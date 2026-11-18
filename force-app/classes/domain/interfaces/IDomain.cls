/** Business logic over a list of records of one object. */
global interface IDomain {
  // Records
  void init(IModel model, SObject[] rows);
  Map<Id, SObject> toMap();
  IModel source();
  Integer size();
  SObject[] records();

  // Updates through a unit of work
  void updateBlank(SObject template, IWork work);
  void updateDifferent(SObject template, IWork work);

  // Selection
  SObject[] sort(IOrdering ordering);
  SObject[] filter(ICondition condition);
  SObject[] getChangedRecords(Map<Id, SObject> previous, Set<SObjectField> fields);
  SObject[] getChangedRecords(Map<Id, SObject> previous, Set<String> fieldNames);

  // Grouping by a path's value
  Map<Id, SObject[]> catalogId(Object route);
  Map<Id, SObject[]> segmentId(Object route);
  Map<String, SObject[]> catalog(Object route);
  Map<String, SObject[]> segment(Object route);
  /** Drops what catalog and segment remembered for the path. */
  void forget(Object route);
  Map<Id, SObject> collectRecords(Object route);
  Object aggregate(IAggregateFunction function);
}
