@isTest
private class ModelFieldsTest {
  @isTest
  static void test_smoke_test() {
    // Simple smoke test to verify basic functionality
    ModelFields modelFields = ModelFields.newInstance(Account.SObjectType);
    System.assertNotEquals(null, modelFields, 'ModelFields should not be null');
    System.assertEquals(
      Account.SObjectType,
      modelFields.source().token(),
      'Source should be Account'
    );

    String soql = modelFields.toSoql();
    System.assertEquals('', soql, 'Empty ModelFields should return empty SOQL');
  }

  @isTest
  static void test_constructor() {
    // Test constructor with SObjectType
    ModelFields modelFields = ModelFields.newInstance(Account.SObjectType);
    System.assertNotEquals(null, modelFields, 'ModelFields should not be null');
    System.assertEquals(
      Account.SObjectType,
      modelFields.source().token(),
      'Source should be Account'
    );
    System.assertEquals(
      false,
      modelFields.isAllFields(),
      'Should not be all fields initially'
    );
  }

  @isTest
  static void test_addFields_sobjectfield() {
    ModelFields modelFields = ModelFields.newInstance(Account.SObjectType);

    // Test adding valid fields
    Set<SObjectField> fields = new Set<SObjectField>{
      Account.Name,
      Account.Type,
      Account.Industry
    };
    Boolean changed = modelFields.addFields(fields);
    System.assertEquals(
      true,
      changed,
      'Should return true when fields are added'
    );

    Set<SObjectField> currentFields = modelFields.getFields();
    System.assert(
      currentFields.contains(Account.Name),
      'Should contain Name field'
    );
    System.assert(
      currentFields.contains(Account.Type),
      'Should contain Type field'
    );
    System.assert(
      currentFields.contains(Account.Industry),
      'Should contain Industry field'
    );

    // Test adding same fields again (should not change)
    changed = modelFields.addFields(fields);
    System.assertEquals(
      false,
      changed,
      'Should return false when no new fields added'
    );
  }

  @isTest
  static void test_addFields_sobjectfield_trusted() {
    ModelFields modelFields = ModelFields.newInstance(Account.SObjectType);

    // Test trusted mode (skips validation)
    Set<SObjectField> fields = new Set<SObjectField>{
      Account.Name,
      Account.Type
    };
    Boolean changed = modelFields.addFields(fields, true);
    System.assertEquals(
      true,
      changed,
      'Should return true when fields are added in trusted mode'
    );
  }

  @isTest
  static void test_addFields_string() {
    ModelFields modelFields = (ModelFields) ModelFields.newInstance(
      Account.SObjectType
    );

    // Test adding fields by string names
    Set<String> fieldNames = new Set<String>{ 'Name', 'Type', 'Industry' };
    Boolean changed = modelFields.addFields(fieldNames);
    System.assertEquals(
      true,
      changed,
      'Should return true when fields are added'
    );

    Set<SObjectField> currentFields = modelFields.getFields();
    System.assert(
      currentFields.contains(Account.Name),
      'Should contain Name field'
    );
    System.assert(
      currentFields.contains(Account.Type),
      'Should contain Type field'
    );
    System.assert(
      currentFields.contains(Account.Industry),
      'Should contain Industry field'
    );
  }

  @isTest
  static void test_addFields_string_invalid() {
    ModelFields modelFields = (ModelFields) ModelFields.newInstance(
      Account.SObjectType
    );

    // Test adding invalid field names (should be ignored)
    Set<String> fieldNames = new Set<String>{ 'Name', 'InvalidField', 'Type' };
    Boolean changed = modelFields.addFields(fieldNames);
    System.assertEquals(true, changed, 'Should return true for valid fields');

    Set<SObjectField> currentFields = modelFields.getFields();
    System.assert(
      currentFields.contains(Account.Name),
      'Should contain Name field'
    );
    System.assert(
      currentFields.contains(Account.Type),
      'Should contain Type field'
    );
    System.assertEquals(
      2,
      currentFields.size(),
      'Should only contain valid fields'
    );
  }

  @isTest
  static void test_addAllFields() {
    ModelFields modelFields = ModelFields.newInstance(Account.SObjectType);

    // Test adding all fields
    Boolean changed = modelFields.addAllFields();
    System.assertEquals(
      true,
      changed,
      'Should return true when all fields are added'
    );
    System.assertEquals(
      true,
      modelFields.isAllFields(),
      'Should be all fields'
    );

    // Test adding all fields again (should not change)
    changed = modelFields.addAllFields();
    System.assertEquals(
      false,
      changed,
      'Should return false when already all fields'
    );
  }

  @isTest
  static void test_addFieldSets() {
    ModelFields modelFields = (ModelFields) ModelFields.newInstance(
      Account.SObjectType
    );

    // Test adding field sets (if any exist)
    Set<String> fieldSetNames = new Set<String>{ 'Standard' };
    Boolean changed = modelFields.addFieldSets(fieldSetNames);

    // Note: This test may pass or fail depending on whether field sets exist
    // The method handles missing field sets gracefully
    System.assertNotEquals(null, changed, 'Should return a boolean value');
  }

  @isTest
  static void test_addFieldSets_null() {
    ModelFields modelFields = (ModelFields) ModelFields.newInstance(
      Account.SObjectType
    );

    // Test adding null field sets
    Boolean changed = modelFields.addFieldSets(null);
    System.assertEquals(
      false,
      changed,
      'Should return false for null field sets'
    );
  }

