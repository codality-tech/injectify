/** One object type: its describe, fields, record types and relationships, and paths from it. */
global interface IModel extends IReference {
  // Identity and schema
  SObjectType token();
  String name();
  DescribeSObjectResult describe();
  Map<String, SObjectField> fieldMap();
  Map<String, FieldSet> fieldSetMap();
  SObjectField nameField();
  IScheme scheme();
  ICore core();

  // Paths and relationships
  IPath path(Object via);
  IPath path(Object via, Boolean strictType, Boolean strictNull);
  ChildRelationship getChildRelationship(SObjectField lookupOnChild);
  ChildRelationship getChildRelationship(String relationshipName);

  // Record types
  String recordTypeName(Id recordTypeId);
  Id recordTypeId(String developerName);

  // Conditions
  ICondition parseCondition(String expression);
  IConditionCompilation compileCondition(ICondition root);
  ICondition condRtdn(Set<String> developerNames);

  // Records, domains and queries
  List<SObject> spawnRecordList();
  SObject spawnRecord(Map<String, Object> valuesByField);
  IDomain domain(List<SObject> rows);
  IAggregateQuery aggregateQuery();
  IQuery query(List<ICondition> conditions);
  IQuery query();
}
