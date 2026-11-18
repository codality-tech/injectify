global interface ICore {
  // Reference
  IReference reference(SObjectType token);
  IReference reference(SObjectField field);
  IReference reference(List<SObjectField> fields);

  // Model
  IModel model(SObjectType token);
  IModel model(String sobjectName);
  IModel model(SObject record);
  IModel model(List<SObject> records);

  // Path
  IPath path(SObjectField field);
  IPath path(List<SObjectField> fields);

  // Logical conditions
  ILogicalCondition all(List<ICondition> items);
  ILogicalCondition any(List<ICondition> items);

  // Field conditions
  IFieldCondition cond(
    Enums.Comparator op,
    Object lhs,
    Object rhs,
    Boolean negated
  );
  IFieldCondition cond(Enums.Comparator op, Object lhs, Object rhs);

  // Convenience condition methods
  IFieldCondition eq(Object lhs, Object rhs);
  IFieldCondition ne(Object lhs, Object rhs);
  IFieldCondition ge(Object lhs, Object rhs);
  IFieldCondition le(Object lhs, Object rhs);
  IFieldCondition gt(Object lhs, Object rhs);
  IFieldCondition lt(Object lhs, Object rhs);
  IFieldCondition lk(Object lhs, Object rhs);
  IFieldCondition iin(Object lhs, Object rhs);
  IFieldCondition nin(Object lhs, Object rhs);
  IFieldCondition inc(Object lhs, Object rhs);
  IFieldCondition exc(Object lhs, Object rhs);

  // Negation
  ICondition neg(ICondition condition);

  // Universal conditions
  IFieldCondition condId(Set<Id> recordIds);
  IFieldCondition condRtdn(Set<String> developerNames);

  // Ordering
  IOrdering ordering(Object route, Boolean isAscending, Boolean nullsLast);

  // Aggregate functions
  IAggregateFunction count(Object field);
  IAggregateFunction countDistinct(Object field);
  IAggregateFunction sum(Object field);
  IAggregateFunction avg(Object field);
  IAggregateFunction min(Object field);
  IAggregateFunction max(Object field);
  IAggregateFunction aggregate(Enums.Aggregate function, Object field);

  // Work
  IWork work();

  // Search
  ISearchQuery searchQuery(List<IQuery> queries);
}