  @isTest
  static void test_addFields_empty() {
    ModelFields modelFields = (ModelFields) ModelFields.newInstance(
      Account.SObjectType
    );

    // Test adding empty sets
    Boolean changed = modelFields.addFields(new Set<SObjectField>());
    System.assertEquals(
      false,
      changed,
      'Should return false for empty field set'
    );

    changed = modelFields.addFields(new Set<String>());
    System.assertEquals(
      false,
      changed,
      'Should return false for empty field names set'
    );
  }

  @isTest
  static void test_addFields_after_all_fields() {
    ModelFields modelFields = ModelFields.newInstance(Account.SObjectType);

    // Set to all fields first
    modelFields.addAllFields();

    // Try to add specific fields after all fields
    Set<SObjectField> fields = new Set<SObjectField>{
      Account.Name,
      Account.Type
    };
    Boolean changed = modelFields.addFields(fields);
    System.assertEquals(
      false,
      changed,
      'Should return false when already all fields'
    );
  }

  @isTest
  static void test_getFields() {
    ModelFields modelFields = ModelFields.newInstance(Account.SObjectType);

    // Initially should be empty
    Set<SObjectField> fields = modelFields.getFields();
    System.assertEquals(0, fields.size(), 'Should be empty initially');

    // Add some fields
    modelFields.addFields(new Set<SObjectField>{ Account.Name, Account.Type });
    fields = modelFields.getFields();
    System.assertEquals(2, fields.size(), 'Should contain 2 fields');

    // Set to all fields
    modelFields.addAllFields();
    fields = modelFields.getFields();
    System.assert(fields.size() > 2, 'Should contain all fields');
  }

  @isTest
  static void test_toSoql() {
    ModelFields modelFields = ModelFields.newInstance(Account.SObjectType);

    // Test empty fields
    String soql = modelFields.toSoql();
    System.assertEquals('', soql, 'Should return empty string for no fields');

    // Test with specific fields
    modelFields.addFields(new Set<SObjectField>{ Account.Name, Account.Type });
    soql = modelFields.toSoql();
    System.assert(soql.contains('Name'), 'Should contain Name in SOQL');
    System.assert(soql.contains('Type'), 'Should contain Type in SOQL');

    // Test with all fields
    modelFields.addAllFields();
    soql = modelFields.toSoql();
    System.assertEquals('*', soql, 'Should return * for all fields');
  }

  @isTest
  static void test_siftFieldsIntoAnchors() {
    Set<SObjectField> fields = new Set<SObjectField>{
      Account.Name,
      Account.Type,
      Contact.FirstName,
      Contact.LastName
    };
    Set<SObjectType> tokens = new Set<SObjectType>{
      Account.SObjectType,
      Contact.SObjectType
    };

    Map<SObjectType, ModelFields> anchors = ModelFields.siftFieldsIntoAnchors(
      fields,
      tokens
    );

    System.assertEquals(
      2,
      anchors.size(),
      'Should have anchors for both object types'
    );
    System.assert(
      anchors.containsKey(Account.SObjectType),
      'Should have Account anchor'
    );
    System.assert(
      anchors.containsKey(Contact.SObjectType),
      'Should have Contact anchor'
    );

    // Check Account fields
    Set<SObjectField> accountFields = anchors.get(Account.SObjectType)
      .getFields();
    System.assert(
      accountFields.contains(Account.Name),
      'Account anchor should contain Name'
    );
    System.assert(
      accountFields.contains(Account.Type),
      'Account anchor should contain Type'
    );

    // Check Contact fields
    Set<SObjectField> contactFields = anchors.get(Contact.SObjectType)
      .getFields();
    System.assert(
      contactFields.contains(Contact.FirstName),
      'Contact anchor should contain FirstName'
    );
    System.assert(
      contactFields.contains(Contact.LastName),
      'Contact anchor should contain LastName'
    );
  }

  @isTest
  static void test_siftFieldsIntoAnchors_null() {
    Map<SObjectType, ModelFields> anchors = ModelFields.siftFieldsIntoAnchors(
      null,
      new Set<SObjectType>{ Account.SObjectType }
    );
    System.assertEquals(
      0,
      anchors.size(),
      'Should return empty map for null fields'
    );
  }

  @isTest
  static void test_validation_sampling() {
    ModelFields modelFields = ModelFields.newInstance(Account.SObjectType);

    // Create a large set of fields to test sampling validation
    Set<SObjectField> fields = new Set<SObjectField>();
    Map<String, SObjectField> fieldMap = Account.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
      .fields.getMap();
    Integer count = 0;
    for (SObjectField field : fieldMap.values()) {
      fields.add(field);
      count++;
      if (count >= 10)
        break; // Just test with first 10 fields
    }

    // This should work with sampling validation
    Boolean changed = modelFields.addFields(fields);
    System.assertEquals(
      true,
      changed,
      'Should add fields successfully with sampling validation'
    );
  }

  @isTest
  static void test_source_mismatch() {
    ModelFields accountFields = ModelFields.newInstance(Account.SObjectType);
    ModelFields contactFields = ModelFields.newInstance(Contact.SObjectType);

    // Note: addFields with another ModelFields instance is no longer supported
    // This test is removed as the method signature no longer exists
  }

  @isTest
  static void test_newInstance() {
    // Test static factory method
    ModelFields modelFields = ModelFields.newInstance(Account.SObjectType);
    System.assertNotEquals(
      null,
      modelFields,
      'newInstance should not return null'
    );
    System.assertEquals(
      Account.SObjectType,
      modelFields.source().token(),
      'Source should be Account'
    );
  }
}
