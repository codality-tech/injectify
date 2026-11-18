@IsTest
private class BaseQueryTest {
  // Test implementation of BaseQuery
  private class TestQuery extends BaseQuery {
    public Boolean onInitializedCalled = false;
    public IModel receivedModel;
    public Integer onInitializedCallCount = 0;

    public override void onInitialized(IModel source) {
      onInitializedCalled = true;
      receivedModel = source;
      onInitializedCallCount++;
    }

    public override IQuery deepClone() {
      TestQuery clone = new TestQuery();
      clone.init(this);
      return clone;
    }
  }

  // Test implementation with custom logic in onInitialized
  private class AccountTestQuery extends BaseQuery {
    public Boolean initialized = false;

    public override void onInitialized(IModel source) {
      initialized = true;
      // Add default condition
      this.addCondition(Application.s.eq(Account.Type, 'Customer'));
      // Add default fields
      this.fields().add(new Set<SObjectField>{ Account.Name, Account.Type });
    }
  }

  @IsTest
  static void testNoArgConstructor() {
    Test.startTest();
    TestQuery query = new TestQuery();
    Test.stopTest();

    System.assertEquals(
      null,
      query.source(),
      'Query should not be initialized without model'
    );
    System.assertEquals(
      false,
      query.onInitializedCalled,
      'onInitialized should not be called without init'
    );
  }

  @IsTest
  static void testConstructorWithModel() {
    IModel accountModel = Application.s.model(Account.SObjectType);

    Test.startTest();
    BaseQuery query = new TestQuery();
    query.init(accountModel);
    Test.stopTest();

    TestQuery testQuery = (TestQuery) query;
    System.assertNotEquals(
      null,
      testQuery.source(),
      'Query should be initialized with model'
    );
    System.assertEquals(
      accountModel,
      testQuery.source(),
      'Query should have correct model'
    );
    System.assertEquals(
      true,
      testQuery.onInitializedCalled,
      'onInitialized should be called'
    );
    System.assertEquals(
      accountModel,
      testQuery.receivedModel,
      'onInitialized should receive correct model'
    );
  }

  @IsTest
  static void testCopyConstructor() {
    IModel accountModel = Application.s.model(Account.SObjectType);
    TestQuery original = new TestQuery();
    original.init(accountModel);
    original.addCondition(Application.s.eq(Account.Type, 'Customer'));

    Test.startTest();
    TestQuery copy = new TestQuery();
    copy.init(original);
    Test.stopTest();

    System.assertNotEquals(null, copy.source(), 'Copy should be initialized');
    System.assertEquals(
      accountModel,
      copy.source(),
      'Copy should have same model'
    );
    System.assertEquals(
      true,
      copy.onInitializedCalled,
      'Copy should have onInitialized called'
    );
    System.assertEquals(
      1,
      copy.filters().getAll().size(),
      'Copy should have same conditions'
    );
  }

  @IsTest
  static void testInitWithModel() {
    IModel accountModel = Application.s.model(Account.SObjectType);
    TestQuery query = new TestQuery();

    Test.startTest();
    query.init(accountModel);
    Test.stopTest();

    System.assertNotEquals(null, query.source(), 'Query should be initialized');
    System.assertEquals(
      true,
      query.onInitializedCalled,
      'onInitialized should be called'
    );
    System.assertEquals(
      accountModel,
      query.receivedModel,
      'onInitialized should receive model'
    );
  }

  @IsTest
  static void testInitWithQuery() {
    IModel accountModel = Application.s.model(Account.SObjectType);
    Query original = new Query(accountModel);
    original.addCondition(Application.s.eq(Account.Type, 'Customer'));
    TestQuery query = new TestQuery();

    Test.startTest();
    query.init(original);
    Test.stopTest();

    System.assertNotEquals(null, query.source(), 'Query should be initialized');
    System.assertEquals(
      true,
      query.onInitializedCalled,
      'onInitialized should be called'
    );
    System.assertEquals(
      1,
      query.filters().getAll().size(),
      'Should copy conditions'
    );
  }

