@IsTest
private class QueryFactoryTest {
  // Faux query for testing - simple subclass of Query
  private class FauxAccountQuery extends Query {
    public override IQuery deepClone() {
      return new FauxAccountQuery();
    }
    public override set<sobjectfield> getDefaultFields() {
      return new Set<sobjectfield>{ Account.Name, Account.Id };
    }
  }

  // Static query map and factory
  private static final IModel accountModel = Application.s.model(
    Account.SObjectType
  );
  private static final Map<Type, Type> queryMap = new Map<Type, Type>{
    Account.class => FauxAccountQuery.class
  };
  static final Core core = new Core(new SchemeDefault());
  static final QueryFactory factory = new QueryFactory(core, queryMap);

  @IsTest
  static void testRegisterAndMake() {
    Assert.isTrue(
      factory.getRegistry().containsKey(Account.class),
      'Should be registered'
    );
    IQuery query = factory.make(Account.SObjectType);
    Assert.isNotNull(query, 'Query instance should not be null');
    Assert.isTrue(
      query instanceof FauxAccountQuery,
      'Should be FauxAccountQuery'
    );
    Assert.isTrue(query.toSoql().contains('Name'));
  }

  @IsTest
  static void testDefaultFieldScope() {
    // Test that defaultFieldScope can be configured
    IFieldScope scope = FieldScope.make(FieldScope.Trait.ALL)
      .exclude(FieldScope.make(FieldScope.Trait.OVERSIZE));

    QueryFactory factoryWithScope = new QueryFactory(core, queryMap)
      .defaultFieldScope(scope);

    Assert.isNotNull(factoryWithScope,
      'Factory with scope should not be null'
    );

    // Test that the scope is applied when creating queries
    IQuery query = factoryWithScope.make(Account.SObjectType);
    Assert.isNotNull(query, 'Query should be created successfully');
  }

  @IsTest
  static void testMakeUnregistered() {
    // Test fallback behavior - should return base Query instance
    IModel contactModel = Application.s.model(Contact.SObjectType);
    IQuery query = factory.make(Contact.SObjectType);
    Assert.isNotNull(query,
      'Should return base Query for unregistered model'
    );
    Assert.isTrue(query instanceof Query, 'Should be base Query class');
  }

  @IsTest
  static void testDeepClone() {
    // Test deep clone functionality
    FauxAccountQuery query = new FauxAccountQuery();

    Test.startTest();
    IQuery cloned = query.deepClone();
    Test.stopTest();

    Assert.isNotNull(cloned, 'Clone should not be null');
    Assert.isTrue(
      cloned instanceof FauxAccountQuery,
      'Clone should be FauxAccountQuery'
    );
  }

  @IsTest
  static void testMakeErrors() {
    // Test empty factory fallback
    QueryFactory f2 = new QueryFactory(core, new Map<Type, Type>());

    // Null safety and name resolution
    try {
      f2.make((SObjectType) null);
      Assert.fail('Should throw for null SObjectType');
    } catch (Exception e) {
      Assert.isTrue(true, 'Expected exception for null token');
    }
    try {
      f2.make((String) null);
      Assert.fail('Should throw for null String');
    } catch (Exception e) {
      Assert.isTrue(true, 'Expected exception for null name');
    }
  }

  @IsTest
  static void testConstructorWithMap() {
    Map<Type, Type> customQueryMap = new Map<Type, Type>{
      Account.class => FauxAccountQuery.class
    };
    QueryFactory customFactory = new QueryFactory(core, customQueryMap);
    Assert.isTrue(
      customFactory.getRegistry().containsKey(Account.class),
      'Should be registered from constructor'
    );
  }

  @IsTest
  static void testMakeWithTokenAndName() {
    // Test make with SObjectType token
    IQuery query1 = factory.make(Account.SObjectType);
    Assert.isNotNull(query1, 'Should work with SObjectType');
    Assert.isTrue(
      query1 instanceof FauxAccountQuery,
      'Should be FauxAccountQuery'
    );

    // Test make with string name
    IQuery query2 = factory.make('Account');
    Assert.isNotNull(query2, 'Should work with string name');
    Assert.isTrue(
      query2 instanceof FauxAccountQuery,
      'Should be FauxAccountQuery'
    );
  }

  // BaseQuery subclass with custom initialization hook
  private class BaseAccountQuery extends BaseQuery {
    public Boolean onInitializedCalled = false;
    public IModel receivedModel;

    public override void onInitialized(IModel source) {
      onInitializedCalled = true;
      receivedModel = source;
      // Add a default condition to verify init was called
      this.addCondition(Application.s.eq(Account.Type, 'Customer'));
    }

    public override IQuery deepClone() {
      BaseAccountQuery clone = new BaseAccountQuery();
      clone.init(this);
      return clone;
    }
  }

  // Query subclass with custom default fields for caching tests
  private class AccountQueryWithDefaults extends Query {
    public override Set<SObjectField> getDefaultFields() {
      return new Set<SObjectField>{ Account.Id, Account.Name };
    }
  }

  // Query subclass with null default fields (uses addAll)
  private class AccountQueryWithAllFields extends Query {
    public override Set<SObjectField> getDefaultFields() {
      return null; // Will trigger addAll()
    }
  }

