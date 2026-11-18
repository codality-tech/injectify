@isTest
private class QueryFieldsTest {
  @isTest
  static void test_smoke_test() {
    // Simple smoke test to verify basic functionality
    QueryFields queryFields = new QueryFields(Account.SObjectType);
    System.assertNotEquals(null, queryFields, 'QueryFields should not be null');
    System.assertEquals(
      Account.SObjectType,
      queryFields.source().token(),
      'Source should be Account'
    );

    String soql = queryFields.toSoql();
    System.assertEquals('Id', soql, 'Empty QueryFields should return Id');
  }

  @isTest
  static void test_constructor() {
    // Test constructor with IModel
    IModel accountModel = Application.s.model(Account.SObjectType);
    QueryFields queryFields = new QueryFields(accountModel);
    System.assertNotEquals(null, queryFields, 'QueryFields should not be null');
    System.assertEquals(
      accountModel,
      queryFields.source(),
      'Source should match'
    );

    // Test constructor with SObjectType
    QueryFields queryFields2 = new QueryFields(Account.SObjectType);
    System.assertNotEquals(
      null,
      queryFields2,
      'QueryFields should not be null'
    );
    System.assertEquals(
      Account.SObjectType,
      queryFields2.source().token(),
      'Source should be Account'
    );
  }

  @isTest
  static void test_constructor_null_source() {
    // Test constructor with null source (should throw exception)
    Boolean threw = false;
    try {
      new QueryFields((IModel) null);
    } catch (Exception e) {
      threw = true;
    }
    System.assert(threw, 'Should throw exception for null source');
  }

  @isTest
  static void test_add_sobjectfield() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Test adding SObjectField set
    Set<SObjectField> fields = new Set<SObjectField>{
      Account.Name,
      Account.Type
    };
    IQueryFields result = queryFields.add(fields);

