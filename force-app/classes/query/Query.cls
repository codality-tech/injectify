/**
 * A fluent SOQL query for one object: fields (with lookups and TYPEOF), child subqueries, a
 * condition tree, ordering, limit, offset, and security options.
 *
 * Values in conditions are passed as bind variables when the query runs, so they never become
 * part of the SOQL text. toSoql() writes them inline instead, for display or for trusted values.
 * Queries run in system mode unless withSharing(true) asks for user mode (sharing and field
 * security). withSecurity(true) keeps the mode and refuses the query unless the running user
 * may read the object and every field its SELECT names.
 *
 *   IQuery customers = Application.s.qf().make(Account.SObjectType);
 *   customers.fields().add(new Set<SObjectField>{ Account.Name, Account.Industry });
 *   customers.filters().add(Application.s.eq(Account.Type, 'Customer'));
 *   List<SObject> rows = customers.setLimit(100).run();
 *
 * Subclass it (or BaseQuery, from another namespace) to give an object default fields.
 */
global virtual inherited sharing class Query implements IQuery {
  public virtual class UnifException extends Exception {
  }

  public virtual class UnifValidationException extends UnifException {
  }

  public virtual class UnifConfigurationException extends UnifException {
  }

  private class RuntimeException extends Exception {
  }

  private IModel source;
  private ChildRelationship parentLink;
  private QueryFields selection;
  private ILogicalCondition conditions;
  private Map<String, IQuery> subqueries = new Map<String, IQuery>();
  private List<IOrdering> orderBy = new List<IOrdering>();
  private Integer rowLimit = 0;
  private Integer rowOffset = 0;
  private Boolean securityEnforced = false;
  private Boolean userMode = false;
  private Boolean locking = false;
  private Set<SObjectField> defaulted;

  public Query() {
  }

  public Query(IModel model) {
    init(model);
  }

  public Query(Query other) {
    init(other);
  }

  /** Binds the query to its object. Calling it again with the same model does nothing. */
  public virtual void init(IModel model) {
    if (model == null) {
      throw new RuntimeException('A query needs a model: sobject token must not be null');
    }
    if (source == null) {
      source = model;
    } else if (source != model) {
      throw new RuntimeException(
        'Query for ' + source.token() + ' has already been initialized with a different model: ' + model.token()
      );
    }
  }

  /** Copies another query: fields, subqueries and conditions deeply, orderings by reference. */
  public virtual void init(Query other) {
    if (other == null) {
      throw new IllegalArgumentException('Cannot copy a null query');
    }
    init(other.source());
    fields().add(other.fields());
    parentLink = other.parentLink;
    for (String relationshipName : other.subqueries.keySet()) {
      subqueries.put(relationshipName, other.subqueries.get(relationshipName).deepClone());
    }
    conditions = (ILogicalCondition) other.filters().clone(true);
    orderBy = other.orderBy.clone();
    rowLimit = other.rowLimit;
    rowOffset = other.rowOffset;
    securityEnforced = other.securityEnforced;
    userMode = other.userMode;
    locking = other.locking;
    defaulted = other.defaulted;
  }

  global virtual IQuery deepClone() {
    return new Query(this);
  }

  global virtual IModel source() {
    return source;
  }

  // SELECT

  global virtual IQueryFields fields() {
    if (selection == null) {
      selection = new QueryFields(source);
    }
    return selection;
  }

  /** Fields a subclass wants selected by default; none here. */
  public virtual Set<SObjectField> getDefaultFields() {
    return null;
  }

  global virtual Query addAllFields() {
    fields().addAll();
    return this;
  }

  /** Every field of the object the route leads to. */
  global virtual Query addAllFields(Object route) {
    fields().addAll(route);
    return this;
  }

  /** Selects the fields the other clauses use: Id, lookup routes, filtered and ordered fields. */
  global virtual IQuery addImplicitFields() {
    Set<IPath> used = new Set<IPath>(fields().getRoutes());
    IPath idPath = source().path('id');
    if (idPath != null) {
      used.add(idPath);
    }
    used.addAll(source().compileCondition(filters()).getPaths());
    for (IOrdering ordering : orderBy) {
      used.add(ordering.path());
    }
    fields().add(used);
    return this;
  }

  /** A child subquery, by its relationship field. */
  global virtual IQuery addSubquery(SObjectField relationshipField, IQuery child) {
    return nest(source().getChildRelationship(relationshipField), (Query) child);
  }

  /** A child subquery, by relationship name, or by the child's lookup field name. */
  global virtual IQuery addSubquery(String relationshipName, IQuery child) {
    ChildRelationship link = source().getChildRelationship(relationshipName);
    if (link == null) {
      SObjectField lookupField = child.source().fieldMap().get(relationshipName);
      link = source.getChildRelationship(lookupField);
    }
    return nest(link, (Query) child);
  }

  private Query nest(ChildRelationship link, Query child) {
    if (link == null) {
      throw new RuntimeException('No child relationship found for the subquery');
    }
    if (child == null) {
      throw new RuntimeException('A subquery is required');
    }
    child.parentLink = link;
    subqueries.put(link.getRelationshipName(), child);
    return this;
  }

  global virtual Map<String, IQuery> getSubqueryMap() {
    return subqueries.clone();
  }

  // WHERE, ORDER BY, LIMIT, OFFSET, security

  /** The root condition, an AND that starts empty, made by the model's own core. */
  global virtual ILogicalCondition filters() {
    if (conditions == null) {
      ICore owner = source?.core();
      conditions = owner == null ? Application.s.all(null) : owner.all(null);
    }
    return conditions;
  }

  global virtual IQuery addCondition(ICondition condition) {
    filters().add(condition);
    return this;
  }

  /** The live list of orderings; add to it directly. */
  global virtual List<IOrdering> orderings() {
    return orderBy;
  }

  /** Zero or null means no limit. */
  global virtual IQuery setLimit(Integer maxRows) {
    rowLimit = maxRows ?? 0;
    return this;
  }

  /** Zero or null means no offset. */
  global virtual IQuery setOffset(Integer skipRows) {
    rowOffset = skipRows ?? 0;
    return this;
  }

  /**
   * Refuses the query, with a QueryException, unless the running user may read the object and
   * every field named in the SELECT: its own fields, fields reached through lookups, and the
   * fields of its subqueries. Sharing is left as it is; for sharing as well, use withSharing.
   * (The platform retired WITH SECURITY_ENFORCED, which did this, at API version 67.)
   */
  global virtual IQuery withSecurity(Boolean enforce) {
    securityEnforced = enforce == true;
    return this;
  }

  /** Runs in user mode (sharing rules and field security) instead of system mode. */
  global virtual IQuery withSharing(Boolean enforce) {
    userMode = enforce == true;
    return this;
  }

  /**
   * Adds FOR UPDATE: the rows returned stay locked until the transaction ends, so nothing else
   * changes them in between. It applies to run() and fetch(); count() and toLocator() leave it
   * out, since the platform accepts it on neither. The platform refuses it with ORDER BY.
   */
  global virtual IQuery forUpdate(Boolean lock) {
    locking = lock == true;
    return this;
  }

  // Output

  /** The SOQL with values written inline. */
  global virtual String toSoql() {
    return toSoql(null);
  }

  /** With `binding` true, values become :a0, :a1... placeholders instead. */
  global virtual String toSoql(Boolean binding) {
    return new Statement(binding).complete(this, null);
  }

  global virtual List<SObject> run() {
    requireReadAccess(true);
    Statement statement = new Statement(true);
    String soql = statement.complete(this, null);
    return source().scheme().queryWithBinds(soql, statement.binds, accessLevel());
  }

  /** At most `maxRows` rows, whatever the query's own limit. */
  global virtual List<SObject> fetch(Integer maxRows) {
    requireReadAccess(true);
    Statement statement = new Statement(true);
    String soql = statement.complete(this, String.valueOf(maxRows));
    return source().scheme().queryWithBinds(soql, statement.binds, accessLevel());
  }

  /** The first row, or null. */
  global virtual SObject fetch() {
    List<SObject> rows = fetch(1);
    return rows.isEmpty() ? null : rows[0];
  }

  global virtual Integer count() {
    requireReadAccess(false);
    Statement statement = new Statement(true);
    String soql = statement.counting(this);
    return source().scheme().countQueryWithBinds(soql, statement.binds, accessLevel());
  }

  global virtual Database.QueryLocator toLocator() {
    requireReadAccess(true);
    Statement statement = new Statement(true);
    statement.lockable = false;
    String soql = statement.complete(this, null);
    return source().scheme().getQueryLocatorWithBinds(soql, statement.binds, accessLevel());
  }

  private AccessLevel accessLevel() {
    return userMode ? AccessLevel.USER_MODE : AccessLevel.SYSTEM_MODE;
  }

  /** Whether withSecurity(true) was asked for. */
  public Boolean isSecurityEnforced() {
    return securityEnforced;
  }

  // With withSecurity(true): throws unless the running user may read what the query names.
  private void requireReadAccess(Boolean fieldsToo) {
    if (!securityEnforced) {
      return;
    }
    List<String> refused = new List<String>();
    addUnreadable(refused, fieldsToo);
    if (!refused.isEmpty()) {
      throw new QueryException('Insufficient permissions: the running user cannot read ' + String.join(refused, ', '));
    }
  }

  /** Adds the names of the object and fields this query reads that the running user may not. */
  public void addUnreadable(List<String> refused, Boolean fieldsToo) {
    IScheme scheme = source.scheme();
    if (!source.describe().isAccessible()) {
      refused.add(source.name());
      return;
    }
    if (fieldsToo != true) {
      return;
    }
    IQueryFields chosen = fields();
    if (chosen instanceof QueryFields) {
      for (SObjectField named : ((QueryFields) chosen).everyFieldNamed()) {
        DescribeFieldResult shape = scheme.getFieldDescribe(named);
        if (!shape.isAccessible()) {
          refused.add(String.valueOf(named.getDescribe().getSObjectType()) + '.' + shape.getName());
        }
      }
    }
    for (IQuery child : subqueries.values()) {
      if (child instanceof Query) {
        ((Query) child).addUnreadable(refused, true);
      }
    }
  }

  /** Whether withSharing(true) was asked for. */
  public Boolean isUserMode() {
    return userMode;
  }

  /**
   * Tells the query which of its fields the factory added as defaults. In user mode those are
   * left out of the SELECT when the running user cannot read them, so a default never makes a
   * query fail. A field asked for by name alone is kept, and the platform refuses the query.
   */
  public void markDefaults(Set<SObjectField> fields) {
    defaulted = fields == null ? null : fields.clone();
  }

  /** The SELECT list, less the unreadable defaults when it is to run in user mode. */
  public String selectedFields(Boolean asUser) {
    IQueryFields chosen = fields();
    if (!asUser || defaulted == null || !(chosen instanceof QueryFields)) {
      return chosen.toSoql();
    }
    Set<SObjectField> unreadable = new Set<SObjectField>();
    for (SObjectField field : defaulted) {
      if (!source.scheme().getFieldDescribe(field).isAccessible()) {
        unreadable.add(field);
      }
    }
    return unreadable.isEmpty() ? chosen.toSoql() : ((QueryFields) chosen).toSoqlWithout(unreadable);
  }

  /*
   * One rendering of a query (and its subqueries) as SOQL. When binding, each bindable value is
   * replaced by a :aN placeholder and collected in `binds`.
   */
  private class Statement {
    private Boolean binding;
    private Boolean asUser = false; // taken from the outermost query; subqueries follow it
    private Boolean lockable = true; // false where FOR UPDATE cannot be written
    private Map<String, Object> binds = new Map<String, Object>();

    private Statement(Boolean binding) {
      this.binding = binding == true;
    }

    // `rowCap`, when given, replaces the query's own LIMIT.
    private String complete(Query target, String rowCap) {
      asUser = target.userMode;
      return assemble(
        new List<String>{
          'SELECT', selectList(target),
          'FROM', fromName(target),
          'WHERE', whereClause(target),
          'ORDER BY', orderList(target),
          'LIMIT', rowCap ?? whenSet(target.rowLimit),
          'OFFSET', whenSet(target.rowOffset),
          'FOR', target.locking && lockable ? 'UPDATE' : null
        }
      );
    }

    private String counting(Query target) {
      return assemble(
        new List<String>{
          'SELECT', 'COUNT()',
          'FROM', fromName(target),
          'WHERE', whereClause(target)
        }
      );
    }

    // A child subquery keeps its fields, conditions and ordering only.
    private String nested(Query child) {
      return assemble(
        new List<String>{
          'SELECT', selectList(child),
          'FROM', fromName(child),
          'WHERE', whereClause(child),
          'ORDER BY', orderList(child)
        }
      );
    }

    // Keyword and value pairs in order; a pair whose value is blank is left out.
    private String assemble(List<String> pairs) {
      List<String> kept = new List<String>();
      for (Integer at = 0; at < pairs.size(); at += 2) {
        if (String.isNotBlank(pairs[at + 1])) {
          kept.add(pairs[at] + ' ' + pairs[at + 1]);
        }
      }
      return String.join(kept, ' ');
    }

    private String whenSet(Integer count) {
      return count == null || count == 0 ? null : String.valueOf(count);
    }

    private String selectList(Query target) {
      List<String> columns = new List<String>();
      String fieldList = target.selectedFields(asUser)?.trim();
      if (String.isNotBlank(fieldList)) {
        columns.add(fieldList);
      }
      for (IQuery child : target.subqueries.values()) {
        if (child != null) {
          columns.add('(' + nested((Query) child) + ')');
        }
      }
      return columns.isEmpty() ? 'Id' : String.join(columns, ', ');
    }

    private String fromName(Query target) {
      return target.parentLink == null ? target.source().name() : target.parentLink.getRelationshipName();
    }

    private String orderList(Query target) {
      List<String> keys = new List<String>();
      for (IOrdering ordering : target.orderBy) {
        ordering.realize(target.source().token());
        keys.add(ordering.toSoql());
      }
      return String.join(keys, ', ');
    }

    private String whereClause(Query target) {
      ILogicalCondition root = target.filters();
      if (root.getAll().isEmpty()) {
        return null;
      }
      rejectAggregates(root);
      IConditionCompilation compiled = target.source().compileCondition(root);
      List<String> leaves = new List<String>();
      for (IFieldCondition leaf : compiled.getFieldConditions()) {
        Boolean bindable = binding && Typing.operator(leaf.operator()).supportsBinding();
        leaves.add(bindable ? leaf.toSoql(placeholderFor(leaf.value())) : leaf.toSoql());
      }
      return String.format(compiled.getMarkup(), leaves);
    }

    private String placeholderFor(Object value) {
      String name = 'a' + binds.size();
      binds.put(name, value);
      return ':' + name;
    }

    private void rejectAggregates(ICondition node) {
      if (node instanceof IFieldCondition && ((IFieldCondition) node).isAggregateCondition()) {
        throw new UnifValidationException(
          'Aggregate functions cannot be used in WHERE clause. Use HAVING in AggregateQuery instead.'
        );
      }
      if (node instanceof ILogicalCondition) {
        for (ICondition child : ((ILogicalCondition) node).getAll()) {
          rejectAggregates(child);
        }
      }
    }
  }
}