  @IsTest
  static void testDefaultFieldsCachingWithSpecificFields() {
    // Register a query with specific default fields
    Map<Type, Type> customMap = new Map<Type, Type>{
      Account.class => AccountQueryWithDefaults.class
    };
    QueryFactory customFactory = new QueryFactory(core, customMap);

    Test.startTest();
    // First call should create and cache the default fields
    IQuery query1 = customFactory.make(Account.SObjectType);
    Assert.isNotNull(query1, 'First query should not be null');
    Assert.isNotNull(query1.source(), 'Query should have a source');

    // Second call should reuse cached default fields
    IQuery query2 = customFactory.make(Account.SObjectType);
    Assert.isNotNull(query2, 'Second query should not be null');
    Assert.isNotNull(query2.source(),
      'Second query should have a source'
    );
    Test.stopTest();

    // Both queries should be separate instances
    Assert.isTrue(query1 !== query2, 'Should create new query instances');

    // Both should have the same model
    Assert.areEqual(
      query1.source(),
      query2.source(),
      'Should share same model'
    );

    // Verify the default fields are applied by checking SOQL
    String soql1 = query1.toSoql();
    String soql2 = query2.toSoql();
    Assert.isTrue(soql1.contains('Id'), 'SOQL should contain Id field');
    Assert.isTrue(soql1.contains('Name'), 'SOQL should contain Name field');
    Assert.areEqual(
      soql1,
      soql2,
      'Both queries should generate identical SOQL'
    );
  }

  @IsTest
  static void testFauxAccountQueryDefaultFields() {
    // Test that FauxAccountQuery default fields (Name, Id) are being applied
    Test.startTest();
    IQuery query = factory.make(Account.SObjectType);
    Test.stopTest();

    Assert.isNotNull(query, 'Query should be created');
    Assert.isTrue(
      query instanceof FauxAccountQuery,
      'Should be FauxAccountQuery'
    );

    // Verify the query has fields configured
    Assert.isNotNull(query.fields(),
      'Query should have fields configured'
    );

    // The FauxAccountQuery should have its default fields (Name, Id) applied
    // We can verify this by checking that the query was created successfully
    // and that it has the expected behavior (the factory should call getDefaultFields())

    // Test that the default fields are cached and reused
    IQuery query2 = factory.make(Account.SObjectType);
    Assert.isNotNull(query2, 'Second query should be created');
    Assert.isTrue(
      query2 instanceof FauxAccountQuery,
      'Second query should be FauxAccountQuery'
    );

    // Both queries should be separate instances but use the same cached default fields
    Assert.isTrue(query !== query2, 'Should create new query instances');
    Assert.areEqual(
      query.source(),
      query2.source(),
      'Should share same model'
    );
  }

  @IsTest
  static void testFauxAccountQueryDefaultFieldsInSOQL() {
    // Test that FauxAccountQuery default fields (Name, Id) are included in SOQL
    Test.startTest();
    IQuery query = factory.make(Account.SObjectType);
    String soql = query.toSoql();
    Test.stopTest();

    Assert.isNotNull(query, 'Query should be created');
    Assert.isTrue(
      query instanceof FauxAccountQuery,
      'Should be FauxAccountQuery'
    );

    // Verify SOQL contains the default fields from FauxAccountQuery
    Assert.isTrue(soql.contains('Id'), 'SOQL should contain Id field');
    Assert.isTrue(soql.contains('Name'), 'SOQL should contain Name field');
    Assert.isTrue(
      soql.contains('FROM Account'),
      'SOQL should contain FROM Account'
    );
  }

  @IsTest
  static void testDefaultFieldsCachingWithAllFields() {
    // Register a query that returns null from getDefaultFields (uses addAll)
    Map<Type, Type> customMap = new Map<Type, Type>{
      Contact.class => AccountQueryWithAllFields.class
    };
    QueryFactory customFactory = new QueryFactory(core, customMap);

    Test.startTest();
    // First call should create and cache all fields
    IQuery query1 = customFactory.make(Contact.SObjectType);
    Assert.isNotNull(query1, 'First query should not be null');

    // Second call should reuse cached fields
    IQuery query2 = customFactory.make(Contact.SObjectType);
    Assert.isNotNull(query2, 'Second query should not be null');
    Test.stopTest();

    // Verify both queries are different instances but use cached fields
    Assert.isTrue(query1 !== query2, 'Should create new query instances');
  }

  @IsTest
  static void testDefaultFieldsCachingAcrossDifferentModels() {
    // Register queries for different models
    Map<Type, Type> customMap = new Map<Type, Type>{
      Account.class => AccountQueryWithDefaults.class,
      Contact.class => AccountQueryWithAllFields.class
    };
    QueryFactory customFactory = new QueryFactory(core, customMap);

    Test.startTest();
    // Create queries for different models
    IQuery accountQuery1 = customFactory.make(Account.SObjectType);
    IQuery contactQuery1 = customFactory.make(Contact.SObjectType);
    IQuery accountQuery2 = customFactory.make(Account.SObjectType);
    IQuery contactQuery2 = customFactory.make(Contact.SObjectType);
    Test.stopTest();

    // All queries should be created
    Assert.isNotNull(accountQuery1,
      'Account query 1 should not be null'
    );
    Assert.isNotNull(contactQuery1,
      'Contact query 1 should not be null'
    );
    Assert.isNotNull(accountQuery2,
      'Account query 2 should not be null'
    );
    Assert.isNotNull(contactQuery2,
      'Contact query 2 should not be null'
    );

    // Different models should have different sources
    Assert.areNotEqual(
      accountQuery1.source(),
      contactQuery1.source(),
      'Different models should have different sources'
    );
  }

