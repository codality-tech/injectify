global interface IScheme {
  SObjectType getSObjectType(String sobjectName);
  DescribeSObjectResult getDescribe(SObjectType arg);
  Map<String, SObjectField> getFieldMap(SObjectType sobjectToken);
  Map<String, Schema.Fieldset> getFieldsetMap(SObjectType sobjectToken);
  DescribeFieldResult getFieldDescribe(SObjectField field);
  List<SObject> queryWithBinds(
    String queryString,
    Map<String, Object> bindMap,
    System.AccessLevel accessLevel
  );
  Database.QueryLocator getQueryLocatorWithBinds(
    String queryString,
    Map<String, Object> bindMap,
    System.AccessLevel accessLevel
  );
  Integer countQueryWithBinds(
    String queryString,
    Map<String, Object> bindMap,
    System.AccessLevel accessLevel
  );
  Type getTypeForName(String className);
}
