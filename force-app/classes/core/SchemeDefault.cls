/**
 * The live schema: describes come from the platform and queries run against the database.
 * Describe results are kept for the rest of the transaction (they cannot change within one), so
 * repeated path and model lookups cost a map read instead of a describe call.
 */
public inherited sharing class SchemeDefault implements IScheme, ISearchScheme {
  private static Map<String, SObjectType> typeByName = new Map<String, SObjectType>();
  private static Map<SObjectType, DescribeSObjectResult> describeByType = new Map<SObjectType, DescribeSObjectResult>();
  private static Map<SObjectType, Map<String, SObjectField>> fieldsByType = new Map<SObjectType, Map<String, SObjectField>>();
  private static Map<SObjectType, Map<String, FieldSet>> fieldSetsByType = new Map<SObjectType, Map<String, FieldSet>>();
  private static Map<SObjectField, DescribeFieldResult> describeByField = new Map<SObjectField, DescribeFieldResult>();

  /** The type with the API name, or null when the name is not an object. */
  public SObjectType getSObjectType(String sobjectName) {
    if (sobjectName == null) {
      return null;
    }
    String key = sobjectName.toLowerCase();
    if (!typeByName.containsKey(key)) {
      SObjectType found;
      try {
        found = ((SObject) Type.forName(sobjectName)?.newInstance())?.getSObjectType();
      } catch (Exception notAnObject) {
        found = null;
      }
      typeByName.put(key, found);
    }
    return typeByName.get(key);
  }

  public DescribeSObjectResult getDescribe(SObjectType sobjectToken) {
    if (sobjectToken == null) {
      return null;
    }
    DescribeSObjectResult described = describeByType.get(sobjectToken);
    if (described == null) {
      described = sobjectToken.getDescribe(SObjectDescribeOptions.DEFAULT);
      describeByType.put(sobjectToken, described);
    }
    return described;
  }

  public Map<String, SObjectField> getFieldMap(SObjectType sobjectToken) {
    Map<String, SObjectField> fields = fieldsByType.get(sobjectToken);
    if (fields == null && sobjectToken != null) {
      fields = getDescribe(sobjectToken).fields.getMap();
      fieldsByType.put(sobjectToken, fields);
    }
    return fields;
  }

  public Map<String, FieldSet> getFieldsetMap(SObjectType sobjectToken) {
    Map<String, FieldSet> fieldSets = fieldSetsByType.get(sobjectToken);
    if (fieldSets == null && sobjectToken != null) {
      fieldSets = getDescribe(sobjectToken).fieldSets.getMap();
      fieldSetsByType.put(sobjectToken, fieldSets);
    }
    return fieldSets;
  }

  public DescribeFieldResult getFieldDescribe(SObjectField field) {
    DescribeFieldResult described = describeByField.get(field);
    if (described == null && field != null) {
      described = field.getDescribe();
      describeByField.put(field, described);
    }
    return described;
  }

  public List<SObject> queryWithBinds(String soql, Map<String, Object> binds, System.AccessLevel mode) {
    return Database.queryWithBinds(soql, binds, mode);
  }

  public Database.QueryLocator getQueryLocatorWithBinds(String soql, Map<String, Object> binds, System.AccessLevel mode) {
    return Database.getQueryLocatorWithBinds(soql, binds, mode);
  }

  public Integer countQueryWithBinds(String soql, Map<String, Object> binds, System.AccessLevel mode) {
    return Database.countQueryWithBinds(soql, binds, mode);
  }

  public List<List<SObject>> search(String sosl, System.AccessLevel mode) {
    return Search.query(sosl, mode);
  }

  public Type getTypeForName(String className) {
    return Type.forName(className);
  }
}