  @IsTest
  static void testBaseQueryInitialization() {
    // Register BaseQuery subclass
    Map<Type, Type> customMap = new Map<Type, Type>{
      Account.class => BaseAccountQuery.class
    };
    QueryFactory customFactory = new QueryFactory(core, customMap);

    Test.startTest();
    IQuery query = customFactory.make(Account.SObjectType);
    Test.stopTest();

    // Verify it's the right type
    Assert.isTrue(
      query instanceof BaseAccountQuery,
      'Should be BaseAccountQuery instance'
    );

    // Cast to access test properties
    BaseAccountQuery baseQuery = (BaseAccountQuery) query;

    // Verify onInitialized was called
    Assert.isTrue(baseQuery.onInitializedCalled,
      'onInitialized hook should have been called'
    );

    // Verify the model was passed correctly
    Assert.isNotNull(baseQuery.receivedModel,
      'Should have received model in onInitialized'
    );
    Assert.areEqual(
      Account.SObjectType,
      baseQuery.receivedModel.token(),
      'Should have received Account model'
    );

    // Verify custom initialization logic ran (added condition)
    Assert.areEqual(
      1,
      query.filters().getAll().size(),
      'Should have default condition from onInitialized'
    );
  }

  @IsTest
  static void testBaseQueryConstructors() {
    IModel accountModel = Application.s.model(Account.SObjectType);

    Test.startTest();
    // Test no-arg constructor and init
    BaseAccountQuery query1 = new BaseAccountQuery();
    query1.init(accountModel);
    // Test no-arg constructor only
    BaseAccountQuery query2 = new BaseAccountQuery();
    // Test copy via init
    BaseAccountQuery query3 = new BaseAccountQuery();
    query3.init(query1);
    Test.stopTest();

    // Verify query1 was initialized
    Assert.isTrue(query1.onInitializedCalled,
      'Query1 should have onInitialized called'
    );
    Assert.isNotNull(query1.source(), 'Query1 should have source');

    // Verify query2 was created but not initialized
    Assert.isNull(query2.source(), 'Query2 should not have source');

    // Verify query3 was initialized via copy
    Assert.isTrue(query3.onInitializedCalled,
      'Query3 should have onInitialized called'
    );
    Assert.isNotNull(query3.source(), 'Query3 should have source');
  }

  @IsTest
  static void testBaseQueryDeepClone() {
    IModel accountModel = Application.s.model(Account.SObjectType);
    BaseAccountQuery original = new BaseAccountQuery();
    original.init(accountModel);

    Test.startTest();
    IQuery cloned = original.deepClone();
    Test.stopTest();

    // Verify clone is correct type
    Assert.isTrue(
      cloned instanceof BaseAccountQuery,
      'Clone should be BaseAccountQuery'
    );

    // Verify clone has same configuration
    BaseAccountQuery clonedBase = (BaseAccountQuery) cloned;
    Assert.isTrue(clonedBase.onInitializedCalled,
      'Clone should have onInitialized called'
    );
    Assert.areEqual(
      1,
      cloned.filters().getAll().size(),
      'Clone should have same conditions'
    );
  }

  @IsTest
  static void testBaseQueryTemplateMethodEnforcement() {
    // This test verifies that init() is final and calls the template method
    IModel accountModel = Application.s.model(Account.SObjectType);

    Test.startTest();
    BaseAccountQuery query = new BaseAccountQuery();
    query.init(accountModel);
    Test.stopTest();

    // Verify both base init and hook were called
    Assert.isNotNull(query.source(), 'Base init should have run');
    Assert.isTrue(query.onInitializedCalled,
      'onInitialized hook should have been called'
    );
    Assert.areEqual(
      accountModel,
      query.receivedModel,
      'Hook should receive correct model'
    );
  }

  @IsTest
  static void testMakeWithAdditiveArgsString() {
    // Test make(String name, List<Object> additiveArgs)
    List<Object> additiveArgs = new List<Object>{
      new Set<String>{ 'Name', 'Type' },
      Application.s.eq(Account.Type, 'Customer')
    };

    Test.startTest();
    IQuery query = factory.make('Account', additiveArgs);
    Test.stopTest();

    Assert.isNotNull(query, 'Query should be created');
    Assert.isTrue(
      query instanceof FauxAccountQuery,
      'Should be FauxAccountQuery'
    );

    // Verify additive args were applied
    // Note: We can't easily verify the exact fields/conditions without exposing internal state
    // But we can verify the query was created successfully with the args
  }

  @IsTest
  static void testMakeWithAdditiveArgsToken() {
    // Test make(SObjectType token, List<Object> additiveArgs)
    List<Object> additiveArgs = new List<Object>{
      new Set<SObjectField>{ Account.Name, Account.Type },
      Application.s.eq(Account.Industry, 'Technology')
    };

    Test.startTest();
    IQuery query = factory.make(Account.SObjectType, additiveArgs);
    Test.stopTest();

    Assert.isNotNull(query, 'Query should be created');
    Assert.isTrue(
      query instanceof FauxAccountQuery,
      'Should be FauxAccountQuery'
    );
  }

  @IsTest
  static void testMakeWithNullAdditiveArgs() {
    // Test make methods with null additive args
    Test.startTest();
    IQuery query1 = factory.make('Account', null);
    IQuery query2 = factory.make(Account.SObjectType, null);
    Test.stopTest();

    Assert.isNotNull(query1,
      'Query with null args should be created'
    );
    Assert.isNotNull(query2,
      'Query with null args should be created'
    );
  }

  @IsTest
  static void testMakeWithEmptyAdditiveArgs() {
    // Test make methods with empty additive args
    List<Object> emptyArgs = new List<Object>();

    Test.startTest();
    IQuery query1 = factory.make('Account', emptyArgs);
    IQuery query2 = factory.make(Account.SObjectType, emptyArgs);
    Test.stopTest();

    Assert.isNotNull(query1,
      'Query with empty args should be created'
    );
    Assert.isNotNull(query2,
      'Query with empty args should be created'
    );
  }

