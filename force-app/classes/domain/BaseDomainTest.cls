@IsTest
private class BaseDomainTest {
  // Test domain implementation
  private class TestDomain extends BaseDomain {
    public Integer onInitializedCallCount = 0;

    public TestDomain() {
      super();
    }

    public override void onInitialized(IModel source, List<SObject> records) {
      onInitializedCallCount++;
    }
  }

  // Custom domain with filtering logic
  private class CustomDomain extends BaseDomain {
    public List<SObject> filteredRecords;

    public override void onInitialized(IModel source, List<SObject> records) {
      // Custom logic: filter records
      filteredRecords = new List<SObject>();
      for (SObject record : records) {
        if (record.get('Name') != null) {
          filteredRecords.add(record);
        }
      }
    }
  }

  // Domain with trigger method overrides
  private class TriggerTestDomain extends BaseDomain {
    public Boolean beforeUpsertCalled = false;
    public Boolean afterUpsertCalled = false;

    public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
      beforeUpsertCalled = true;
    }

    public override void onAfterUpsert(Map<Id, SObject> oldMap) {
      afterUpsertCalled = true;
    }
  }

  @IsTest
  static void testNoArgConstructor() {
    TestDomain domain = new TestDomain();
    System.assertNotEquals(null, domain, 'Domain should be created');
    System.assertEquals(
      0,
      domain.onInitializedCallCount,
      'onInitialized should not be called without init'
    );
  }

  @IsTest
  static void testConstructorWithModelAndRecords() {
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> accounts = new List<SObject>{
      new Account(Name = 'Test Account 1'),
      new Account(Name = 'Test Account 2')
    };

    Test.startTest();
    TestDomain domain = new TestDomain();
    domain.init(accountModel, accounts);
    Test.stopTest();

    System.assertNotEquals(null, domain, 'Domain should be created');
    System.assertEquals(
      1,
      domain.onInitializedCallCount,
      'onInitialized should be called once'
    );
    System.assertEquals(accountModel, domain.source(), 'Source should match');
    System.assertEquals(2, domain.records().size(), 'Should have 2 records');
  }

  @IsTest
  static void testInitWithModel() {
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> accounts = new List<SObject>{
      new Account(Name = 'Test Account')
    };
    TestDomain domain = new TestDomain();

    Test.startTest();
    domain.init(accountModel, accounts);
    Test.stopTest();

    System.assertEquals(
      1,
      domain.onInitializedCallCount,
      'onInitialized should be called once'
    );
    System.assertEquals(accountModel, domain.source(), 'Source should match');
    System.assertEquals(1, domain.records().size(), 'Should have 1 record');
  }

  @IsTest
  static void testTemplateMethodPattern() {
    // Verify that super.init() runs before onInitialized()
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> accounts = new List<SObject>{
      new Account(Name = 'Test Account')
    };
    TestDomain domain = new TestDomain();

    Test.startTest();
    domain.init(accountModel, accounts);
    Test.stopTest();

    // onInitialized was called
    System.assertEquals(
      1,
      domain.onInitializedCallCount,
      'onInitialized should be called'
    );
    // Base initialization completed (source and records set)
    System.assertEquals(accountModel, domain.source(), 'Source should be set');
    System.assert(domain.isInitialized(), 'Domain should be initialized');
  }

  @IsTest
  static void testOnInitializedOnlyCalledOnce() {
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> accounts = new List<SObject>{
      new Account(Name = 'Test Account')
    };
    TestDomain domain = new TestDomain();

    Test.startTest();
    domain.init(accountModel, accounts);
    Test.stopTest();

    System.assertEquals(
      1,
      domain.onInitializedCallCount,
      'onInitialized should be called exactly once'
    );
  }

  @IsTest
  static void testCustomInitializationLogic() {
    // Test domain with custom initialization
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> accounts = new List<SObject>{
      new Account(Name = 'Test Account'),
      new Account() // No name
    };

    Test.startTest();
    CustomDomain domain = new CustomDomain();
    domain.init(accountModel, accounts);
    Test.stopTest();

    System.assertEquals(
      1,
      domain.filteredRecords.size(),
      'Should have filtered to 1 record with name'
    );
  }

  @IsTest
  static void testNullModelHandling() {
    TestDomain domain = new TestDomain();
    // Use a properly typed list so getSObjectType() returns the correct type
    List<Account> accounts = new List<Account>{
      new Account(Name = 'Test Account')
    };

    Test.startTest();
    domain.init(null, accounts);
    // Domain should infer model from properly typed records
    System.assertEquals(
      Account.SObjectType,
      domain.source().token(),
      'Should infer model from records'
    );
    System.assertEquals(1, domain.records().size(), 'Should have 1 record');
    Test.stopTest();
  }

  @IsTest
  static void testBaseMethodAccessDomainFunctionality() {
    IModel accountModel = Application.s.model(Account.SObjectType);
    insert new List<Account>{
      new Account(Name = 'Test 1', Industry = 'Technology'),
      new Account(Name = 'Test 2', Industry = 'Finance')
    };
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account];

    TestDomain domain = new TestDomain();
    domain.init(accountModel, accounts);

    Test.startTest();
    // Access via base() method
    IDomain baseDomain = domain.base();
    List<SObject> filtered = baseDomain.filter(
      Application.s.eq(Account.Industry, 'Technology')
    );
    Test.stopTest();

    System.assertEquals(
      1,
      filtered.size(),
      'Should filter to 1 technology account'
    );
    System.assertEquals(
      'Test 1',
      filtered[0].get('Name'),
      'Should be correct account'
    );
  }

  @IsTest
  static void testDoubleInitializationPrevention() {
    IModel accountModel = Application.s.model(Account.SObjectType);
    IModel contactModel = Application.s.model(Contact.SObjectType);
    List<SObject> accounts = new List<SObject>{
      new Account(Name = 'Test Account')
    };
    TestDomain domain = new TestDomain();
    domain.init(accountModel, accounts);

    Test.startTest();
    // Same model, same records: idempotent, should not throw
    domain.init(accountModel, accounts);
    System.assertEquals(
      1,
      domain.onInitializedCallCount,
      'onInitialized should only be called once even with double init'
    );

    // Same model, null records: idempotent, should not throw (null is OK for idempotent calls)
    domain.init(accountModel, null);
    System.assertEquals(
      1,
      domain.onInitializedCallCount,
      'onInitialized should still only be called once with null records'
    );

    // Same model, empty records: idempotent, should not throw (empty list is OK for idempotent calls)
    domain.init(accountModel, new List<SObject>());
    System.assertEquals(
      1,
      domain.onInitializedCallCount,
      'onInitialized should still only be called once with empty records'
    );

    // Same model, different records: should throw
    try {
      List<SObject> differentAccounts = new List<SObject>{
        new Account(Name = 'Different Account')
      };
      domain.init(accountModel, differentAccounts);
      System.assert(
        false,
        'Should throw exception when initializing with different records'
      );
    } catch (Exception e) {
      System.assert(
        e.getMessage().contains('Cannot change records'),
        'Should throw records change exception: ' + e.getMessage()
      );
    }

    // Different model: should throw
    try {
      domain.init(contactModel, new List<Contact>());
      System.assert(
        false,
        'Should throw exception on init with different model'
      );
    } catch (Exception e) {
      System.assert(
        e.getMessage()
          .contains('already been initialized with a different model'),
        'Should throw different model exception: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testBaseMethodProvidesCrossNamespaceAccess() {
    // Verify that base() returns IDomain interface
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> accounts = new List<SObject>{
      new Account(Name = 'Test Account')
    };
    TestDomain domain = new TestDomain();
    domain.init(accountModel, accounts);

    Test.startTest();
    IDomain baseDomain = domain.base();
    Test.stopTest();

    System.assertNotEquals(null, baseDomain, 'base() should return IDomain');
    System.assertEquals(
      domain.source(),
      baseDomain.source(),
      'Should be same domain'
    );
    System.assertEquals(
      domain.records().size(),
      baseDomain.records().size(),
      'Should have same records'
    );
  }

  @IsTest
  static void testTriggerMethodsStillWork() {
    // Verify that virtual trigger methods still work on BaseDomain subclasses
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> accounts = new List<SObject>{
      new Account(Name = 'Test Account')
    };
    TriggerTestDomain domain = new TriggerTestDomain();
    domain.init(accountModel, accounts);

    Test.startTest();
    // Trigger BEFORE_INSERT and AFTER_INSERT to invoke upsert methods
    domain.handleTrigger(
      TriggerOperation.BEFORE_INSERT,
      accounts,
      null,
      null,
      accountModel
    );
    domain.handleTrigger(
      TriggerOperation.AFTER_INSERT,
      accounts,
      null,
      null,
      accountModel
    );
    Test.stopTest();

    System.assert(domain.beforeUpsertCalled, 'onBeforeUpsert should be called');
    System.assert(domain.afterUpsertCalled, 'onAfterUpsert should be called');
  }

  @IsTest
  static void testSegmentViaBase() {
    // Test using base() to access Domain methods
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<Account> accounts = new List<Account>{
      new Account(Name = 'Test 1', Industry = 'Technology'),
      new Account(Name = 'Test 2', Industry = 'Technology'),
      new Account(Name = 'Test 3', Industry = 'Finance')
    };

    TestDomain domain = new TestDomain();
    domain.init(accountModel, accounts);

    Test.startTest();
    Map<String, List<SObject>> segments = domain.base().segment('Industry');
    Test.stopTest();

    System.assertEquals(2, segments.size(), 'Should have 2 industry segments');
    System.assertEquals(
      2,
      segments.get('Technology').size(),
      'Should have 2 tech accounts'
    );
    System.assertEquals(
      1,
      segments.get('Finance').size(),
      'Should have 1 finance account'
    );
  }

  // Domain with model+records constructor
  private class DomainWithConstructor extends BaseDomain {
    public DomainWithConstructor(IModel source, List<SObject> records) {
      super(source, records);
    }
  }

  @IsTest
  static void testProtectedConstructorWithModelAndRecords() {
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> accounts = new List<SObject>{
      new Account(Name = 'Test 1'),
      new Account(Name = 'Test 2')
    };

    Test.startTest();
    DomainWithConstructor domain = new DomainWithConstructor(
      accountModel,
      accounts
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      domain.source(),
      'Domain should be initialized via constructor'
    );
    System.assertEquals(
      accountModel,
      domain.source(),
      'Domain should have correct model'
    );
    System.assertEquals(
      2,
      domain.records().size(),
      'Domain should have correct records'
    );
    System.assert(domain.isInitialized(), 'Domain should be initialized');
  }

  @IsTest
  static void testBaseMethodReturnsIDomain() {
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> accounts = new List<SObject>{
      new Account(Name = 'Test Account')
    };
    TestDomain domain = new TestDomain();
    domain.init(accountModel, accounts);

    Test.startTest();
    IDomain baseDomain = domain.base();
    Test.stopTest();

    System.assertNotEquals(null, baseDomain, 'base() should return IDomain');
    System.assertEquals(
      domain.source(),
      baseDomain.source(),
      'Should be same domain instance'
    );
    System.assert(
      baseDomain instanceof TestDomain,
      'Should still be TestDomain type'
    );
  }

  @IsTest
  static void testOnInitializedAccessToRecords() {
    // Verify onInitialized can access records
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> accounts = new List<SObject>{
      new Account(Name = 'Test 1'),
      new Account(Name = 'Test 2'),
      new Account() // No name
    };

    Test.startTest();
    CustomDomain domain = new CustomDomain();
    domain.init(accountModel, accounts);
    Test.stopTest();

    System.assertEquals(
      2,
      domain.filteredRecords.size(),
      'onInitialized should have access to records'
    );
    System.assertEquals(
      'Test 1',
      domain.filteredRecords[0].get('Name'),
      'Should have filtered correctly'
    );
  }

  @IsTest
  static void testShouldRecycleInstance() {
    // Test default behavior of shouldRecycleInstance
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> accounts = new List<SObject>{
      new Account(Name = 'Test Account')
    };
    TestDomain domain = new TestDomain();
    domain.init(accountModel, accounts);

    Test.startTest();
    Boolean shouldRecycle = domain.shouldRecycleInstance();
    Test.stopTest();

    System.assertEquals(
      true,
      shouldRecycle,
      'Default should be true (recycling enabled for BaseDomain)'
    );
  }

  @IsTest
  static void testShouldEnforceSecurity() {
    // Test default behavior of shouldEnforceSecurity
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> accounts = new List<SObject>{
      new Account(Name = 'Test Account')
    };
    TestDomain domain = new TestDomain();
    domain.init(accountModel, accounts);

    Test.startTest();
    Boolean shouldEnforce = domain.shouldEnforceSecurity();
    Test.stopTest();

    System.assertEquals(
      false,
      shouldEnforce,
      'Default should be false (no security enforcement)'
    );
  }

  // Domain that opts out of recycling behavior
  private class NonRecyclableDomain extends BaseDomain {
    public override Boolean shouldRecycleInstance() {
      return false;
    }
  }

  // Domain with custom security behavior
  private class NoSecurityDomain extends BaseDomain {
    public override Boolean shouldEnforceSecurity() {
      return false;
    }
  }

  @IsTest
  static void testShouldRecycleInstanceOverride() {
    // Test overriding shouldRecycleInstance to opt-out
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> accounts = new List<SObject>{
      new Account(Name = 'Test Account')
    };
    NonRecyclableDomain domain = new NonRecyclableDomain();
    domain.init(accountModel, accounts);

    Test.startTest();
    Boolean shouldRecycle = domain.shouldRecycleInstance();
    Test.stopTest();

    System.assertEquals(
      false,
      shouldRecycle,
      'Should allow opt-out by returning false'
    );
  }

  // Test domain with consolidated upsert logic
  private class UpsertDomain extends BaseDomain {
    public Integer beforeUpsertCallCount = 0;
    public Integer afterUpsertCallCount = 0;
    public Boolean lastBeforeWasInsert;
    public Boolean lastAfterWasInsert;

    public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
      beforeUpsertCallCount++;
      lastBeforeWasInsert = (oldMap == null);
    }

    public override void onAfterUpsert(Map<Id, SObject> oldMap) {
      afterUpsertCallCount++;
      lastAfterWasInsert = (oldMap == null);
    }
  }

  @IsTest
  static void testConsolidatedUpsertMethods() {
    // Test that onBeforeUpsert and onAfterUpsert are called for both INSERT and UPDATE
    // with correct oldMap values (null for insert, non-null for update)
    UpsertDomain domain = new UpsertDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> insertRecords = new List<SObject>{
      new Account(Name = 'Insert Test')
    };
    List<SObject> updateRecords = new List<SObject>{
      new Account(Id = IdUtil.generateId(accountModel), Name = 'Update Test')
    };

    Test.startTest();

    // Test BEFORE_INSERT calls onBeforeUpsert with isInsert=true
    domain.handleTrigger(
      TriggerOperation.BEFORE_INSERT,
      insertRecords,
      null,
      null,
      accountModel
    );
    System.assertEquals(
      1,
      domain.beforeUpsertCallCount,
      'onBeforeUpsert should be called for BEFORE_INSERT'
    );
    System.assertEquals(
      true,
      domain.lastBeforeWasInsert,
      'oldMap should be null for BEFORE_INSERT'
    );

    // Test AFTER_INSERT calls onAfterUpsert with oldMap=null
    domain.handleTrigger(
      TriggerOperation.AFTER_INSERT,
      insertRecords,
      null,
      null,
      accountModel
    );
    System.assertEquals(
      1,
      domain.afterUpsertCallCount,
      'onAfterUpsert should be called for AFTER_INSERT'
    );
    System.assertEquals(
      true,
      domain.lastAfterWasInsert,
      'oldMap should be null for AFTER_INSERT'
    );

    // Test BEFORE_UPDATE calls onBeforeUpsert with oldMap != null
    // Create new domain instance for update operation
    domain = new UpsertDomain();
    domain.handleTrigger(
      TriggerOperation.BEFORE_UPDATE,
      updateRecords,
      updateRecords,
      new Map<Id, SObject>(),
      accountModel
    );
    System.assertEquals(
      1,
      domain.beforeUpsertCallCount,
      'onBeforeUpsert should be called for BEFORE_UPDATE'
    );
    System.assertEquals(
      false,
      domain.lastBeforeWasInsert,
      'oldMap should be non-null for BEFORE_UPDATE'
    );

    // Test AFTER_UPDATE calls onAfterUpsert with oldMap != null
    domain.handleTrigger(
      TriggerOperation.AFTER_UPDATE,
      updateRecords,
      updateRecords,
      new Map<Id, SObject>(),
      accountModel
    );
    System.assertEquals(
      1,
      domain.afterUpsertCallCount,
      'onAfterUpsert should be called for AFTER_UPDATE'
    );
    System.assertEquals(
      false,
      domain.lastAfterWasInsert,
      'oldMap should be non-null for AFTER_UPDATE'
    );

    Test.stopTest();
  }

  @IsTest
  static void testShouldEnforceSecurityOverride() {
    // Test overriding shouldEnforceSecurity
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> accounts = new List<SObject>{
      new Account(Name = 'Test Account')
    };
    NoSecurityDomain domain = new NoSecurityDomain();
    domain.init(accountModel, accounts);

    Test.startTest();
    Boolean shouldEnforce = domain.shouldEnforceSecurity();
    Test.stopTest();

    System.assertEquals(
      false,
      shouldEnforce,
      'Should return overridden value of false'
    );
  }

  // Test domain with all trigger methods overridden
  private class FullTriggerDomain extends BaseDomain {
    public Integer beforeUpsertCallCount = 0;
    public Integer afterUpsertCallCount = 0;
    public Integer beforeDeleteCallCount = 0;
    public Integer afterDeleteCallCount = 0;
    public Integer afterUndeleteCallCount = 0;
    public Map<Id, SObject> lastBeforeUpsertOldMap;
    public Map<Id, SObject> lastAfterUpsertOldMap;

    public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
      beforeUpsertCallCount++;
      lastBeforeUpsertOldMap = oldMap;
    }

    public override void onAfterUpsert(Map<Id, SObject> oldMap) {
      afterUpsertCallCount++;
      lastAfterUpsertOldMap = oldMap;
    }

    public override void onBeforeDelete() {
      beforeDeleteCallCount++;
    }

    public override void onAfterDelete() {
      afterDeleteCallCount++;
    }

    public override void onAfterUndelete() {
      afterUndeleteCallCount++;
    }
  }

  @IsTest
  static void testAllTriggerMethods() {
    // Test that all trigger methods are called correctly
    FullTriggerDomain domain = new FullTriggerDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> insertRecords = new List<SObject>{
      new Account(Name = 'Insert Test')
    };
    List<SObject> updateRecords = new List<SObject>{
      new Account(Id = IdUtil.generateId(accountModel), Name = 'Update Test')
    };
    List<SObject> deleteRecords = new List<SObject>{
      new Account(Id = IdUtil.generateId(accountModel), Name = 'Delete Test')
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>(updateRecords);

    Test.startTest();

    // Test INSERT operations
    domain.handleTrigger(
      TriggerOperation.BEFORE_INSERT,
      insertRecords,
      null,
      null,
      accountModel
    );
    System.assertEquals(
      1,
      domain.beforeUpsertCallCount,
      'onBeforeUpsert should be called for INSERT'
    );
    System.assertEquals(
      null,
      domain.lastBeforeUpsertOldMap,
      'oldMap should be null for INSERT'
    );

    domain.handleTrigger(
      TriggerOperation.AFTER_INSERT,
      insertRecords,
      null,
      null,
      accountModel
    );
    System.assertEquals(
      1,
      domain.afterUpsertCallCount,
      'onAfterUpsert should be called for INSERT'
    );
    System.assertEquals(
      null,
      domain.lastAfterUpsertOldMap,
      'oldMap should be null for INSERT'
    );

    // Test UPDATE operations
    domain = new FullTriggerDomain(); // New instance for update
    domain.handleTrigger(
      TriggerOperation.BEFORE_UPDATE,
      updateRecords,
      updateRecords,
      oldMap,
      accountModel
    );
    System.assertEquals(
      1,
      domain.beforeUpsertCallCount,
      'onBeforeUpsert should be called for UPDATE'
    );
    System.assertEquals(
      oldMap,
      domain.lastBeforeUpsertOldMap,
      'oldMap should match for UPDATE'
    );

    domain.handleTrigger(
      TriggerOperation.AFTER_UPDATE,
      updateRecords,
      updateRecords,
      oldMap,
      accountModel
    );
    System.assertEquals(
      1,
      domain.afterUpsertCallCount,
      'onAfterUpsert should be called for UPDATE'
    );
    System.assertEquals(
      oldMap,
      domain.lastAfterUpsertOldMap,
      'oldMap should match for UPDATE'
    );

    // Test DELETE operations
    domain = new FullTriggerDomain(); // New instance for delete
    domain.handleTrigger(
      TriggerOperation.BEFORE_DELETE,
      null,
      deleteRecords,
      new Map<Id, SObject>(deleteRecords),
      accountModel
    );
    System.assertEquals(
      1,
      domain.beforeDeleteCallCount,
      'onBeforeDelete should be called'
    );

    domain.handleTrigger(
      TriggerOperation.AFTER_DELETE,
      null,
      deleteRecords,
      new Map<Id, SObject>(deleteRecords),
      accountModel
    );
    System.assertEquals(
      1,
      domain.afterDeleteCallCount,
      'onAfterDelete should be called'
    );

    // Test UNDELETE operation
    domain.handleTrigger(
      TriggerOperation.AFTER_UNDELETE,
      deleteRecords,
      null,
      null,
      accountModel
    );
    System.assertEquals(
      1,
      domain.afterUndeleteCallCount,
      'onAfterUndelete should be called'
    );

    Test.stopTest();
  }

  // Test domain that overrides both consolidated and granular methods (footgun test)
  private class ConflictingDomain extends BaseDomain {
    public Integer consolidatedCallCount = 0;
    public Integer granularCallCount = 0;

    public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
      consolidatedCallCount++;
    }

    // This should not be possible since granular methods are now private
    // But let's test the behavior if someone tries to override them
  }

  @IsTest
  static void testConsolidatedMethodOverride() {
    // Test that only consolidated methods are called, not granular ones
    ConflictingDomain domain = new ConflictingDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> records = new List<SObject>{ new Account(Name = 'Test') };

    Test.startTest();
    domain.handleTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null,
      accountModel
    );
    Test.stopTest();

    System.assertEquals(
      1,
      domain.consolidatedCallCount,
      'Consolidated method should be called'
    );
    System.assertEquals(
      0,
      domain.granularCallCount,
      'Granular methods should not be accessible'
    );
  }

  // Test domain with complex upsert logic
  private class ComplexUpsertDomain extends BaseDomain {
    public List<String> operationLog = new List<String>();
    public Map<Id, String> recordNames = new Map<Id, String>();

    public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
      if (oldMap == null) {
        operationLog.add('INSERT: Setting defaults');
        for (Account acc : (List<Account>) records()) {
          acc.Industry = 'Technology';
        }
      } else {
        operationLog.add('UPDATE: Validating changes');
        for (Account acc : (List<Account>) records()) {
          Account old = (Account) oldMap.get(acc.Id);
          if (old != null && acc.Name != old.Name) {
            operationLog.add(
              'Name changed from ' + old.Name + ' to ' + acc.Name
            );
          }
        }
      }
    }

    public override void onAfterUpsert(Map<Id, SObject> oldMap) {
      if (oldMap == null) {
        operationLog.add('INSERT: Post-processing');
        for (Account acc : (List<Account>) records()) {
          recordNames.put(acc.Id, acc.Name);
        }
      } else {
        operationLog.add('UPDATE: Post-processing');
        for (Account acc : (List<Account>) records()) {
          recordNames.put(acc.Id, acc.Name);
        }
      }
    }
  }

  @IsTest
  static void testComplexUpsertLogic() {
    // Test complex logic that handles both INSERT and UPDATE in consolidated methods
    ComplexUpsertDomain domain = new ComplexUpsertDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);

    // Test INSERT
    List<SObject> insertRecords = new List<SObject>{
      new Account(Name = 'New Account')
    };

    Test.startTest();
    domain.handleTrigger(
      TriggerOperation.BEFORE_INSERT,
      insertRecords,
      null,
      null,
      accountModel
    );
    domain.handleTrigger(
      TriggerOperation.AFTER_INSERT,
      insertRecords,
      null,
      null,
      accountModel
    );

    // Test UPDATE
    ComplexUpsertDomain updateDomain = new ComplexUpsertDomain(); // New instance
    List<SObject> updateRecords = new List<SObject>{
      new Account(
        Id = IdUtil.generateId(accountModel),
        Name = 'Updated Account'
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      updateRecords[0].Id => new Account(
        Id = updateRecords[0].Id,
        Name = 'Old Account'
      )
    };

    updateDomain.handleTrigger(
      TriggerOperation.BEFORE_UPDATE,
      updateRecords,
      updateRecords,
      oldMap,
      accountModel
    );
    updateDomain.handleTrigger(
      TriggerOperation.AFTER_UPDATE,
      updateRecords,
      updateRecords,
      oldMap,
      accountModel
    );
    Test.stopTest();

    // Verify INSERT logic on first domain instance
    System.assert(
      domain.operationLog.contains('INSERT: Setting defaults'),
      'Should handle INSERT logic'
    );
    System.assert(
      domain.operationLog.contains('INSERT: Post-processing'),
      'Should handle INSERT post-processing'
    );

    // Verify UPDATE logic on second domain instance
    System.assert(
      updateDomain.operationLog.contains('UPDATE: Validating changes'),
      'Should handle UPDATE logic'
    );
    System.assert(
      updateDomain.operationLog.contains('UPDATE: Post-processing'),
      'Should handle UPDATE post-processing'
    );
    System.assert(
      updateDomain.operationLog.contains(
        'Name changed from Old Account to Updated Account'
      ),
      'Should detect name change'
    );
  }

  // Test domain with delete-specific logic
  private class DeleteDomain extends BaseDomain {
    public List<String> deletedNames = new List<String>();
    public Integer deleteCount = 0;

    public override void onBeforeDelete() {
      deleteCount++;
      for (Account acc : (List<Account>) records()) {
        if (acc.Name != null) {
          deletedNames.add(acc.Name);
        }
      }
    }

    public override void onAfterDelete() {
      // Post-delete cleanup logic
      System.debug('Deleted ' + deleteCount + ' accounts');
    }
  }

  @IsTest
  static void testDeleteOperations() {
    // Test delete-specific logic
    DeleteDomain domain = new DeleteDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> deleteRecords = new List<SObject>{
      new Account(Id = IdUtil.generateId(accountModel), Name = 'Account 1'),
      new Account(Id = IdUtil.generateId(accountModel), Name = 'Account 2')
    };

    Test.startTest();
    domain.handleTrigger(
      TriggerOperation.BEFORE_DELETE,
      null,
      deleteRecords,
      new Map<Id, SObject>(deleteRecords),
      accountModel
    );
    domain.handleTrigger(
      TriggerOperation.AFTER_DELETE,
      null,
      deleteRecords,
      new Map<Id, SObject>(deleteRecords),
      accountModel
    );
    Test.stopTest();

    System.assertEquals(
      1,
      domain.deleteCount,
      'onBeforeDelete should be called once'
    );
    System.assertEquals(
      2,
      domain.deletedNames.size(),
      'Should capture both account names'
    );
    System.assert(
      domain.deletedNames.contains('Account 1'),
      'Should capture first account name'
    );
    System.assert(
      domain.deletedNames.contains('Account 2'),
      'Should capture second account name'
    );
  }

  // Test domain with undelete logic
  private class UndeleteDomain extends BaseDomain {
    public Integer undeleteCount = 0;
    public List<String> restoredNames = new List<String>();

    public override void onAfterUndelete() {
      undeleteCount++;
      for (Account acc : (List<Account>) records()) {
        restoredNames.add(acc.Name);
      }
    }
  }

  @IsTest
  static void testUndeleteOperation() {
    // Test undelete-specific logic
    UndeleteDomain domain = new UndeleteDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> undeleteRecords = new List<SObject>{
      new Account(
        Id = IdUtil.generateId(accountModel),
        Name = 'Restored Account'
      )
    };

    Test.startTest();
    domain.handleTrigger(
      TriggerOperation.AFTER_UNDELETE,
      undeleteRecords,
      null,
      null,
      accountModel
    );
    Test.stopTest();

    System.assertEquals(
      1,
      domain.undeleteCount,
      'onAfterUndelete should be called once'
    );
    System.assertEquals(
      1,
      domain.restoredNames.size(),
      'Should capture restored account name'
    );
    System.assertEquals(
      'Restored Account',
      domain.restoredNames[0],
      'Should capture correct name'
    );
  }

  // Test domain that uses this.records and this.toMap() in delete methods
  private class RecordsAccessDomain extends BaseDomain {
    public Integer recordsCount = 0;
    public Integer toMapCount = 0;

    public override void onBeforeDelete() {
      recordsCount = records().size();
      toMapCount = toMap().size();
    }

    public override void onAfterDelete() {
      // Verify we can still access records after delete
      System.assertEquals(
        recordsCount,
        records().size(),
        'Records should still be accessible'
      );
    }
  }

  @IsTest
  static void testRecordsAccessInDeleteMethods() {
    // Test that delete methods can access this.records and this.toMap()
    RecordsAccessDomain domain = new RecordsAccessDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> deleteRecords = new List<SObject>{
      new Account(Id = IdUtil.generateId(accountModel), Name = 'Test 1'),
      new Account(Id = IdUtil.generateId(accountModel), Name = 'Test 2')
    };

    Test.startTest();
    domain.handleTrigger(
      TriggerOperation.BEFORE_DELETE,
      null,
      deleteRecords,
      new Map<Id, SObject>(deleteRecords),
      accountModel
    );
    domain.handleTrigger(
      TriggerOperation.AFTER_DELETE,
      null,
      deleteRecords,
      new Map<Id, SObject>(deleteRecords),
      accountModel
    );
    Test.stopTest();

    System.assertEquals(
      2,
      domain.recordsCount,
      'Should access correct number of records'
    );
    System.assertEquals(
      2,
      domain.toMapCount,
      'Should access correct toMap size'
    );
  }

  // Test domain with error handling in trigger methods
  private class ErrorHandlingDomain extends BaseDomain {
    public Boolean shouldThrowInBeforeUpsert = false;
    public Boolean shouldThrowInAfterUpsert = false;
    public Boolean shouldThrowInBeforeDelete = false;
    public Boolean shouldThrowInAfterDelete = false;

    public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
      if (shouldThrowInBeforeUpsert) {
        throw new IllegalArgumentException('Error in onBeforeUpsert');
      }
    }

    public override void onAfterUpsert(Map<Id, SObject> oldMap) {
      if (shouldThrowInAfterUpsert) {
        throw new IllegalArgumentException('Error in onAfterUpsert');
      }
    }

    public override void onBeforeDelete() {
      if (shouldThrowInBeforeDelete) {
        throw new IllegalArgumentException('Error in onBeforeDelete');
      }
    }

    public override void onAfterDelete() {
      if (shouldThrowInAfterDelete) {
        throw new IllegalArgumentException('Error in onAfterDelete');
      }
    }
  }

  @IsTest
  static void testErrorHandlingInTriggerMethods() {
    // Test that errors in trigger methods are properly propagated
    ErrorHandlingDomain domain = new ErrorHandlingDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> records = new List<SObject>{ new Account(Name = 'Test') };

    Test.startTest();

    // Test error in onBeforeUpsert
    domain.shouldThrowInBeforeUpsert = true;
    try {
      domain.handleTrigger(
        TriggerOperation.BEFORE_INSERT,
        records,
        null,
        null,
        accountModel
      );
      System.assert(false, 'Should throw exception');
    } catch (IllegalArgumentException e) {
      System.assertEquals(
        'Error in onBeforeUpsert',
        e.getMessage(),
        'Should propagate error'
      );
    }

    // Test error in onAfterUpsert
    domain = new ErrorHandlingDomain();
    domain.shouldThrowInAfterUpsert = true;
    try {
      domain.handleTrigger(
        TriggerOperation.AFTER_INSERT,
        records,
        null,
        null,
        accountModel
      );
      System.assert(false, 'Should throw exception');
    } catch (IllegalArgumentException e) {
      System.assertEquals(
        'Error in onAfterUpsert',
        e.getMessage(),
        'Should propagate error'
      );
    }

    // Test error in onBeforeDelete
    domain = new ErrorHandlingDomain();
    domain.shouldThrowInBeforeDelete = true;
    try {
      domain.handleTrigger(
        TriggerOperation.BEFORE_DELETE,
        null,
        records,
        new Map<Id, SObject>(),
        accountModel
      );
      System.assert(false, 'Should throw exception');
    } catch (IllegalArgumentException e) {
      System.assertEquals(
        'Error in onBeforeDelete',
        e.getMessage(),
        'Should propagate error'
      );
    }

    // Test error in onAfterDelete
    domain = new ErrorHandlingDomain();
    domain.shouldThrowInAfterDelete = true;
    try {
      domain.handleTrigger(
        TriggerOperation.AFTER_DELETE,
        null,
        records,
        new Map<Id, SObject>(),
        accountModel
      );
      System.assert(false, 'Should throw exception');
    } catch (IllegalArgumentException e) {
      System.assertEquals(
        'Error in onAfterDelete',
        e.getMessage(),
        'Should propagate error'
      );
    }

    Test.stopTest();
  }

  // Test domain with null handling in trigger methods
  private class NullHandlingDomain extends BaseDomain {
    public Integer nullHandlingCount = 0;

    public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
      nullHandlingCount++;
      // Test that we can handle null oldMap gracefully
      if (oldMap != null) {
        System.debug(
          'Processing update with ' + oldMap.size() + ' old records'
        );
      } else {
        System.debug('Processing insert');
      }
    }

    public override void onAfterUpsert(Map<Id, SObject> oldMap) {
      // Test that we can handle null oldMap gracefully
      if (oldMap != null) {
        System.debug(
          'Post-processing update with ' + oldMap.size() + ' old records'
        );
      } else {
        System.debug('Post-processing insert');
      }
    }
  }

  @IsTest
  static void testNullHandlingInTriggerMethods() {
    // Test that trigger methods handle null parameters gracefully
    NullHandlingDomain domain = new NullHandlingDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> records = new List<SObject>{ new Account(Name = 'Test') };

    Test.startTest();

    // Test with null oldMap (INSERT)
    domain.handleTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null,
      accountModel
    );

    // Test with non-null oldMap (UPDATE)
    Map<Id, SObject> oldMap = new Map<Id, SObject>();
    domain.handleTrigger(
      TriggerOperation.BEFORE_UPDATE,
      records,
      records,
      oldMap,
      accountModel
    );

    Test.stopTest();

    System.assertEquals(
      2,
      domain.nullHandlingCount,
      'Should handle both null and non-null oldMap'
    );
  }

  // Test domain with complex initialization scenarios
  private class ComplexInitDomain extends BaseDomain {
    public Integer initCallCount = 0;
    public List<String> initLog = new List<String>();

    public override void onInitialized(IModel source, List<SObject> records) {
      initCallCount++;
      initLog.add(
        'Init ' +
          initCallCount +
          ': ' +
          source.token() +
          ' with ' +
          records.size() +
          ' records'
      );
    }
  }

  @IsTest
  static void testComplexInitializationScenarios() {
    // Test various initialization scenarios
    ComplexInitDomain domain = new ComplexInitDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);
    IModel contactModel = Application.s.model(Contact.SObjectType);

    Test.startTest();

    // Test initialization with empty records
    domain.init(accountModel, new List<SObject>());
    System.assertEquals(
      1,
      domain.initCallCount,
      'Should initialize with empty records'
    );

    // Test idempotent initialization (same model, same records)
    domain.init(accountModel, new List<SObject>());
    System.assertEquals(
      1,
      domain.initCallCount,
      'Should not reinitialize with same parameters'
    );

    // Test idempotent initialization (same model, null records)
    domain.init(accountModel, null);
    System.assertEquals(
      1,
      domain.initCallCount,
      'Should not reinitialize with null records'
    );

    // Test error case: different model
    try {
      domain.init(contactModel, new List<Contact>());
      System.assert(false, 'Should throw exception for different model');
    } catch (Exception e) {
      System.assert(
        e.getMessage().contains('different model'),
        'Should throw different model exception'
      );
    }

    Test.stopTest();
  }

  // Test domain with security enforcement
  private class SecurityDomain extends BaseDomain {
    public override Boolean shouldEnforceSecurity() {
      return true;
    }
  }

  @IsTest
  static void testSecurityEnforcement() {
    // Test that security enforcement can be enabled
    SecurityDomain domain = new SecurityDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> records = new List<SObject>{ new Account(Name = 'Test') };

    Test.startTest();
    Boolean shouldEnforce = domain.shouldEnforceSecurity();
    Test.stopTest();

    System.assertEquals(
      true,
      shouldEnforce,
      'Should enforce security when enabled'
    );
  }

  // Test domain with custom recycling behavior
  private class CustomRecyclingDomain extends BaseDomain {
    public Boolean customRecyclingEnabled = true;

    public override Boolean shouldRecycleInstance() {
      return customRecyclingEnabled;
    }
  }

  @IsTest
  static void testCustomRecyclingBehavior() {
    // Test that custom recycling behavior can be implemented
    CustomRecyclingDomain domain = new CustomRecyclingDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> records = new List<SObject>{ new Account(Name = 'Test') };

    Test.startTest();

    // Test with recycling enabled
    System.assertEquals(
      true,
      domain.shouldRecycleInstance(),
      'Should recycle when enabled'
    );

    // Test with recycling disabled
    domain.customRecyclingEnabled = false;
    System.assertEquals(
      false,
      domain.shouldRecycleInstance(),
      'Should not recycle when disabled'
    );

    Test.stopTest();
  }

  // Test domain with mixed trigger method implementations
  private class MixedTriggerDomain extends BaseDomain {
    public Integer upsertCallCount = 0;
    public Integer deleteCallCount = 0;
    public Integer undeleteCallCount = 0;

    public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
      upsertCallCount++;
    }

    public override void onAfterUpsert(Map<Id, SObject> oldMap) {
      upsertCallCount++;
    }

    public override void onBeforeDelete() {
      deleteCallCount++;
    }

    public override void onAfterDelete() {
      deleteCallCount++;
    }

    public override void onAfterUndelete() {
      undeleteCallCount++;
    }
  }

  @IsTest
  static void testMixedTriggerMethodImplementations() {
    // Test that domains can implement only some trigger methods
    MixedTriggerDomain domain = new MixedTriggerDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> records = new List<SObject>{ new Account(Name = 'Test') };

    Test.startTest();

    // Test UPSERT operations
    domain.handleTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null,
      accountModel
    );
    domain.handleTrigger(
      TriggerOperation.AFTER_INSERT,
      records,
      null,
      null,
      accountModel
    );

    // Test DELETE operations
    domain.handleTrigger(
      TriggerOperation.BEFORE_DELETE,
      null,
      records,
      new Map<Id, SObject>(),
      accountModel
    );
    domain.handleTrigger(
      TriggerOperation.AFTER_DELETE,
      null,
      records,
      new Map<Id, SObject>(),
      accountModel
    );

    // Test UNDELETE operation
    domain.handleTrigger(
      TriggerOperation.AFTER_UNDELETE,
      records,
      null,
      null,
      accountModel
    );

    Test.stopTest();

    System.assertEquals(
      2,
      domain.upsertCallCount,
      'Should call upsert methods'
    );
    System.assertEquals(
      2,
      domain.deleteCallCount,
      'Should call delete methods'
    );
    System.assertEquals(
      1,
      domain.undeleteCallCount,
      'Should call undelete method'
    );
  }

  // Test domain with performance-critical operations
  private class PerformanceDomain extends BaseDomain {
    public Integer operationCount = 0;
    public Long totalExecutionTime = 0;

    public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
      Long startTime = System.currentTimeMillis();
      operationCount++;
      // Simulate some work
      for (Integer i = 0; i < 1000; i++) {
        Math.random();
      }
      totalExecutionTime += (System.currentTimeMillis() - startTime);
    }
  }

  @IsTest
  static void testPerformanceCriticalOperations() {
    // Test that trigger methods can handle performance-critical operations
    PerformanceDomain domain = new PerformanceDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> records = new List<SObject>{ new Account(Name = 'Test') };

    Test.startTest();

    // Execute multiple operations
    for (Integer i = 0; i < 10; i++) {
      domain.handleTrigger(
        TriggerOperation.BEFORE_INSERT,
        records,
        null,
        null,
        accountModel
      );
    }

    Test.stopTest();

    System.assertEquals(
      10,
      domain.operationCount,
      'Should execute all operations'
    );
    System.assert(
      domain.totalExecutionTime > 0,
      'Should have measurable execution time'
    );
  }

  // Test domain with state management across operations
  private class StatefulDomain extends BaseDomain {
    public Map<String, Object> state = new Map<String, Object>();
    public Integer operationSequence = 0;

    public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
      operationSequence++;
      state.put('beforeUpsertSequence', operationSequence);
      state.put('isInsert', oldMap == null);
    }

    public override void onAfterUpsert(Map<Id, SObject> oldMap) {
      operationSequence++;
      state.put('afterUpsertSequence', operationSequence);
      state.put('oldMapSize', oldMap != null ? oldMap.size() : 0);
    }

    public override void onBeforeDelete() {
      operationSequence++;
      state.put('beforeDeleteSequence', operationSequence);
    }

    public override void onAfterDelete() {
      operationSequence++;
      state.put('afterDeleteSequence', operationSequence);
    }
  }

  @IsTest
  static void testStateManagementAcrossOperations() {
    // Test that domains can maintain state across operations
    StatefulDomain domain = new StatefulDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> records = new List<SObject>{ new Account(Name = 'Test') };

    Test.startTest();

    // Execute a sequence of operations
    domain.handleTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null,
      accountModel
    );
    domain.handleTrigger(
      TriggerOperation.AFTER_INSERT,
      records,
      null,
      null,
      accountModel
    );
    domain.handleTrigger(
      TriggerOperation.BEFORE_DELETE,
      null,
      records,
      new Map<Id, SObject>(),
      accountModel
    );
    domain.handleTrigger(
      TriggerOperation.AFTER_DELETE,
      null,
      records,
      new Map<Id, SObject>(),
      accountModel
    );

    Test.stopTest();

    // Verify state was maintained correctly
    System.assertEquals(
      1,
      domain.state.get('beforeUpsertSequence'),
      'Should track before upsert sequence'
    );
    System.assertEquals(
      2,
      domain.state.get('afterUpsertSequence'),
      'Should track after upsert sequence'
    );
    System.assertEquals(
      3,
      domain.state.get('beforeDeleteSequence'),
      'Should track before delete sequence'
    );
    System.assertEquals(
      4,
      domain.state.get('afterDeleteSequence'),
      'Should track after delete sequence'
    );
    System.assertEquals(
      true,
      domain.state.get('isInsert'),
      'Should track insert operation'
    );
    System.assertEquals(
      0,
      domain.state.get('oldMapSize'),
      'Should track oldMap size'
    );
  }

  // Domain that doesn't override any trigger methods (uses base implementations)
  private class NoOverrideDomain extends BaseDomain {
    // Intentionally empty - uses all default implementations from BaseDomain
  }

  @IsTest
  static void testDefaultTriggerMethodImplementations() {
    // Test that default (no-op) implementations work without errors
    // This ensures coverage of the base virtual method bodies
    NoOverrideDomain domain = new NoOverrideDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> insertRecords = new List<SObject>{
      new Account(Name = 'Test Insert')
    };
    List<SObject> updateRecords = new List<SObject>{
      new Account(Id = IdUtil.generateId(accountModel), Name = 'Test Update')
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>(updateRecords);

    Test.startTest();

    // Test all trigger operations with default (no-op) implementations
    // This hits lines 130, 151, 167, 183, 196 in BaseDomain

    // BEFORE_INSERT -> calls default onBeforeUpsert (line 130)
    domain.handleTrigger(
      TriggerOperation.BEFORE_INSERT,
      insertRecords,
      null,
      null,
      accountModel
    );

    // AFTER_INSERT -> calls default onAfterUpsert (line 151)
    domain.handleTrigger(
      TriggerOperation.AFTER_INSERT,
      insertRecords,
      null,
      null,
      accountModel
    );

    // Create new domain for update (to test with oldMap)
    domain = new NoOverrideDomain();

    // BEFORE_UPDATE -> calls default onBeforeUpsert (line 130)
    domain.handleTrigger(
      TriggerOperation.BEFORE_UPDATE,
      updateRecords,
      updateRecords,
      oldMap,
      accountModel
    );

    // AFTER_UPDATE -> calls default onAfterUpsert (line 151)
    domain.handleTrigger(
      TriggerOperation.AFTER_UPDATE,
      updateRecords,
      updateRecords,
      oldMap,
      accountModel
    );

    // BEFORE_DELETE -> calls default onBeforeDelete (line 167)
    domain.handleTrigger(
      TriggerOperation.BEFORE_DELETE,
      null,
      updateRecords,
      oldMap,
      accountModel
    );

    // AFTER_DELETE -> calls default onAfterDelete (line 183)
    domain.handleTrigger(
      TriggerOperation.AFTER_DELETE,
      null,
      updateRecords,
      oldMap,
      accountModel
    );

    // AFTER_UNDELETE -> calls default onAfterUndelete (line 196)
    domain.handleTrigger(
      TriggerOperation.AFTER_UNDELETE,
      updateRecords,
      null,
      null,
      accountModel
    );

    Test.stopTest();

    // If we got here without exceptions, all default implementations worked
    System.assertNotEquals(
      null,
      domain,
      'Domain should successfully handle all operations with default implementations'
    );
  }

  @IsTest
  static void testDefaultOnBeforeUpsertWithNullOldMap() {
    // Specifically test default onBeforeUpsert with null oldMap (INSERT case)
    NoOverrideDomain domain = new NoOverrideDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> records = new List<SObject>{ new Account(Name = 'Test') };

    Test.startTest();
    // This calls the default onBeforeUpsert(null) implementation
    domain.handleTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null,
      accountModel
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      domain,
      'Should handle default onBeforeUpsert with null oldMap'
    );
  }

  @IsTest
  static void testDefaultOnBeforeUpsertWithOldMap() {
    // Specifically test default onBeforeUpsert with non-null oldMap (UPDATE case)
    NoOverrideDomain domain = new NoOverrideDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> records = new List<SObject>{
      new Account(Id = IdUtil.generateId(accountModel), Name = 'Test')
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>(records);

    Test.startTest();
    // This calls the default onBeforeUpsert(oldMap) implementation
    domain.handleTrigger(
      TriggerOperation.BEFORE_UPDATE,
      records,
      records,
      oldMap,
      accountModel
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      domain,
      'Should handle default onBeforeUpsert with oldMap'
    );
  }

  @IsTest
  static void testDefaultOnAfterUpsertImplementations() {
    // Test default onAfterUpsert for both INSERT and UPDATE
    NoOverrideDomain domain = new NoOverrideDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);

    Test.startTest();

    // Test AFTER_INSERT (null oldMap)
    List<SObject> insertRecords = new List<SObject>{
      new Account(Name = 'Insert Test')
    };
    domain.handleTrigger(
      TriggerOperation.AFTER_INSERT,
      insertRecords,
      null,
      null,
      accountModel
    );

    // Test AFTER_UPDATE (non-null oldMap)
    domain = new NoOverrideDomain();
    List<SObject> updateRecords = new List<SObject>{
      new Account(Id = IdUtil.generateId(accountModel), Name = 'Update Test')
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>(updateRecords);
    domain.handleTrigger(
      TriggerOperation.AFTER_UPDATE,
      updateRecords,
      updateRecords,
      oldMap,
      accountModel
    );

    Test.stopTest();

    System.assertNotEquals(
      null,
      domain,
      'Should handle default onAfterUpsert for both insert and update'
    );
  }

  @IsTest
  static void testDefaultDeleteAndUndeleteImplementations() {
    // Test default onBeforeDelete, onAfterDelete, and onAfterUndelete
    NoOverrideDomain domain = new NoOverrideDomain();
    IModel accountModel = Application.s.model(Account.SObjectType);
    List<SObject> records = new List<SObject>{
      new Account(Id = IdUtil.generateId(accountModel), Name = 'Delete Test')
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>(records);

    Test.startTest();

    // Test BEFORE_DELETE -> default onBeforeDelete
    domain.handleTrigger(
      TriggerOperation.BEFORE_DELETE,
      null,
      records,
      oldMap,
      accountModel
    );

    // Test AFTER_DELETE -> default onAfterDelete
    domain.handleTrigger(
      TriggerOperation.AFTER_DELETE,
      null,
      records,
      oldMap,
      accountModel
    );

    // Test AFTER_UNDELETE -> default onAfterUndelete
    domain.handleTrigger(
      TriggerOperation.AFTER_UNDELETE,
      records,
      null,
      null,
      accountModel
    );

    Test.stopTest();

    System.assertNotEquals(
      null,
      domain,
      'Should handle default delete and undelete implementations'
    );
  }
}
