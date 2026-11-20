/**
 * An aggregate SOQL query: grouped fields, aggregate functions (each with an alias), WHERE and
 * HAVING conditions, ordering, limit and offset, ALL ROWS and USING SCOPE. ROLLUP and CUBE add
 * GROUPING() columns for every grouped field. Like Query, run() binds condition values; toSoql()
 * writes them inline.
 */
public virtual inherited sharing class AggregateQuery implements IAggregateQuery {
  public virtual class AggregateException extends Exception {
  }

  private static final Integer MAX_ROLLUP_FIELDS = 3;

  private IModel source;
  private Set<IAggregateFunction> functions = new Set<IAggregateFunction>();
  private List<IPath> grouped = new List<IPath>();
  private Boolean isRollup = false;
  private Boolean isCube = false;
  private ILogicalCondition whereRoot;
  private ILogicalCondition havingRoot;
  private List<IOrdering> orderBy = new List<IOrdering>();
  private Integer rowLimit;
  private Integer rowOffset;
  private Boolean securityEnforced = false;
  private Boolean userMode = false;
  private Boolean deletedToo = false;
  private Enums.FilterScope scope;

  public AggregateQuery() {
  }

  public AggregateQuery(IModel model) {
    init(model);
  }

  public AggregateQuery(AggregateQuery other) {
    init(other);
  }

  /** Binds the query to its object; the same model again does nothing. */
  public virtual void init(IModel model) {
    if (model == null) {
      throw new AggregateException('An aggregate query needs a model: source must not be null');
    }
    if (source == null) {
      source = model;
    } else if (source != model) {
      throw new AggregateException('AggregateQuery has already been initialized with a different model');
    }
  }

  /** Copies another aggregate query: conditions deeply, functions, groupings and orderings by reference. */
  public virtual void init(AggregateQuery other) {
    init(other.source());
    functions = other.aggregates().clone();
    grouped = other.groupBys().clone();
    isRollup = other.isRollup;
    isCube = other.isCube;
    havingRoot = (ILogicalCondition) other.havingFilters().clone(true);
    whereRoot = (ILogicalCondition) other.filters().clone(true);
    orderBy = other.orderings().clone();
    rowLimit = other.rowLimit;
    rowOffset = other.rowOffset;
    securityEnforced = other.securityEnforced;
    userMode = other.userMode;
    deletedToo = other.deletedToo;
    scope = other.scope;
  }

  public virtual IAggregateQuery deepClone() {
    return new AggregateQuery(this);
  }

  public IModel source() {
    return source;
  }

  /** The live set of aggregate functions to select. */
  public Set<IAggregateFunction> aggregates() {
    return functions;
  }

  /** The live list of grouped fields. */
  public List<IPath> groupBys() {
    return grouped;
  }

  /** GROUP BY ROLLUP(...), with subtotal rows; at most three grouped fields. */
  public IAggregateQuery rollup() {
    isRollup = true;
    return this;
  }

  /** GROUP BY CUBE(...), with subtotals for every combination; at most three grouped fields. */
  public IAggregateQuery cube() {
    isCube = true;
    return this;
  }

  /** Conditions on the rows before grouping (WHERE). A semi-join or anti-join goes here. */
  public ILogicalCondition filters() {
    if (whereRoot == null) {
      whereRoot = emptyRoot();
    }
    return whereRoot;
  }

  /** Conditions on the groups (HAVING), usually comparing an aggregate function. No semi-joins. */
  public ILogicalCondition havingFilters() {
    if (havingRoot == null) {
      havingRoot = emptyRoot();
    }
    return havingRoot;
  }

  // An empty AND from the model's own core, so an injected scheme is used throughout.
  private ILogicalCondition emptyRoot() {
    ICore owner = source?.core();
    return owner == null ? Application.s.all(null) : owner.all(null);
  }

  public List<IOrdering> orderings() {
    return orderBy;
  }

  /** Null means no limit; 0 is written as LIMIT 0. */
  public IAggregateQuery setLimit(Integer maxRows) {
    rowLimit = maxRows;
    return this;
  }

  public IAggregateQuery setOffset(Integer skipRows) {
    rowOffset = skipRows;
    return this;
  }

  /**
   * Refuses the query, with a QueryException, unless the running user may read the object, every
   * field it aggregates or groups by, and the object and field that the inner query of a
   * semi-join in its WHERE clause selects. Sharing is left as it is.
   */
  public IAggregateQuery withSecurity(Boolean enforce) {
    securityEnforced = enforce == true;
    return this;
  }

  /** Runs in user mode (sharing rules and field security) instead of system mode. */
  public IAggregateQuery withSharing(Boolean enforce) {
    userMode = enforce == true;
    return this;
  }

  /** Adds ALL ROWS: records in the recycle bin and archived activities are counted as well. */
  public IAggregateQuery allRows(Boolean include) {
    deletedToo = include == true;
    return this;
  }

  /**
   * Adds USING SCOPE: only the records in the scope are read; null removes it. The platform ends
   * the transaction for a scope the object does not support. (An aggregate query takes neither
   * FOR VIEW nor FOR REFERENCE: the platform fails on them, so they are not offered here.)
   */
  public IAggregateQuery usingScope(Enums.FilterScope scope) {
    this.scope = scope;
    return this;
  }

  public virtual String toSoql() {
    return toSoql(null);
  }

  /** With `binding` true, condition values become :a0, :a1... placeholders. */
  public virtual String toSoql(Boolean binding) {
    return new Statement(this, binding).text();
  }

  /** Whether withSecurity(true) was asked for. */
  public Boolean isSecurityEnforced() {
    return securityEnforced;
  }

  // With withSecurity(true): throws unless the running user may read what the query names.
  private void requireReadAccess() {
    if (!securityEnforced) {
      return;
    }
    List<String> refused = new List<String>();
    if (!source.describe().isAccessible()) {
      refused.add(source.name());
    } else {
      Set<SObjectField> named = new Set<SObjectField>();
      for (IAggregateFunction function : functions) {
        Object over = function.field();
        if (over instanceof SObjectField) {
          named.add((SObjectField) over);
        } else if (over instanceof IPath) {
          named.addAll(((IPath) over).fieldSequence());
        }
      }
      for (IPath groupedBy : grouped) {
        named.addAll(groupedBy.fieldSequence());
      }
      for (SObjectField field : named) {
        DescribeFieldResult shape = source.scheme().getFieldDescribe(field);
        if (!shape.isAccessible()) {
          refused.add(String.valueOf(field.getDescribe().getSObjectType()) + '.' + shape.getName());
        }
      }
      Query.addUnreadableJoins(whereRoot, refused);
    }
    if (!refused.isEmpty()) {
      throw new QueryException('Insufficient permissions: the running user cannot read ' + String.join(refused, ', '));
    }
  }

  public virtual List<AggregateResult> run() {
    requireReadAccess();
    Statement statement = new Statement(this, true);
    String soql = statement.text();
    AccessLevel mode = userMode ? AccessLevel.USER_MODE : AccessLevel.SYSTEM_MODE;
    return (List<AggregateResult>) source.scheme().queryWithBinds(soql, statement.binds, mode);
  }

  /*
   * One rendering of the query. When binding, each bindable condition value is replaced by a :aN
   * placeholder and collected in `binds`.
   */
  private class Statement {
    private AggregateQuery target;
    private Boolean binding;
    private Map<String, Object> binds = new Map<String, Object>();

    private Statement(AggregateQuery target, Boolean binding) {
      this.target = target;
      this.binding = binding == true;
    }

    // Keyword and value pairs in SOQL order; blank values are left out.
    private String text() {
      List<String> pairs = new List<String>{
        'SELECT', selectList(),
        'FROM', target.source.name(),
        'USING SCOPE', Query.scopeName(target.scope),
        'WHERE', conditionText(target.whereRoot, false),
        'GROUP BY', groupClause(),
        'HAVING', conditionText(target.havingRoot, true),
        'ORDER BY', orderList(),
        'LIMIT', target.rowLimit == null ? null : String.valueOf(target.rowLimit),
        'OFFSET', target.rowOffset == null ? null : String.valueOf(target.rowOffset),
        'ALL', target.deletedToo ? 'ROWS' : null
      };
      List<String> kept = new List<String>();
      for (Integer at = 0; at < pairs.size(); at += 2) {
        if (String.isNotBlank(pairs[at + 1])) {
          kept.add(pairs[at] + ' ' + pairs[at + 1]);
        }
      }
      return String.join(kept, ' ');
    }

    // Grouped fields, then each function with its alias, then GROUPING() columns for ROLLUP/CUBE.
    private String selectList() {
      List<String> columns = new List<String>(groupedNames());
      for (IAggregateFunction function : target.functions) {
        columns.add(function.toSoql() + ' ' + function.getAlias());
      }
      if (target.isRollup || target.isCube) {
        for (String name : groupedNames()) {
          columns.add('GROUPING(' + name + ') ' + name + '_grp');
        }
      }
      return String.join(columns, ', ');
    }

    private List<String> groupedNames() {
      List<String> names = new List<String>();
      for (IPath field : target.grouped) {
        names.add(field.name());
      }
      return names;
    }

    private String groupClause() {
      List<String> names = groupedNames();
      if (names.isEmpty()) {
        return null;
      }
      String modifier = target.isRollup ? 'ROLLUP' : (target.isCube ? 'CUBE' : null);
      if (modifier == null) {
        return String.join(names, ', ');
      }
      if (names.size() > MAX_ROLLUP_FIELDS) {
        throw new AggregateException(
          modifier + ' supports a maximum of ' + MAX_ROLLUP_FIELDS + ' fields, but ' + names.size() + ' were provided'
        );
      }
      return modifier + '(' + String.join(names, ', ') + ')';
    }

    // A condition tree as SOQL; with binding, bindable values become placeholders. A semi-join's
    // inner query is written in place, and its values share this statement's binds. Only WHERE
    // takes one: the platform refuses a semi-join in HAVING. HAVING takes no bare field either,
    // so its tree is compiled as `grouped`, which writes the constants of empty groups as counts.
    private String conditionText(ILogicalCondition root, Boolean grouped) {
      if (root == null || root.getAll().isEmpty()) {
        return null;
      }
      IConditionCompilation compiled = grouped
        ? new Filtering.ConditionCompilation(target.source, root, true)
        : target.source.compileCondition(root);
      List<String> leaves = new List<String>();
      for (IFieldCondition leaf : compiled.getFieldConditions()) {
        if (leaf.value() instanceof IQuery) {
          if (grouped) {
            throw new Filtering.ConditionException('Cannot write a semi-join in HAVING: it belongs in filters()');
          }
          String innerSoql = Query.semiJoinSoql((IQuery) leaf.value(), binding ? binds : null);
          leaves.add(leaf.toSoql(innerSoql));
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

    private String orderList() {
      List<String> keys = new List<String>();
      for (IOrdering ordering : target.orderBy) {
        ordering.realize(target.source.token());
        keys.add(ordering.toSoql());
      }
      return String.join(keys, ', ');
    }
  }
}