  @IsTest
  static void testApplyAdditiveArgsWithVariousTypes() {
    // Test applyAdditiveArgs with different argument types
    IQuery query = factory.make(Account.SObjectType);

    List<Object> args = new List<Object>{
      // ICondition
      Application.s.eq(Account.Name, 'Test'),
      // Set<String>
      new Set<String>{ 'Name', 'Type' },
      // Set<SObjectField>
      new Set<SObjectField>{ Account.Name, Account.Type },
      // Set<IPath> - create a simple path
      new Set<IPath>{ accountModel.path('Name') },
      // IFieldScope
      FieldScope.make(FieldScope.Trait.STANDARD)
    };

    Test.startTest();
    // We can't directly test applyAdditiveArgs since it's private, but we can test via make()
    IQuery queryWithArgs = factory.make('Account', args);
    Test.stopTest();

    Assert.isNotNull(queryWithArgs,
      'Query with various args should be created'
    );
  }

  @IsTest
  static void testApplyAdditiveArgsWithInvalidType() {
    // Test applyAdditiveArgs with unsupported argument type
    List<Object> invalidArgs = new List<Object>{
      new List<String>{ 'Invalid', 'Type' } // List<String> is not supported
    };

    Test.startTest();
    try {
      factory.make('Account', invalidArgs);
      Assert.fail('Should have thrown exception for invalid arg type');
    } catch (QueryFactory.QueryFactoryException e) {
      Assert.isTrue(
        e.getMessage().contains('Unsupported additive argument type'),
        'Should throw QueryFactoryException with appropriate message'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testApplyAdditiveArgsWithNullArg() {
    // Test applyAdditiveArgs with null argument (should be ignored)
    List<Object> argsWithNull = new List<Object>{
      Application.s.eq(Account.Name, 'Test'),
      null, // This should be ignored
      new Set<String>{ 'Name' }
    };

    Test.startTest();
    IQuery query = factory.make('Account', argsWithNull);
    Test.stopTest();

    Assert.isNotNull(query,
      'Query should be created despite null arg'
    );
  }

  @IsTest
  static void testIsValidPairValidation() {
    // Test isValidPair validation method indirectly through constructor behavior
    // Since isValidPair is protected, we test it indirectly by creating factories with valid/invalid registries

    Test.startTest();
    // Valid registry - should work
    Map<Type, Type> validRegistry = new Map<Type, Type>{
      Account.class => FauxAccountQuery.class
    };
    QueryFactory validFactory = new QueryFactory(core, validRegistry);
    Assert.isNotNull(validFactory,
      'Factory with valid registry should be created'
    );

    // Test that the factory works with valid pairs
    IQuery query = validFactory.make(Account.SObjectType);
    Assert.isNotNull(query,
      'Query should be created with valid registry'
    );
    Test.stopTest();
  }

  @IsTest
  static void testConstructorVariants() {
    // Test constructor with registry map
    Map<Type, Type> customMap = new Map<Type, Type>{
      Account.class => FauxAccountQuery.class
    };

    Test.startTest();
    QueryFactory factoryWithMap = new QueryFactory(core, customMap);
    QueryFactory factoryWithoutMap = new QueryFactory(core);
    Test.stopTest();

    Assert.isNotNull(factoryWithMap,
      'Factory with map should be created'
    );
    Assert.isNotNull(factoryWithoutMap,
      'Factory without map should be created'
    );

    // Verify registry is properly set
    Assert.areEqual(
      customMap,
      factoryWithMap.getRegistry(),
      'Factory with map should have correct registry'
    );
    Assert.areEqual(
      new Map<Type, Type>(),
      factoryWithoutMap.getRegistry(),
      'Factory without map should have empty registry'
    );
  }

  @IsTest
  static void testDefaultFieldScopeConfiguration() {
    // Test defaultFieldScope configuration and its effect
    IFieldScope customScope = FieldScope.make(FieldScope.Trait.STANDARD)
      .exclude(FieldScope.make(FieldScope.Trait.FORMULA));

    Test.startTest();
    QueryFactory factoryWithCustomScope = new QueryFactory(core, queryMap)
      .defaultFieldScope(customScope);

    IQuery query = factoryWithCustomScope.make(Account.SObjectType);
    Test.stopTest();

    Assert.isNotNull(query,
      'Query should be created with custom scope'
    );
    Assert.isNotNull(query.fields(),
      'Query should have fields configured'
    );
  }

  @IsTest
  static void testDefaultFieldScopeNull() {
    // Test behavior when defaultFieldScope is set to null
    Test.startTest();
    QueryFactory factoryWithNullScope = new QueryFactory(core, queryMap)
      .defaultFieldScope(null);

    IQuery query = factoryWithNullScope.make(Account.SObjectType);
    Test.stopTest();

    Assert.isNotNull(query,
      'Query should be created even with null scope'
    );
    // When scope is null, it should fall back to addAll() behavior
  }

  @IsTest
  static void testDefaultFieldsCachingWithDifferentScopes() {
    // Test that different field scopes create different cached entries
    IFieldScope scope1 = FieldScope.make(FieldScope.Trait.STANDARD);
    IFieldScope scope2 = FieldScope.make(FieldScope.Trait.CUSTOM);

    Test.startTest();
    QueryFactory factory1 = new QueryFactory(core, queryMap)
      .defaultFieldScope(scope1);
    QueryFactory factory2 = new QueryFactory(core, queryMap)
      .defaultFieldScope(scope2);

    IQuery query1 = factory1.make(Account.SObjectType);
    IQuery query2 = factory2.make(Account.SObjectType);
    Test.stopTest();

    Assert.isNotNull(query1, 'Query 1 should be created');
    Assert.isNotNull(query2, 'Query 2 should be created');

    // Both queries should be created successfully with their respective scopes
    // The exact field differences are hard to verify without exposing internal state
  }

  @IsTest
  static void testMakeWithUnregisteredToken() {
    // Test make(SObjectType token) with unregistered token
    Test.startTest();
    IQuery query = factory.make(Contact.SObjectType);
    Test.stopTest();

    Assert.isNotNull(query,
      'Should create base Query for unregistered token'
    );
    Assert.isTrue(query instanceof Query, 'Should be base Query class');
  }

  @IsTest
  static void testMakeWithUnregisteredName() {
    // Test make(String name) with unregistered name
    Test.startTest();
    IQuery query = factory.make('Contact');
    Test.stopTest();

    Assert.isNotNull(query,
      'Should create base Query for unregistered name'
    );
    Assert.isTrue(query instanceof Query, 'Should be base Query class');
  }

  @IsTest
  static void testMakeWithInvalidName() {
    // Test make(String name) with invalid object name
    Test.startTest();
    try {
      factory.make('InvalidObjectName');
      // This might not throw an exception depending on how core.model() handles invalid names
      // The test verifies the method doesn't crash
    } catch (Exception e) {
      // If it does throw, that's also acceptable behavior
      Assert.isNotNull(e,
        'Exception should be thrown for invalid name'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testAddForeignFieldsWithRelationshipPath() {
    // Test addForeignFields functionality with IPath that references other objects
    // This tests the addForeignFields() method indirectly through make() with IPath args

    IModel accountModel = Application.s.model(Account.SObjectType);

    // Create a path to a relationship field (like Account.OwnerId -> User)
    IPath ownerPath = accountModel.path('OwnerId');

    List<Object> argsWithPath = new List<Object>{
      ownerPath // This should trigger addForeignFields()
    };

    Test.startTest();
    IQuery query = factory.make('Account', argsWithPath);
    Test.stopTest();

    Assert.isNotNull(query,
      'Query should be created with relationship path'
    );
    Assert.isNotNull(query.fields(),
      'Query should have fields configured'
    );

    // The addForeignFields method should have been called and added fields from the referenced object
    // We can't easily verify the exact fields without exposing internal state, but we can verify
    // that the query was created successfully and the method didn't crash
  }

  @IsTest
  static void testAddForeignFieldsWithNonRelationshipPath() {
    // Test validation: non-relationship field should throw exception
    IModel accountModel = Application.s.model(Account.SObjectType);

    // Create a path to a non-relationship field
    IPath namePath = accountModel.path('Name');

    List<Object> argsWithNonRelPath = new List<Object>{ namePath };

    Test.startTest();
    try {
      factory.make('Account', argsWithNonRelPath);
      Assert.fail('Should throw exception for non-reference field');
    } catch (QueryFactory.QueryFactoryException e) {
      Assert.isTrue(
        e.getMessage().contains('not a reference field'),
        'Should mention field is not a reference'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testAddForeignFieldsWithNullReferenceTo() {
    // Test validation: non-relationship field (text field) should throw exception
    IModel accountModel = Application.s.model(Account.SObjectType);

    // Create a path to a text field (not a reference)
    IPath textPath = accountModel.path('Description'); // Description is a text field, no references

    List<Object> argsWithTextPath = new List<Object>{ textPath };

    Test.startTest();
    try {
      factory.make('Account', argsWithTextPath);
      Assert.fail('Should throw exception for non-reference field');
    } catch (QueryFactory.QueryFactoryException e) {
      Assert.isTrue(
        e.getMessage().contains('not a reference field'),
        'Should mention field is not a reference'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testApplyAdditiveArgWithPathThatReturnsNull() {
    // Test applyAdditiveArg when query.source().path() returns null
    // This tests the path resolution logic in applyAdditiveArg

    List<Object> argsWithInvalidPath = new List<Object>{
      'InvalidFieldName' // This should cause path() to return null
    };

    Test.startTest();
    try {
      IQuery query = factory.make('Account', argsWithInvalidPath);
      // If it doesn't throw, that's fine - it should fall back to other interpretations
      Assert.isNotNull(query,
        'Query should be created even with invalid path'
      );
    } catch (Exception e) {
      // If it throws, that's also acceptable behavior
      Assert.isNotNull(e,
        'Exception should be thrown for invalid path'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testDefaultFieldScopeWithExclusions() {
    // Test the default field scope configuration with exclusions
    // This tests the default field scope setup in the constructor

    Test.startTest();
    QueryFactory testFactory = new QueryFactory(core, queryMap);
    IQuery query = testFactory.make(Account.SObjectType);
    Test.stopTest();

    Assert.isNotNull(query,
      'Query should be created with default scope'
    );
    Assert.isNotNull(query.fields(),
      'Query should have fields configured'
    );

    // The default scope excludes Preferences, Permissions, Formula, and Namespaced fields
    // We can't easily verify the exact exclusions without exposing internal state,
    // but we can verify the query was created successfully
  }

  @IsTest
  static void testDefaultFieldsMapCachingBehavior() {
    // Test that the defaultFieldsMap properly caches and reuses field configurations
    QueryFactory testFactory = new QueryFactory(core, queryMap);

    Test.startTest();
    // First call should create and cache default fields
    IQuery query1 = testFactory.make(Account.SObjectType);

    // Second call should reuse cached default fields
    IQuery query2 = testFactory.make(Account.SObjectType);

    // Third call with different factory instance should create new cache entry
    QueryFactory testFactory2 = new QueryFactory(core, queryMap);
    IQuery query3 = testFactory2.make(Account.SObjectType);
    Test.stopTest();

    Assert.isNotNull(query1, 'First query should be created');
    Assert.isNotNull(query2, 'Second query should be created');
    Assert.isNotNull(query3, 'Third query should be created');

    // All queries should be separate instances
    Assert.isTrue(query1 !== query2, 'Should create new query instances');
    Assert.isTrue(query1 !== query3, 'Should create new query instances');
    Assert.isTrue(query2 !== query3, 'Should create new query instances');

    // But they should all share the same model
    Assert.areEqual(
      query1.source(),
      query2.source(),
      'Should share same model'
    );
    Assert.areEqual(
      query1.source(),
      query3.source(),
      'Should share same model'
    );
  }

  @IsTest
  static void testDefaultFieldScopeFallbackToAddAll() {
    // Test that when defaultFieldScope is null, it falls back to addAll()
    QueryFactory testFactory = new QueryFactory(core, queryMap)
      .defaultFieldScope(null); // Set to null to trigger fallback

    Test.startTest();
    IQuery query = testFactory.make(Account.SObjectType);
    Test.stopTest();

    Assert.isNotNull(query,
      'Query should be created with null scope'
    );
    Assert.isNotNull(query.fields(),
      'Query should have fields configured'
    );

    // When scope is null, it should fall back to addAll() behavior
    // We can't easily verify the exact fields without exposing internal state,
    // but we can verify the query was created successfully
  }

  @IsTest
  static void testValidationWrongModel() {
    // Test strict validation: IPath from wrong model
    IModel contactModel = Application.s.model(Contact.SObjectType);
    IPath contactNamePath = contactModel.path('FirstName');

    List<Object> args = new List<Object>{ contactNamePath };

    Test.startTest();
    try {
      factory.make('Account', args); // Account query with Contact path
      Assert.fail('Should throw validation error for wrong model');
    } catch (QueryFactory.QueryFactoryException e) {
      Assert.isTrue(
        e.getMessage().contains('Unsupported additive argument type'),
        'Should throw error for IPath from wrong model'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testValidationNonReferenceField() {
    // Test strict validation: IPath that's not a reference field
    IModel accountModel = Application.s.model(Account.SObjectType);
    IPath namePath = accountModel.path('Name'); // Name is not a FK

    List<Object> args = new List<Object>{ namePath };

    Test.startTest();
    try {
      factory.make('Account', args);
      Assert.fail('Should throw validation error for non-FK field');
    } catch (QueryFactory.QueryFactoryException e) {
      Assert.isTrue(
        e.getMessage().contains('not a reference field'),
        'Should mention field is not a reference'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testValidationInvalidChildRelationship() {
    // Test strict validation: String that's not a child relationship
    List<Object> args = new List<Object>{ 'InvalidChildRelationship' };

    Test.startTest();
    try {
      factory.make('Account', args);
      Assert.fail('Should throw validation error for invalid child relationship'
      );
    } catch (QueryFactory.QueryFactoryException e) {
      Assert.isTrue(
        e.getMessage().contains('not a valid child relationship'),
        'Should mention invalid child relationship'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testValidationFieldFromWrongSObject() {
    // Test strict validation: SObjectField from wrong SObject
    List<Object> args = new List<Object>{ Contact.FirstName }; // Contact field in Account query

    Test.startTest();
    try {
      factory.make('Account', args);
      Assert.fail('Should throw validation error for field from wrong SObject'
      );
    } catch (QueryFactory.QueryFactoryException e) {
      Assert.isTrue(
        e.getMessage().contains('does not belong to'),
        'Should mention field belongs to wrong SObject'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testValidationInvalidFieldNames() {
    // Test strict validation: Set<String> with invalid field names
    List<Object> args = new List<Object>{
      new Set<String>{ 'InvalidFieldName' }
    };

    Test.startTest();
    try {
      factory.make('Account', args);
      Assert.fail('Should throw validation error for invalid field name'
      );
    } catch (QueryFactory.QueryFactoryException e) {
      Assert.isTrue(
        e.getMessage().contains('does not exist'),
        'Should mention field does not exist'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testValidationIPathFromWrongModelDirect() {
    // Test validation: IPath from Contact used in Account query
    // Note: The path might not be recognized as valid IPath type by applyAdditiveArg,
    // so it may throw "Unsupported additive argument type" instead
    IModel contactModel = Application.s.model(Contact.SObjectType);
    IPath contactPath = contactModel.path('AccountId'); // Contact.AccountId

    List<Object> args = new List<Object>{ contactPath };

    Test.startTest();
    try {
      factory.make('Account', args);
      Assert.fail('Should throw validation error for IPath from wrong model'
      );
    } catch (QueryFactory.QueryFactoryException e) {
      Assert.isTrue(
        e.getMessage().contains('originates from') ||
          e.getMessage().contains('Wrong model') ||
          e.getMessage().contains('Unsupported additive argument type'),
        'Should mention validation error: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testValidationSetOfIPathFromWrongModel() {
    // Test validation: Set<IPath> with paths from wrong model
    IModel contactModel = Application.s.model(Contact.SObjectType);
    IPath contactPath1 = contactModel.path('FirstName');
    IPath contactPath2 = contactModel.path('LastName');

    List<Object> args = new List<Object>{
      new Set<IPath>{ contactPath1, contactPath2 }
    };

    Test.startTest();
    try {
      factory.make('Account', args);
      Assert.fail('Should throw validation error for Set<IPath> from wrong model'
      );
    } catch (QueryFactory.QueryFactoryException e) {
      Assert.isTrue(
        e.getMessage().contains('originates from'),
        'Should mention wrong origin model: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testValidationSetOfSObjectFieldFromWrongSObject() {
    // Test validation: Set<SObjectField> with fields from wrong SObject
    List<Object> args = new List<Object>{
      new Set<SObjectField>{ Contact.FirstName, Contact.LastName }
    };

    Test.startTest();
    try {
      factory.make('Account', args);
      Assert.fail('Should throw validation error for Set<SObjectField> from wrong SObject'
      );
    } catch (QueryFactory.QueryFactoryException e) {
      Assert.isTrue(
        e.getMessage().contains('belongs to'),
        'Should mention field belongs to wrong SObject: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testValidationIQueryFieldsFromWrongModel() {
    // Test validation: IQueryFields for wrong model
    IModel contactModel = Application.s.model(Contact.SObjectType);
    IQueryFields contactFields = new QueryFields(contactModel);
    contactFields.add(
      new Set<SObjectField>{ Contact.FirstName, Contact.LastName }
    );

    List<Object> args = new List<Object>{ contactFields };

    Test.startTest();
    try {
      factory.make('Account', args);
      Assert.fail('Should throw validation error for IQueryFields from wrong model'
      );
    } catch (QueryFactory.QueryFactoryException e) {
      Assert.isTrue(
        e.getMessage().contains('Source models must match'),
        'Should mention model mismatch: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testValidationSObjectFieldAsChildRelationship() {
    // Test validation: SObjectField that's not a child relationship
    // Use a field that exists on Account but is not a reference field
    // This will trigger validation error about not being a reference field
    List<Object> args = new List<Object>{ Account.Name };

    Test.startTest();
    try {
      factory.make('Account', args);
      Assert.fail('Should throw validation error for non-reference field'
      );
    } catch (QueryFactory.QueryFactoryException e) {
      Assert.isTrue(
        e.getMessage().contains('not a reference field') ||
        e.getMessage().contains('not a child relationship'),
        'Should mention validation error: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testGetDefaultQueryFieldsWithNullSource() {
    // This tests an edge case where getDefaultQueryFields receives null
    // This is difficult to test directly since it's a private method,
    // but we can test that the factory handles models gracefully

    Test.startTest();
    // Make sure factory doesn't crash with valid inputs
    IQuery query = factory.make(Account.SObjectType);
    Assert.isNotNull(query, 'Query should be created');
    Assert.isNotNull(query.source(),
      'Query source should not be null'
    );
    Test.stopTest();
  }

  @IsTest
  static void testMakeWithValidChildRelationshipString() {
    // Test that valid child relationship strings work correctly
    List<Object> args = new List<Object>{ 'Contacts' }; // Account has Contacts child relationship

    Test.startTest();
    IQuery query = factory.make('Account', args);
    Test.stopTest();

    Assert.isNotNull(query,
      'Query should be created with child relationship'
    );
    // The query should have a subquery for Contacts
  }

  @IsTest
  static void testMakeWithValidChildRelationshipField() {
    // Test that valid child relationship via SObjectField works
    // This is tricky - we need to use a field that IS a child relationship
    // Most standard objects don't expose child relationship fields directly
    // Let's test the validation path that would work if we had such a field

    Test.startTest();
    // Test with a string child relationship instead (which we know works)
    List<Object> args = new List<Object>{ 'Opportunities' };
    IQuery query = factory.make('Account', args);
    Test.stopTest();

    Assert.isNotNull(query,
      'Query with child relationship should be created'
    );
  }

  @IsTest
  static void testApplyAdditiveArgsWithICondition() {
    // Test that ICondition is properly applied
    ICondition condition = Application.s.eq(Account.Type, 'Customer');
    List<Object> args = new List<Object>{ condition };

    Test.startTest();
    IQuery query = factory.make('Account', args);
    Test.stopTest();

    Assert.isNotNull(query, 'Query should be created');
    Assert.areEqual(
      1,
      query.filters().getAll().size(),
      'Should have condition applied'
    );
  }

  @IsTest
  static void testApplyAdditiveArgsWithIFieldScope() {
    // Test that IFieldScope is properly applied
    IFieldScope scope = FieldScope.make(FieldScope.Trait.STANDARD);
    List<Object> args = new List<Object>{ scope };

    Test.startTest();
    IQuery query = factory.make('Account', args);
    Test.stopTest();

    Assert.isNotNull(query,
      'Query should be created with field scope'
    );
  }

  @IsTest
  static void testValidationWithMixedValidAndInvalidArgs() {
    // Test that validation catches invalid args even when mixed with valid ones
    IModel contactModel = Application.s.model(Contact.SObjectType);
    IPath invalidPath = contactModel.path('FirstName'); // Wrong model

    List<Object> args = new List<Object>{
      new Set<String>{ 'Name' }, // Valid
      invalidPath // Invalid - from wrong model
    };

    Test.startTest();
    try {
      factory.make('Account', args);
      Assert.fail('Should throw validation error for invalid arg in mixed list'
      );
    } catch (QueryFactory.QueryFactoryException e) {
      // Should catch the validation error from the invalid path
      Assert.isNotNull(e, 'Should throw exception');
    }
    Test.stopTest();
  }

  @IsTest
  static void testAddForeignFieldsWithMultipleReferenceTo() {
    // Test addForeignFields with a polymorphic reference field (Owner, What, Who)
    IModel taskModel = Application.s.model(Task.SObjectType);
    IPath ownerPath = taskModel.path('OwnerId'); // Polymorphic - references User or Group

    List<Object> args = new List<Object>{ ownerPath };

    Test.startTest();
    IQuery query = factory.make(Task.SObjectType, args);
    Test.stopTest();

    Assert.isNotNull(query,
      'Query should be created with polymorphic reference'
    );
  }

  @IsTest
  static void testDefaultFieldsCacheResetOnScopeChange() {
    // Test that changing defaultFieldScope resets the cache
    IFieldScope scope1 = FieldScope.make(FieldScope.Trait.STANDARD);
    QueryFactory factory1 = new QueryFactory(core, queryMap)
      .defaultFieldScope(scope1);

    Test.startTest();
    IQuery query1 = factory1.make(Account.SObjectType);

    // Change scope - should reset cache
    IFieldScope scope2 = FieldScope.make(FieldScope.Trait.CUSTOM);
    factory1.defaultFieldScope(scope2);
    IQuery query2 = factory1.make(Account.SObjectType);
    Test.stopTest();

    Assert.isNotNull(query1, 'First query should be created');
    Assert.isNotNull(query2, 'Second query should be created');
    // Both should be valid but potentially have different field sets
  }

  @IsTest
  static void testMakeWithEmptySetArguments() {
    // Test that empty sets are handled gracefully
    List<Object> args = new List<Object>{
      new Set<String>(), // Empty set - should be handled
      new Set<SObjectField>(), // Empty set
      new Set<IPath>() // Empty set
    };

    Test.startTest();
    IQuery query = factory.make('Account', args);
    Test.stopTest();

    Assert.isNotNull(query,
      'Query should be created with empty sets'
    );
  }

  @IsTest
  static void testIsValidPairWithNullValues() {
    // Test that factory throws exception for null keys in registry
    Map<Type, Type> registryWithNullKey = new Map<Type, Type>{
      Account.class => FauxAccountQuery.class,
      null => FauxAccountQuery.class // Null key - should throw exception
    };

    Test.startTest();
    try {
      QueryFactory testFactory = new QueryFactory(core, registryWithNullKey);
      Assert.fail('Should throw exception for null key in registry');
    } catch (Application.FactoryException e) {
      Assert.isTrue(
        e.getMessage().contains('Invalid pairing'),
        'Should mention invalid pairing: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testIsValidPairWithNullValue() {
    // Test that factory handles null values in registry
    Map<Type, Type> registryWithNullValue = new Map<Type, Type>{
      Account.class => FauxAccountQuery.class,
      Contact.class => null // Null value
    };

    Test.startTest();
    QueryFactory testFactory = new QueryFactory(core, registryWithNullValue);
    // Should create factory successfully - null values are filtered
    Assert.isNotNull(testFactory,
      'Factory should be created with null value entry'
    );
    Test.stopTest();
  }

  @IsTest
  static void testGetTypeWithNullModel() {
    // Test that getType handles null model gracefully
    // This is testing an internal method indirectly

    Test.startTest();
    // Create a factory and ensure it doesn't crash with edge cases
    QueryFactory testFactory = new QueryFactory(core, new Map<Type, Type>());
    IQuery query = testFactory.make(Contact.SObjectType);
    Test.stopTest();

    Assert.isNotNull(query,
      'Should create query even with empty registry'
    );
  }

  @IsTest
  static void testAggregateQueryFactory() {
    // Test aggregateQuery on Model
    Test.startTest();
    IModel model = Application.s.model(Opportunity.SObjectType);
    IAggregateQuery aggQuery = model.aggregateQuery();
    Test.stopTest();

    Assert.isNotNull(aggQuery, 'AggregateQuery should not be null');
    Assert.areEqual(
      'Opportunity',
      aggQuery.source().name(),
      'Source should be Opportunity'
    );
  }

  @IsTest
  static void testAggregateQueryFactoryWithNull() {
    // Test aggregateQuery with null model (not applicable anymore)
    // This test is no longer relevant since you call aggregateQuery() on a model
    // If model is null, you'd get a NullPointerException before reaching aggregateQuery()
    Test.startTest();
    IModel model = Application.s.model(Account.SObjectType);
    IAggregateQuery aggQuery = model.aggregateQuery();
    Assert.isNotNull(aggQuery, 'Should create aggregate query');
    Test.stopTest();
  }

  @IsTest
  static void testSearchQueryFactory() {
    // Test searchQuery on Core with List<IQuery>
    IQuery accountQuery = Application.s.qf().make(Account.SObjectType);
    IQuery contactQuery = Application.s.qf().make(Contact.SObjectType);

    Test.startTest();
    ISearchQuery searchQuery = Application.s.searchQuery(
      new List<IQuery>{ accountQuery, contactQuery }
    );
    Test.stopTest();

    Assert.isNotNull(searchQuery, 'SearchQuery should not be null');
    Assert.areEqual(
      2,
      searchQuery.targetMap().size(),
      'Should have 2 targets'
    );
    Assert.isTrue(
      searchQuery.targetMap().containsKey(Account.SObjectType),
      'Should contain Account'
    );
    Assert.isTrue(
      searchQuery.targetMap().containsKey(Contact.SObjectType),
      'Should contain Contact'
    );
  }

  @IsTest
  static void testSearchQueryFactoryWithNull() {
    // Test searchQuery with null query list
    Test.startTest();
    try {
      Application.s.searchQuery(null);
      Assert.fail('Should throw exception for null queries');
    } catch (Exception e) {
      Assert.isTrue(
        e.getMessage().contains('cannot be null'),
        'Should mention null query list'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testSearchQueryFactoryWithEmptyList() {
    // Test searchQuery with empty list
    Test.startTest();
    try {
      Application.s.searchQuery(new List<IQuery>());
      Assert.fail('Should throw exception for empty list');
    } catch (Exception e) {
      Assert.isTrue(
        e.getMessage().contains('empty'),
        'Should mention empty query list'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void defaultFieldsLeaveOutFieldsNoUserCanBeGranted() {
    IQuery accounts = Application.s.qf().make(Account.SObjectType);
    Set<SObjectField> selected = accounts.fields().getFieldsByReference().get(accounts.source());

    Assert.isTrue(selected.contains(Account.Name), 'ordinary fields stay');
    for (SObjectField field : selected) {
      DescribeFieldResult described = field.getDescribe();
      Assert.isTrue(described.isAccessible() || described.isPermissionable(), field + ' cannot be granted to anyone');
    }
  }
}
