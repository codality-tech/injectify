/**
 * A fluent SOQL query for one object: fields (with lookups and TYPEOF), child subqueries, a
 * condition tree, ordering, limit, offset, security options, and the statement's own options
 * (FOR UPDATE, ALL ROWS, USING SCOPE, FOR VIEW, FOR REFERENCE).
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
 * A query can also be the value of an IN or NOT IN condition of another query, which makes a
 * semi-join or anti-join. It then selects one field, an Id or a lookup field, and its values are
 * bound with the outer query's:
 *
 *   IQuery inSeattle = Application.s.model(Contact.SObjectType).query();
 *   inSeattle.fields().add(new Set<SObjectField>{ Contact.AccountId });
 *   inSeattle.filters().add(Application.s.eq(Contact.MailingCity, 'Seattle'));
 *   customers.filters().add(Application.s.iin(Account.Id, inSeattle));
 *   // ... AND Id IN (SELECT AccountId FROM Contact WHERE (MailingCity = :a1))
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
  private Boolean deletedToo = false;
  private Enums.FilterScope scope;
  private Boolean viewing = false;
  private Boolean referencing = false;
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

  /**
   * Copies another query: fields, subqueries and conditions deeply (the inner queries of its
   * semi-joins included), orderings by reference.
   */
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
    deletedToo = other.deletedToo;
    scope = other.scope;
    viewing = other.viewing;
    referencing = other.referencing;
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
   * every field named in the SELECT: its own fields, fields reached through lookups, the fields
   * of its subqueries, and the object and field that the inner query of a semi-join selects.
   * Sharing is left as it is; for sharing as well, use withSharing.
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

  /**
   * Adds ALL ROWS: records in the recycle bin and archived activities are read as well. It
   * applies to run(), fetch(), count() and toLocator(). The platform takes it on the query
   * itself only, so a child subquery or the inner query of a semi-join that asks for it throws,
   * and it refuses ALL ROWS together with FOR UPDATE.
   */
  global virtual IQuery allRows(Boolean include) {
    deletedToo = include == true;
    return this;
  }

  /**
   * Adds USING SCOPE: only the records in the scope are read, such as those the running user
   * owns (MINE). Null removes it. An object supports only some scopes, and the platform ends the
   * transaction, with an error no code can catch, for one the object does not support. A child
   * subquery takes none, and throws.
   */
  global virtual IQuery usingScope(Enums.FilterScope scope) {
    this.scope = scope;
    return this;
  }

  /**
   * Adds FOR VIEW: the records returned count as viewed by the running user. Their
   * LastViewedDate and LastReferencedDate are set, and they show among the user's recently
   * viewed records. It applies to run(), fetch() and toLocator(). The platform takes FOR VIEW or
   * FOR REFERENCE, not both.
   */
  global virtual IQuery forView(Boolean mark) {
    viewing = mark == true;
    return this;
  }

  /**
   * Adds FOR REFERENCE: the records returned count as referenced by the running user. Their
   * LastReferencedDate alone is set, and they show among the user's recently viewed records.
   * It applies to run(), fetch() and toLocator().
   */
  global virtual IQuery forReference(Boolean mark) {
    referencing = mark == true;
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

  /**
   * Adds the names of the object and fields this query reads that the running user may not. The
   * semi-joins in its WHERE clause are read whether fields are asked for or not: a count has them.
   */
  public void addUnreadable(List<String> refused, Boolean fieldsToo) {
    IScheme scheme = source.scheme();
    if (!source.describe().isAccessible()) {
      refused.add(source.name());
      return;
    }
    addUnreadableJoins(conditions, refused);
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

  /**
   * Adds what the semi-joins and anti-joins of a condition tree read that the running user may
   * not: the inner query's object, or else the one field it selects.
   */
  public static void addUnreadableJoins(ICondition node, List<String> refused) {
    if (node instanceof IFieldCondition) {
      Object innerQuery = ((IFieldCondition) node).value();
      if (innerQuery instanceof Query) {
        ((Query) innerQuery).addUnreadableAsJoin(refused);
      }
    } else if (node instanceof ILogicalCondition) {
      for (ICondition member : ((ILogicalCondition) node).getAll()) {
        addUnreadableJoins(member, refused);
      }
    }
  }

  private void addUnreadableAsJoin(List<String> refused) {
    if (!source.describe().isAccessible()) {
      refused.add(source.name());
      return;
    }
    checkJoinable();
    SObjectField matched = joinField();
    DescribeFieldResult shape = source.scheme().getFieldDescribe(matched);
    if (!shape.isAccessible()) {
      refused.add(String.valueOf(matched.getDescribe().getSObjectType()) + '.' + shape.getName());
    }
  }

  // Semi-joins and anti-joins

  /**
   * The inner query of a semi-join or anti-join as SOQL, in parentheses: its one field, its
   * object and its conditions. Given a bind map, its values are added to the map and written as
   * :aN placeholders, numbered after the values already there; given null, they are written inline.
   */
  public static String semiJoinSoql(IQuery innerQuery, Map<String, Object> sharedBinds) {
    Statement statement = new Statement(sharedBinds != null);
    if (sharedBinds != null) {
      statement.binds = sharedBinds;
    }
    return statement.joined(innerQuery);
  }

  /**
   * The one field this query selects as the inner query of a semi-join: the lookup field chosen,
   * or Id when no field was chosen. (A query always selects Id as well, so Id beside one lookup
   * field means the lookup field.)
   */
  private SObjectField joinField() {
    List<SObjectField> own = ownFieldsBesidesId();
    return own.isEmpty() ? source.fieldMap().get('Id') : own[0];
  }

  // Throws unless this query can be the inner query of a semi-join: it selects one Id or lookup
  // field and nothing else, and has no limit, offset or ALL ROWS, which the platform takes on
  // the outer query only.
  private void checkJoinable() {
    List<SObjectField> own = ownFieldsBesidesId();
    DescribeFieldResult chosen = own.size() == 1 ? source.scheme().getFieldDescribe(own[0]) : null;
    String unfit;
    if (!fields().getRoutes().isEmpty()) {
      unfit = 'selects fields through a lookup';
    } else if (!subqueries.isEmpty()) {
      unfit = 'has a child subquery';
    } else if (own.size() > 1) {
      unfit = 'selects ' + own.size() + ' fields besides Id';
    } else if (chosen != null && chosen.getType() != DisplayType.REFERENCE) {
      unfit = 'selects ' + chosen.getName() + ', which is not a lookup field';
    } else if (rowLimit != 0 || rowOffset != 0) {
      unfit = 'has a LIMIT or OFFSET';
    } else if (deletedToo) {
      unfit = 'asks for ALL ROWS';
    }
    if (unfit != null) {
      throw new UnifValidationException('Cannot use the query on ' + source.name() + ' in a semi-join: it ' + unfit);
    }
  }

  private List<SObjectField> ownFieldsBesidesId() {
    List<SObjectField> own = new List<SObjectField>();
    Map<IReference, Set<SObjectField>> byReference = fields().getFieldsByReference();
    for (IReference via : byReference.keySet()) {
      if (via.size() == 0) {
        own.addAll(byReference.get(via));
      }
    }
    Integer idAt = own.indexOf(source.fieldMap().get('Id'));
    if (idAt >= 0) {
      own.remove(idAt);
    }
    return own;
  }

  /** Whether withSharing(true) was asked for. */
  public Boolean isUserMode() {
    return userMode;
  }

  /** The row limit, or 0 for none. */
  public Integer rowLimit() {
    return rowLimit;
  }

  /** The row offset, or 0 for none. */
  public Integer rowOffset() {
    return rowOffset;
  }

  /**
   * ALL ROWS or USING SCOPE, when the query asks for one; null when it asks for neither. They
   * belong to a query as a whole, so a child subquery and a search refuse a query that has one.
   */
  public String wholeQueryOption() {
    return deletedToo ? 'ALL ROWS' : (scope != null ? 'USING SCOPE' : null);
  }

  /** USING SCOPE as SOQL writes it: the enum's name in lower case, but for scopingRule. */
  public static String scopeName(Enums.FilterScope scope) {
    if (scope == null) {
      return null;
    }
    return scope == Enums.FilterScope.SCOPING_RULE ? 'scopingRule' : scope.name().toLowerCase();
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
   * One rendering of a query (with its subqueries and the inner queries of its semi-joins) as
   * SOQL. When binding, each bindable value is replaced by a :aN placeholder and collected in
   * `binds`.
   */
  private class Statement {
    private Boolean binding;
    private Boolean asUser = false; // taken from the outermost query; subqueries follow it
    private Boolean lockable = true; // false where FOR UPDATE cannot be written
    private Boolean joining = false; // true while the inner query of a semi-join is written
    private Map<String, Object> binds = new Map<String, Object>();

    private Statement(Boolean binding) {
      this.binding = binding == true;
    }

    // `rowCap`, when given, replaces the query's own LIMIT. The clauses after OFFSET come in the
    // one order the platform takes: FOR VIEW or FOR REFERENCE, then FOR UPDATE or ALL ROWS.
    private String complete(Query target, String rowCap) {
      asUser = target.userMode;
      Boolean locks = target.locking && lockable;
      String clash;
      if (target.viewing && target.referencing) {
        clash = 'FOR VIEW with FOR REFERENCE';
      } else if (locks && target.deletedToo) {
        clash = 'FOR UPDATE with ALL ROWS';
      }
      if (clash != null) {
        throw new UnifValidationException(
          'Cannot write ' + clash + ' on ' + target.source().name() + ': a query takes one or the other'
        );
      }
      return assemble(
        new List<String>{
          'SELECT', selectList(target),
          'FROM', fromName(target),
          'USING SCOPE', scopeName(target.scope),
          'WHERE', whereClause(target),
          'ORDER BY', orderList(target),
          'LIMIT', rowCap ?? whenSet(target.rowLimit),
          'OFFSET', whenSet(target.rowOffset),
          'FOR', target.viewing ? 'VIEW' : (target.referencing ? 'REFERENCE' : null),
          'FOR', locks ? 'UPDATE' : null,
          'ALL', target.deletedToo ? 'ROWS' : null
        }
      );
    }

    // A count returns no rows, so it has nothing to lock or to mark as viewed.
    private String counting(Query target) {
      return assemble(
        new List<String>{
          'SELECT', 'COUNT()',
          'FROM', fromName(target),
          'USING SCOPE', scopeName(target.scope),
          'WHERE', whereClause(target),
          'ALL', target.deletedToo ? 'ROWS' : null
        }
      );
    }

    // A child subquery keeps its fields, conditions, ordering, limit and offset. (The platform
    // takes an offset there only when the parent query returns one row; it says so itself.) It
    // takes no ALL ROWS and no USING SCOPE: those belong to the query as a whole, so a child that
    // asks for one is refused rather than read without it. Locking and view marking are the
    // parent's to ask for, and are not written here.
    private String nested(Query child) {
      String refused = child.wholeQueryOption();
      if (refused != null) {
        throw new UnifValidationException(
          'Cannot write ' + refused + ' in the subquery on ' + fromName(child) + ': it belongs to the parent query'
        );
      }
      return assemble(
        new List<String>{
          'SELECT', selectList(child),
          'FROM', fromName(child),
          'WHERE', whereClause(child),
          'ORDER BY', orderList(child),
          'LIMIT', whenSet(child.rowLimit),
          'OFFSET', whenSet(child.rowOffset)
        }
      );
    }

    // The right-hand side of a semi-join or anti-join, in parentheses: the inner query's one
    // field, its object, its scope and its conditions, whose values are bound with the outer
    // query's. Its ordering is left out (the platform takes none there, and it could not change
    // the result). The platform does not nest one semi-join in another's inner query, so neither
    // does this.
    private String joined(IQuery innerQuery) {
      if (!(innerQuery instanceof Query)) {
        throw new UnifValidationException('A semi-join needs a query made by the framework as its inner query');
      }
      if (joining) {
        throw new UnifValidationException('A semi-join cannot be nested in the inner query of another semi-join');
      }
      Query target = (Query) innerQuery;
      target.checkJoinable();
      joining = true;
      String text = assemble(
        new List<String>{
          'SELECT', target.source().toSoql(target.joinField()),
          'FROM', target.source().name(),
          'USING SCOPE', scopeName(target.scope),
          'WHERE', whereClause(target)
        }
      );
      joining = false;
      return '(' + text + ')';
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
        if (leaf.value() instanceof IQuery) {
          leaves.add(leaf.toSoql(joined((IQuery) leaf.value())));
          continue;
        }
        Boolean bindable = binding && Typing.bindable(leaf.operator(), leaf.value());
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