  @IsTest
  static void testOnInitializedOnlyCalledOnce() {
    IModel accountModel = Application.s.model(Account.SObjectType);
    IModel contactModel = Application.s.model(Contact.SObjectType);

    Test.startTest();
    TestQuery query = new TestQuery();
    query.init(accountModel);
    Test.stopTest();

    System.assertEquals(
      1,
      query.onInitializedCallCount,
      'onInitialized should be called exactly once'
    );

    // Same model: idempotent, should not throw and should not call onInitialized again
    query.init(accountModel);
    System.assertEquals(
      1,
      query.onInitializedCallCount,
      'onInitialized should still be called exactly once after idempotent init'
    );

    // Different model: should throw
    try {
      query.init(contactModel);
      System.assert(false, 'Should throw on init with different model');
    } catch (Exception e) {
      System.assert(
        e.getMessage()
          .contains('already been initialized with a different model'),
        'Should throw RuntimeException for double init'
      );
    }
  }

  @IsTest
  static void testCustomInitializationLogic() {
    IModel accountModel = Application.s.model(Account.SObjectType);

    Test.startTest();
    AccountTestQuery query = new AccountTestQuery();
    query.init(accountModel);
    Test.stopTest();

    System.assertEquals(
      true,
      query.initialized,
      'Custom initialization should run'
    );
    System.assertEquals(
      1,
      query.filters().getAll().size(),
      'Should have default condition'
    );
    // Note: Can't easily test field count without running query
  }

  @IsTest
  static void testDeepClone() {
    IModel accountModel = Application.s.model(Account.SObjectType);
    TestQuery original = new TestQuery();
    original.init(accountModel);
    original.addCondition(Application.s.eq(Account.Type, 'Customer'));
    original.setLimit(10);

    Test.startTest();
    IQuery cloned = original.deepClone();
    Test.stopTest();

    System.assert(cloned instanceof TestQuery, 'Clone should be same type');
    TestQuery clonedTest = (TestQuery) cloned;
    System.assertEquals(
      true,
      clonedTest.onInitializedCalled,
      'Clone should have onInitialized called'
    );
    System.assertEquals(
      accountModel,
      cloned.source(),
      'Clone should have same model'
    );
  }

  @IsTest
  static void testTemplateMethodPattern() {
    // This test verifies the Template Method pattern is enforced
    IModel accountModel = Application.s.model(Account.SObjectType);
    TestQuery query = new TestQuery();

    Test.startTest();
    query.init(accountModel);
    Test.stopTest();

    // Verify both steps of the template ran:
    // 1. Base initialization (source is set)
    System.assertNotEquals(
      null,
      query.source(),
      'Base init should complete first'
    );

    // 2. Hook was called (onInitialized ran)
    System.assertEquals(
      true,
      query.onInitializedCalled,
      'Hook should run after base init'
    );

    // Verify the sequence is correct
    System.assertEquals(
      accountModel,
      query.receivedModel,
      'Hook should receive the initialized model'
    );
  }

  @IsTest
  static void testInitCannotBeOverridden() {
    // This test documents that init() is final and cannot be overridden
    // If someone tries to override init(), it should fail at compile time
    // This test verifies the behavior is as expected at runtime

    IModel accountModel = Application.s.model(Account.SObjectType);

    // Attempt to use a BaseQuery subclass
    TestQuery query = new TestQuery();
    query.init(accountModel);

    // The init() method on BaseQuery is final, so it always:
    // 1. Calls super.init() first
    // 2. Then calls onInitialized()
    // Verify this sequence happened
    System.assertEquals(
      true,
      query.onInitializedCalled,
      'onInitialized must be called by final init()'
    );
    System.assertNotEquals(
      null,
      query.source(),
      'Base init must complete before hook'
    );
  }

  @IsTest
  static void testNullModelHandling() {
    TestQuery query = new TestQuery();

    Test.startTest();
    try {
      query.init((IModel) null);
      System.assert(false, 'Should throw on null model');
    } catch (Exception e) {
      System.assert(
        e.getMessage().contains('must not be null'),
        'Should throw for null model'
      );
    }
    Test.stopTest();

    System.assertEquals(
      false,
      query.onInitializedCalled,
      'onInitialized should not be called if base init fails'
    );
  }