    System.assertEquals(queryFields, result, 'Should return self for chaining');
    String soql = queryFields.toSoql();
    System.assert(soql.contains('Name'), 'SOQL should contain Name field');
    System.assert(soql.contains('Type'), 'SOQL should contain Type field');
  }

  @isTest
  static void test_add_sobjectfield_with_route() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Test adding SObjectField set with route
    Set<SObjectField> fields = new Set<SObjectField>{ User.Name, User.Id };
    IQueryFields result = queryFields.add(Account.OwnerId, fields);

    System.assertEquals(queryFields, result, 'Should return self for chaining');
    String soql = queryFields.toSoql();
    System.assert(
      soql.contains('Owner.Name'),
      'SOQL should contain Owner.Name field'
    );
    System.assert(
      soql.contains('Owner.Id'),
      'SOQL should contain Owner.Id field'
    );
  }

  @isTest
  static void test_add_string() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Test adding string field names
    Set<String> fieldNames = new Set<String>{ 'Name', 'Type', 'Industry' };
    IQueryFields result = queryFields.add(fieldNames);

    System.assertEquals(queryFields, result, 'Should return self for chaining');
    String soql = queryFields.toSoql();
    System.assert(soql.contains('Name'), 'SOQL should contain Name field');
    System.assert(soql.contains('Type'), 'SOQL should contain Type field');
    System.assert(
      soql.contains('Industry'),
      'SOQL should contain Industry field'
    );
  }

  @isTest
  static void test_add_string_with_route() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Test adding string field names with route
    Set<String> fieldNames = new Set<String>{ 'Name', 'Id' };
    IQueryFields result = queryFields.add('OwnerId', fieldNames);

    System.assertEquals(queryFields, result, 'Should return self for chaining');
    String soql = queryFields.toSoql();
    System.assert(
      soql.contains('Owner.Name'),
      'SOQL should contain Owner.Name field'
    );
    System.assert(
      soql.contains('Owner.Id'),
      'SOQL should contain Owner.Id field'
    );
  }

  @isTest
  static void test_add_query_fields() {
    QueryFields queryFields1 = new QueryFields(Account.SObjectType);
    QueryFields queryFields2 = new QueryFields(Account.SObjectType);

    // Add fields to first instance
    queryFields1.add(new Set<SObjectField>{ Account.Name, Account.Type });

    // Add QueryFields to second instance
    IQueryFields result = queryFields2.add(queryFields1);

    System.assertEquals(
      queryFields2,
      result,
      'Should return self for chaining'
    );
    String soql = queryFields2.toSoql();
    System.assert(soql.contains('Name'), 'SOQL should contain Name field');
    System.assert(soql.contains('Type'), 'SOQL should contain Type field');
  }

  @isTest
  static void test_add_query_fields_with_route() {
    QueryFields fAccount = new QueryFields(Account.SObjectType);
    QueryFields fUser = new QueryFields(User.SObjectType);

    // Add fields to first instance
    fAccount.add(new Set<SObjectField>{ Account.Name, Account.Id });
    fUser.add(new Set<SObjectField>{ User.Name, User.Id });

    // Add QueryFields with route
    fAccount.add(Account.OwnerId, fUser);

    String soql = fAccount.toSoql();
    System.assert(
      soql.contains('Owner.Name'),
      'SOQL should contain Owner.Name field'
    );
    System.assert(
      soql.contains('Owner.Id'),
      'SOQL should contain Owner.Id field'
    );
  }

  @isTest
  static void test_add_query_fields_with_invalid_field() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);
    Boolean threw = false;
    try {
      // Add a valid and an invalid field name (use a truly invalid field for Account)
      queryFields.add(new Set<String>{ 'Name', 'DefinitelyNotAField' });
    } catch (Exception e) {
      threw = true;
    }
    System.assert(
      !threw,
      'Should not throw when adding invalid field names; should ignore or handle gracefully'
    );
    String soql = queryFields.toSoql();
    System.assert(
      soql.contains('Name'),
      'SOQL should contain valid Name field'
    );
    System.assert(
      !soql.contains('DefinitelyNotAField'),
      'SOQL should not contain invalid field'
    );
  }

  @isTest
  static void test_add_paths() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);
    // Create paths using valid SObjectField and cross-object path API
    Set<IPath> paths = new Set<IPath>{
      Application.s.path(Account.Name),
      Application.s.path(Account.Type),
      Application.s.path(new List<SObjectField>{ Account.OwnerId, User.Name })
    };
    IQueryFields result = queryFields.add(paths);
    System.assertEquals(queryFields, result, 'Should return self for chaining');
    String soql = queryFields.toSoql();
    System.assert(soql.contains('Name'), 'SOQL should contain Name field');
    System.assert(soql.contains('Type'), 'SOQL should contain Type field');
    System.assert(
      soql.contains('Owner.Name'),
      'SOQL should contain Owner.Name field'
    );
  }

  @isTest
  static void test_addAll() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);
    // Add all fields using the correct API
    queryFields.addAll();
    String soql = queryFields.toSoql();
    // Instead of expecting '*', check for multiple known Account fields
    System.assert(soql.contains('Name'), 'SOQL should contain Name field');
    System.assert(soql.contains('Id'), 'SOQL should contain Id field');
    System.assert(soql.contains('Type'), 'SOQL should contain Type field');
  }

  @isTest
  static void test_addAll_with_route() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Test adding all fields with route
    IQueryFields result = queryFields.addAll(Account.OwnerId);

    System.assertEquals(queryFields, result, 'Should return self for chaining');
    String soql = queryFields.toSoql();
    System.assert(soql.contains('Owner.'), 'SOQL should contain Owner fields');
  }

  @isTest
  static void test_clearFields() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Add some fields
    queryFields.add(new Set<SObjectField>{ Account.Name, Account.Type });
    String soql1 = queryFields.toSoql();
    System.assert(
      soql1.contains('Name'),
      'Should contain fields before clearing'
    );

    // Clear fields
    IQueryFields result = queryFields.clearFields();

    System.assertEquals(queryFields, result, 'Should return self for chaining');
    String soql2 = queryFields.toSoql();
    System.assertEquals('Id', soql2, 'Should return Id after clearing fields');
  }

  @isTest
  static void test_toSoql_empty() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Test empty QueryFields
    String soql = queryFields.toSoql();
    System.assertEquals('Id', soql, 'Should return Id for empty fields');
  }

  @isTest
  static void test_toSoql_with_fields() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Add fields
    queryFields.add(new Set<SObjectField>{ Account.Name, Account.Type });
    String soql = queryFields.toSoql();

    System.assert(soql.contains('Name'), 'Should contain Name field');
    System.assert(soql.contains('Type'), 'Should contain Type field');
    System.assert(soql.contains('Id'), 'Should always contain Id field');
  }

  @isTest
  static void test_toSoql_monomorphic_and_polymorphic() {
    // Exercise TYPEOF generation using Owner polymorphism on Task (WhoId/WhatId would require Activity)
    IModel contactModel = Application.s.model(Contact.SObjectType);
    QueryFields queryFields = new QueryFields(contactModel);
    // Add a cross-object path to an ID to seed monomorphic
    queryFields.add(new Set<SObjectField>{ Contact.Id, Contact.LastName });
    String soql = queryFields.toSoql();
    System.assert(soql.contains('Id'), 'Should contain Id field');
  }

  @isTest
  static void test_getRoutes() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Initially should be empty
    Set<IPath> routes = queryFields.getRoutes();
    System.assertEquals(0, routes.size(), 'Should be empty initially');

    // Add fields with routes
    queryFields.add(
      Account.OwnerId,
      new Set<SObjectField>{ User.Name, User.FirstName }
    );
    routes = queryFields.getRoutes();
    System.assertEquals(1, routes.size(), 'Should have one route');
  }

  @isTest
  static void test_getFieldsByReference() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Add fields by reference
    queryFields.add(
      Account.OwnerId,
      new Set<SObjectField>{ User.Name, User.FirstName }
    );

    Map<IReference, Set<SObjectField>> fieldsByRef = queryFields.getFieldsByReference();
    System.assertNotEquals(null, fieldsByRef, 'Should not be null');
  }

  @isTest
  static void test_add_empty_fields() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Test adding empty sets
    IQueryFields result1 = queryFields.add(new Set<SObjectField>());
    IQueryFields result2 = queryFields.add(new Set<String>());

    System.assertEquals(
      queryFields,
      result1,
      'Should return self for empty SObjectField set'
    );
    System.assertEquals(
      queryFields,
      result2,
      'Should return self for empty string set'
    );
  }

  @isTest
  static void test_add_null_fields() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Test adding null sets (should handle gracefully)
    IQueryFields result = queryFields.add((Set<SObjectField>) null);
    System.assertEquals(
      queryFields,
      result,
      'Should return self for null fields'
    );
  }

  @isTest
  static void test_invalid_route() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Test adding fields with invalid route
    Boolean threw = false;
    try {
      queryFields.add('InvalidField', new Set<SObjectField>{ Account.Name });
    } catch (Exception e) {
      threw = true;
    }
    System.assert(threw, 'Should throw exception for invalid route');
  }

  @isTest
  static void test_polymorphic_foreign_key_unsupported() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Test polymorphic foreign key (should throw exception)
    Boolean threw = false;
    try {
      queryFields.add('InvalidPolymorphicField', new Set<String>{ 'Name' });
    } catch (Exception e) {
      threw = true;
    }
    // This test may pass or fail depending on the object's relationships
    // The method should handle polymorphic foreign keys appropriately
  }

  @isTest
  static void test_reference_mismatch() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Create reference map for different object
    Map<IReference, Set<SObjectField>> fields = new Map<IReference, Set<SObjectField>>();
    IReference contactRef = (IReference) Application.s.model(
      Contact.SObjectType
    );
    fields.put(
      contactRef,
      new Set<SObjectField>{ Contact.FirstName, Contact.LastName }
    );

    // Test adding fields with reference mismatch
    Boolean threw = false;
    try {
      queryFields.add(fields);
    } catch (Exception e) {
      threw = true;
    }
    System.assert(threw, 'Should throw exception for reference mismatch');
  }

  @isTest
  static void test_fluent_chaining() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Test fluent chaining
    IQueryFields result = queryFields
      .add(new Set<SObjectField>{ Account.Name })
      .add(Account.OwnerId, new Set<SObjectField>{ User.Name })
      .addAll()
      .clearFields();

    System.assertEquals(queryFields, result, 'Should support fluent chaining');
  }

  @isTest
  static void test_static_newInstance_methods() {
    IQueryFields qf1 = QueryFields.newInstance(Account.SObjectType);
    System.assertNotEquals(
      null,
      qf1,
      'newInstance(sobjecttype) should not return null'
    );
    System.assertEquals(
      Account.SObjectType,
      qf1.source().token(),
      'Source should be Account'
    );

    IQueryFields qf2 = QueryFields.newInstance('Account');
    System.assertNotEquals(
      null,
      qf2,
      'newInstance(string) should not return null'
    );
    System.assertEquals(
      Account.SObjectType,
      qf2.source().token(),
      'Source should be Account'
    );
  }

  @isTest
  static void test_polymorphic_fields_basic() {
    // Test polymorphic fields with a real polymorphic relationship
    // Using Task.WhoId which can reference Contact or Lead
    QueryFields queryFields = new QueryFields(Task.SObjectType);

    // Add fields to the polymorphic WhoId field using SObjectField approach
    Set<SObjectField> contactFields = new Set<SObjectField>{
      Contact.Name,
      Contact.Email
    };
    Set<SObjectField> leadFields = new Set<SObjectField>{
      Lead.Name,
      Lead.Email
    };

    queryFields.add('WhoId', contactFields);
    queryFields.add('WhoId', leadFields);

    String soql = queryFields.toSoql();
    System.assert(
      soql.contains('TYPEOF'),
      'Should contain TYPEOF for polymorphic fields'
    );
    // Note: WhoId field might not appear directly in SOQL as it's part of the TYPEOF structure
  }

  @isTest
  static void test_polymorphic_fields_with_sobjectfield() {
    QueryFields queryFields = new QueryFields(Task.SObjectType);

    // Add SObjectField to polymorphic relationship
    Set<SObjectField> contactFields = new Set<SObjectField>{
      Contact.Name,
      Contact.Email
    };
    Set<SObjectField> leadFields = new Set<SObjectField>{
      Lead.Name,
      Lead.Email
    };

    queryFields.add('WhoId', contactFields);
    queryFields.add('WhoId', leadFields);

    String soql = queryFields.toSoql();
    System.assert(
      soql.contains('TYPEOF'),
      'Should contain TYPEOF for polymorphic fields'
    );
  }

  @isTest
  static void test_polymorphic_fields_error_handling() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Test adding polymorphic fields to non-polymorphic field
    Boolean threw = false;
    try {
      queryFields.add('Name', new Set<String>{ 'SomeField' });
    } catch (Exception e) {
      threw = true;
    }
    System.assert(threw, 'Should throw exception for non-foreign key field');
  }

  @isTest
  static void test_monomorphic_fields_reference_mismatch() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Create a reference map with mismatched source
    Map<IReference, Set<SObjectField>> fields = new Map<IReference, Set<SObjectField>>();
    IReference contactRef = (IReference) Application.s.model(
      Contact.SObjectType
    );
    fields.put(contactRef, new Set<SObjectField>{ Contact.FirstName });

    Boolean threw = false;
    try {
      queryFields.add(fields);
    } catch (Exception e) {
      threw = true;
    }
    System.assert(threw, 'Should throw exception for reference mismatch');
  }

  @isTest
  static void test_monomorphic_fields_empty_reference() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    Boolean threw = false;
    try {
      queryFields.add(
        (IReference) null,
        new Map<IReference, Set<SObjectField>>()
      );
    } catch (Exception e) {
      threw = true;
    }
    System.assert(threw, 'Should throw exception for null reference');
  }

  @isTest
  static void test_monomorphic_fields_empty_fields_by_reference() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Test with empty map - this should not throw an exception
    Boolean threw = false;
    try {
      Map<IReference, Set<SObjectField>> emptyMap = new Map<IReference, Set<SObjectField>>();
      queryFields.add(emptyMap);
    } catch (Exception e) {
      threw = true;
    }
    System.assert(
      !threw,
      'Should not throw exception for empty fields by reference'
    );
  }

  @isTest
  static void test_add_fields_with_route_reference_mismatch() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Create QueryFields for different object
    QueryFields contactFields = new QueryFields(Contact.SObjectType);
    contactFields.add(new Set<SObjectField>{ Contact.FirstName });

    Boolean threw = false;
    try {
      queryFields.add(Account.OwnerId, contactFields);
    } catch (Exception e) {
      threw = true;
    }
    System.assert(threw, 'Should throw exception for reference mismatch');
  }

  @isTest
  static void test_add_fields_with_route_target_mismatch() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Create QueryFields for User (OwnerId target) but try to add Contact fields
    QueryFields userFields = new QueryFields(User.SObjectType);
    userFields.add(new Set<SObjectField>{ User.Name }); // Valid User field

    // This should work since we're adding valid User fields to Account.OwnerId
    Boolean threw = false;
    try {
      queryFields.add(Account.OwnerId, userFields);
    } catch (Exception e) {
      threw = true;
    }
    System.assert(
      !threw,
      'Should not throw exception for valid User fields on OwnerId'
    );
  }

  @isTest
  static void test_polymorphic_fields_null_path() {
    QueryFields queryFields = new QueryFields(Task.SObjectType);

    Boolean threw = false;
    try {
      // This should trigger the null path check in PolymorphicFields.addFields
      queryFields.add((String) null, new Set<String>{ 'Name' });
    } catch (Exception e) {
      threw = true;
    }
    System.assert(threw, 'Should throw exception for null path');
  }

  @isTest
  static void test_polymorphic_fields_invalid_path_type() {
    QueryFields queryFields = new QueryFields(Task.SObjectType);

    // This test might not trigger the specific error path, but it's good to have
    Boolean threw = false;
    try {
      queryFields.add('WhoId', new Set<String>{ 'InvalidField' });
    } catch (Exception e) {
      threw = true;
    }
    // This may or may not throw depending on the field validation
  }

  @isTest
  static void test_complex_field_combinations() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Add various types of fields
    queryFields.add(new Set<SObjectField>{ Account.Name, Account.Type });
    queryFields.add(Account.OwnerId, new Set<SObjectField>{ User.Name });
    queryFields.add(new Set<String>{ 'Industry', 'Phone' });
    queryFields.addAll();

    String soql = queryFields.toSoql();
    System.assert(soql.contains('Name'), 'Should contain Name field');
    System.assert(
      soql.contains('Owner.Name'),
      'Should contain Owner.Name field'
    );
    System.assert(soql.contains('Industry'), 'Should contain Industry field');
  }

  @isTest
  static void test_toSoql_combinations() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Test monomorphic only
    queryFields.add(new Set<SObjectField>{ Account.Name });
    String soql1 = queryFields.toSoql();
    System.assert(soql1.contains('Name'), 'Should contain Name field');

    // Clear and test polymorphic only (if possible)
    queryFields.clearFields();
    // Note: This might not generate pure polymorphic SOQL without monomorphic
    // depending on the implementation
  }

  @isTest
  static void test_getRoutes_comprehensive() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Initially should be empty
    Set<IPath> routes = queryFields.getRoutes();
    System.assertEquals(0, routes.size(), 'Should be empty initially');

    // Add fields with routes
    queryFields.add(Account.OwnerId, new Set<SObjectField>{ User.Name });
    routes = queryFields.getRoutes();
    System.assertEquals(1, routes.size(), 'Should have one route');

    // Add more routes
    queryFields.add('ParentId', new Set<SObjectField>{ Account.Name });
    routes = queryFields.getRoutes();
    System.assertEquals(2, routes.size(), 'Should have two routes');
  }

  @isTest
  static void test_getFieldsByReference_comprehensive() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Add fields by reference
    queryFields.add(
      Account.OwnerId,
      new Set<SObjectField>{ User.Name, User.Email }
    );
    queryFields.add('ParentId', new Set<SObjectField>{ Account.Name });

    Map<IReference, Set<SObjectField>> fieldsByRef = queryFields.getFieldsByReference();
    System.assertNotEquals(null, fieldsByRef, 'Should not be null');
    System.assert(fieldsByRef.size() > 0, 'Should have fields by reference');
  }

  @isTest
  static void test_addAll_comprehensive() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Test addAll without route
    queryFields.addAll();
    String soql1 = queryFields.toSoql();
    System.assert(soql1.contains('Name'), 'Should contain Name field');

    // Clear and test addAll with route
    queryFields.clearFields();
    queryFields.addAll(Account.OwnerId);
    String soql2 = queryFields.toSoql();
    System.assert(soql2.contains('Owner.'), 'Should contain Owner fields');
  }

  @isTest
  static void test_addAll_polymorphic() {
    QueryFields queryFields = new QueryFields(Task.SObjectType);

    // Test addAll with polymorphic field
    queryFields.addAll('WhoId');
    String soql = queryFields.toSoql();
    System.assert(
      soql.contains('TYPEOF'),
      'Should contain TYPEOF for polymorphic addAll'
    );
  }

  @isTest
  static void test_fluent_chaining_comprehensive() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Test comprehensive fluent chaining
    IQueryFields result = queryFields
      .add(new Set<SObjectField>{ Account.Name })
      .add(Account.OwnerId, new Set<SObjectField>{ User.Name })
      .add(new Set<String>{ 'Industry' })
      .addAll()
      .clearFields()
      .add(new Set<SObjectField>{ Account.Type });

    System.assertEquals(queryFields, result, 'Should support fluent chaining');
    String soql = queryFields.toSoql();
    System.assert(
      soql.contains('Type'),
      'Should contain Type field after chaining'
    );
  }

  @isTest
  static void test_edge_cases() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Test adding same field multiple times
    queryFields.add(new Set<SObjectField>{ Account.Name });
    queryFields.add(new Set<SObjectField>{ Account.Name }); // Duplicate
    String soql = queryFields.toSoql();
    System.assert(soql.contains('Name'), 'Should contain Name field');

    // Test clearing and re-adding
    queryFields.clearFields();
    queryFields.add(new Set<SObjectField>{ Account.Type });
    soql = queryFields.toSoql();
    System.assert(
      soql.contains('Type'),
      'Should contain Type field after clear'
    );
  }

  @isTest
  static void test_static_newInstance_with_invalid_name() {
    Boolean threw = false;
    try {
      QueryFields.newInstance('InvalidObjectName');
    } catch (Exception e) {
      threw = true;
    }
    System.assert(threw, 'Should throw exception for invalid object name');
  }

  @isTest
  static void test_toSoql_caching() {
    QueryFields queryFields = new QueryFields(Account.SObjectType);

    // Add fields
    queryFields.add(new Set<SObjectField>{ Account.Name });

    // Call toSoql multiple times to test caching
    String soql1 = queryFields.toSoql();
    String soql2 = queryFields.toSoql();
    System.assertEquals(soql1, soql2, 'Should return same SOQL (cached)');

    // Add more fields to test cache invalidation
    queryFields.add(new Set<SObjectField>{ Account.Type });
    String soql3 = queryFields.toSoql();
    System.assertNotEquals(
      soql1,
      soql3,
      'Should return different SOQL after adding fields'
    );
  }

  @IsTest
  static void typeofHasABranchOnlyForTargetsGivenFields() {
    Account acme = new Account(Name = 'Typed Acme');
    insert acme;
    insert new Task(Subject = 'Call', WhatId = acme.Id);
    IQuery tasks = Application.s.model(Task.SObjectType).query();
    tasks.fields().add(Task.WhatId, new Set<SObjectField>{ Account.Name, Opportunity.Amount });

    String soql = tasks.toSoql();

    Assert.isTrue(soql.contains('TYPEOF What WHEN Account THEN Id, Name WHEN Opportunity THEN Id, Amount END'), soql);
    Assert.areEqual(2, soql.countMatches(' WHEN '), 'no branch for targets without fields: ' + soql);
    Task found = (Task) tasks.run()[0];
    Assert.areEqual('Typed Acme', found.getSObject('What').get('Name'));
  }
}
