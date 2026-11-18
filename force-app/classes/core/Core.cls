public virtual class Core implements ICore {
  // # State
  private Modeling modeling;
  private Filtering filtering;
  private IInjector injectorInstance;

  // # Constructor
  public Core(IScheme scheme) {
    if (scheme == null) {
      scheme = new SchemeDefault();
    }
    this.modeling = new Modeling(scheme, this);
    this.modeling.setCore(this); // Set the core reference after creation
    this.filtering = new Filtering(this);
    this.injectorInstance = new Injector(scheme);
  }

  public Core() {
    this(null); // Use default SchemeDefault
  }

  // Getter for injector (internal only)
  public IInjector injector() {
    return injectorInstance;
  }

  // Getter for filtering
  public Filtering filtering() {
    return filtering;
  }

  /*
   * [MODELING]
   *
   * Schema introspection and metadata access layer.
   * All methods delegate to Modeling class for SObjectType/SObjectField operations.
   *
   * KEY ABSTRACTIONS:
   *   - IModel: Represents an SObjectType with field access, path building, and query creation
   *   - IPath: Represents a field path (e.g., Account.Name, Contact.Account.Industry)
   *   - IReference: Union of IModel and IPath (allows relationship traversal)
   *
   * USAGE:
   *   IModel accountModel = Application.s.model(Account.SObjectType);
   *   IPath namePath = Application.s.path(Account.Name);
   *   IPath industryPath = Application.s.path(new List<SObjectField>{ Contact.AccountId, Account.Industry });
   */

  // # Reference
  public IReference reference(SObjectType token) {
    return (IReference) modeling.model(token);
  }
  public IReference reference(SObjectField field) {
    return (IReference) modeling.path(field);
  }

  public IReference reference(List<SObjectField> fields) {
    return (IReference) modeling.path(fields);
  }

  // # Model
  public IModel model(SObjectType token) {
    return modeling.model(token);
  }

  public IModel model(String sobjectName) {
    return modeling.model(sobjectName);
  }

  public IModel model(SObject record) {
    return modeling.model(record?.getSObjectType());
  }

  public IModel model(List<SObject> records) {
    sobjecttype token = records?.getSObjectType();
    if (token == null && records?.size() > 0) {
      token = records[0].getSObjectType();
    }
    return model(token);
  }

  // # Path
  public IPath path(SObjectField field) {
    return modeling.path(field);
  }

  public IPath path(List<SObjectField> fields) {
    return modeling.path(fields);
  }

  /*
    [FILTERING]
    All interfaces and methods pass through to that base class
    Handles condition logic, i.e. conjunctions, disjunctions, field conditions
    */

  // # Logic
  public ILogicalCondition all(List<ICondition> items) {
    return filtering.all(items);
  }

  public ILogicalCondition any(List<ICondition> items) {
    return filtering.any(items);
  }

  // # Field Conditions
  public IFieldCondition cond(
    Enums.Comparator op,
    Object lhs,
    Object rhs,
    Boolean negated
  ) {
    return filtering.fieldCondition(op, lhs, rhs, negated);
  }

  public IFieldCondition cond(Enums.Comparator op, Object lhs, Object rhs) {
    return filtering.fieldCondition(op, lhs, rhs);
  }

  // # Convenience Methods
  public IFieldCondition eq(Object lhs, Object rhs) {
    return filtering.fieldCondition(Enums.Comparator.EQ, lhs, rhs);
  }

  public IFieldCondition ne(Object lhs, Object rhs) {
    return filtering.fieldCondition(Enums.Comparator.NE, lhs, rhs);
  }

  public IFieldCondition ge(Object lhs, Object rhs) {
    return filtering.fieldCondition(Enums.Comparator.GE, lhs, rhs);
  }

  public IFieldCondition le(Object lhs, Object rhs) {
    return filtering.fieldCondition(Enums.Comparator.LE, lhs, rhs);
  }

  public IFieldCondition gt(Object lhs, Object rhs) {
    return filtering.fieldCondition(Enums.Comparator.GT, lhs, rhs);
  }

  public IFieldCondition lt(Object lhs, Object rhs) {
    return filtering.fieldCondition(Enums.Comparator.LT, lhs, rhs);
  }

  public IFieldCondition lk(Object lhs, Object rhs) {
    return filtering.fieldCondition(Enums.Comparator.LK, lhs, rhs);
  }

  public IFieldCondition iin(Object lhs, Object rhs) {
    return filtering.fieldCondition(Enums.Comparator.IIN, lhs, rhs);
  }

  public IFieldCondition nin(Object lhs, Object rhs) {
    return filtering.fieldCondition(Enums.Comparator.NIN, lhs, rhs);
  }

  public IFieldCondition inc(Object lhs, Object rhs) {
    return filtering.fieldCondition(Enums.Comparator.INC, lhs, rhs);
  }

  public IFieldCondition exc(Object lhs, Object rhs) {
    return filtering.fieldCondition(Enums.Comparator.EXC, lhs, rhs);
  }

  // Negation method
  public ICondition neg(ICondition condition) {
    // Cast to implementation types to call setNegated (not in interface)
    if (condition instanceof Filtering.LogicalCondition) {
      ((Filtering.LogicalCondition) condition).setNegated(true);
    } else if (condition instanceof Filtering.FieldCondition) {
      ((Filtering.FieldCondition) condition).setNegated(true);
    }
    return condition;
  }

  // Universal Conditions (standard fields)

  public IFieldCondition condId(set<id> recordIds) {
    return iin('Id', recordIds);
  }

  public IFieldCondition condRtdn(set<string> developerNames) {
    return iin('RecordType.DeveloperName', developerNames);
  }

  /*
    [ORDERING]
    All interfaces and methods pass through to that base class
    Handles ordering logic, i.e. ASC/DESC, NULLS FIRST/LAST
    */

  public IOrdering ordering(
    Object route,
    Boolean isAscending,
    Boolean nullsLast
  ) {
    return modeling.ordering(route, isAscending, nullsLast);
  }

  public IOrdering ordering(Object route, Boolean isAscending) {
    return modeling.ordering(route, isAscending, false);
  }

  public IOrdering ordering(Object route) {
    return modeling.ordering(route, true, false);
  }

  /*
    [Aggregate Functions]
    */

  public IAggregateFunction count(Object field) {
    return new Modeling.AggregateFunction('COUNT', field);
  }

  public IAggregateFunction countDistinct(Object field) {
    return new Modeling.AggregateFunction('COUNT_DISTINCT', field);
  }

  public IAggregateFunction sum(Object field) {
    return new Modeling.AggregateFunction('SUM', field);
  }

  public IAggregateFunction avg(Object field) {
    return new Modeling.AggregateFunction('AVG', field);
  }

  public IAggregateFunction min(Object field) {
    return new Modeling.AggregateFunction('MIN', field);
  }

  public IAggregateFunction max(Object field) {
    return new Modeling.AggregateFunction('MAX', field);
  }

  /** The function chosen at run time, as cond() chooses a comparison. */
  public IAggregateFunction aggregate(Enums.Aggregate function, Object field) {
    if (function == null) {
      throw new IllegalArgumentException('An aggregate function is required');
    }
    return new Modeling.AggregateFunction(function.name(), field);
  }

  /*
    [Work]
    */

  public IWork work() {
    return new Work(modeling.scheme);
  }

  /*
    [Search]
    */

  public ISearchQuery searchQuery(List<IQuery> queries) {
    if (queries == null || queries.isEmpty()) {
      throw new Modeling.ModelException('Query list cannot be null or empty');
    }
    return new SearchQuery(queries);
  }
}