  @IsTest
  static void testInitWithNullQuery() {
    TestQuery query = new TestQuery();

    Test.startTest();
    try {
      query.init((Query) null);
      Assert.fail('Should throw on null query');
    } catch (IllegalArgumentException e) {
      Assert.areEqual('Cannot copy a null query', e.getMessage());
    }
    Test.stopTest();
  }

  // Test implementation with model constructor
  private class QueryWithModelConstructor extends BaseQuery {
    public QueryWithModelConstructor(IModel model) {
      super(model);
    }
  }

  // Test implementation with copy constructor
  private class QueryWithCopyConstructor extends BaseQuery {
    public QueryWithCopyConstructor(BaseQuery other) {
      super(other);
    }
  }

  @IsTest
  static void testProtectedConstructorWithModel() {
    IModel accountModel = Application.s.model(Account.SObjectType);

    Test.startTest();
    QueryWithModelConstructor query = new QueryWithModelConstructor(
      accountModel
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      query.source(),
      'Query should be initialized via constructor'
    );
    System.assertEquals(
      accountModel,
      query.source(),
      'Query should have correct model'
    );
  }

  @IsTest
  static void testProtectedCopyConstructor() {
    IModel accountModel = Application.s.model(Account.SObjectType);
    TestQuery original = new TestQuery();
    original.init(accountModel);
    original.addCondition(Application.s.eq(Account.Type, 'Customer'));
    original.setLimit(100);

    Test.startTest();
    QueryWithCopyConstructor copy = new QueryWithCopyConstructor(original);
    Test.stopTest();

    System.assertNotEquals(null, copy.source(), 'Copy should be initialized');
    System.assertEquals(
      accountModel,
      copy.source(),
      'Copy should have same model'
    );
    System.assertEquals(
      1,
      copy.filters().getAll().size(),
      'Copy should have same conditions'
    );
  }

  @IsTest
  static void testBaseMethodReturnsIQuery() {
    IModel accountModel = Application.s.model(Account.SObjectType);
    TestQuery query = new TestQuery();
    query.init(accountModel);

    Test.startTest();
    IQuery baseQuery = query.base();
    Test.stopTest();

    System.assertNotEquals(null, baseQuery, 'base() should return IQuery');
    System.assertEquals(
      query.source(),
      baseQuery.source(),
      'Should be same query instance'
    );
    System.assert(
      baseQuery instanceof TestQuery,
      'Should still be TestQuery type'
    );
  }

  @IsTest
  static void testBaseMethodForCrossNamespaceAccess() {
    // Verify base() can be used to access Query methods in cross-namespace scenarios
    IModel accountModel = Application.s.model(Account.SObjectType);
    AccountTestQuery query = new AccountTestQuery();
    query.init(accountModel);

    Test.startTest();
    // Access via base() as if from another namespace
    IQuery baseQuery = query.base();
    baseQuery.setLimit(50);
    List<SObject> results = baseQuery.run();
    Test.stopTest();

    // Verify the query worked through the interface
    // The limit was set successfully (can't easily verify without execution)
    System.assertNotEquals(null, baseQuery, 'Query should be accessible');
  }

  // Test class that doesn't override deepClone - will use BaseQuery's default implementation
  private class SimpleTestQuery extends BaseQuery {
    public override void onInitialized(IModel source) {
      // Minimal implementation
    }
  }

  @IsTest
  static void testDefaultDeepCloneImplementation() {
    // Test the default deepClone() implementation in BaseQuery
    IModel accountModel = Application.s.model(Account.SObjectType);
    SimpleTestQuery original = new SimpleTestQuery();
    original.init(accountModel);
    original.addCondition(Application.s.eq(Account.Type, 'Customer'));

    Test.startTest();
    IQuery cloned = original.deepClone();
    Test.stopTest();

    // Verify clone was created
    System.assertNotEquals(null, cloned, 'Clone should not be null');
    System.assertEquals(
      accountModel.token(),
      cloned.source().token(),
      'Clone should have same source'
    );
  }
}
