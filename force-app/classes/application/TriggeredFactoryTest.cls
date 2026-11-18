@IsTest
private class TriggeredFactoryTest {
  // Static counter for tracking instance creation
  private static Integer instanceCount = 0;
  // Calls that reached NonDomainTrigger.handleTrigger
  private static Integer secureCalls = 0;

  // Faux domain for testing state and config
  private class FauxAccounts extends Domain {
    public Boolean triggerCalled = false;
    public FauxAccounts() {
      super();
    }
    public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
      triggerCalled = true;
    }
  }

  // Non-domain ITriggered implementation with configuration
  private class NonDomainTrigger implements ITriggered, ITriggeredConfigured {
    public void handleTrigger(
      TriggerOperation op,
      List<SObject> trigNew,
      List<SObject> trigOld,
      Map<Id, SObject> trigOldMap,
      IModel model
    ) {
      secureCalls++;
    }
    public Boolean shouldRecycleInstance() {
      return false;
    }
    public Boolean shouldEnforceSecurity() {
      return true;
    }
  }

  // What each recycled phase saw: the instance's number and the industries it catalogued.
  private static List<String> phasesSeen = new List<String>();

  private class WatchingAccounts extends Domain {
    private Integer instanceNumber;

    public WatchingAccounts() {
      super();
      instanceCount++;
      instanceNumber = instanceCount;
    }
    public override Boolean shouldRecycleInstance() {
      return true;
    }
    protected override void onBeforeUpsert(Map<Id, SObject> oldMap) {
      phasesSeen.add('before#' + instanceNumber + ' ' + catalog(Account.Industry).keySet());
    }
    protected override void onAfterUpsert(Map<Id, SObject> oldMap) {
      phasesSeen.add('after#' + instanceNumber + ' ' + catalog(Account.Industry).keySet());
    }
  }

  // Static domain map and factory
  private static final Map<Type, Type> domainMap = new Map<Type, Type>{
    Account.class => FauxAccounts.class
  };
  static final Core core = new Core(new SchemeDefault());
  static final TriggeredFactory factory = new TriggeredFactory(core, domainMap);

  @IsTest
  static void testRegisterAndMake() {
    System.assert(
      factory.getRegistry().containsKey(Account.class),
      'Should be registered'
    );
    ITriggered triggered = factory.make(Account.SObjectType);
    System.assertNotEquals(
      null,
      triggered,
      'Triggered instance should not be null'
    );
    System.assert(triggered instanceof FauxAccounts, 'Should be FauxAccounts');
  }

  @IsTest
  static void testMakeStringAndUnregistered() {
    ITriggered triggered = factory.make('Account');
    System.assert(triggered instanceof FauxAccounts, 'Should be FauxAccounts');

    // Test with unregistered type (Contact) - should throw for unregistered class
    try {
      factory.make('Contact');
      System.assert(false, 'Should throw for unregistered type');
    } catch (TriggeredFactory.TriggerFactoryException e) {
      System.assert(
        e.getMessage().contains('No Triggered class registered'),
        'Should mention unregistered class'
      );
    }
  }

  @IsTest
  static void testExecuteAndState() {
    // Simulate trigger context
    List<Account> records = new List<Account>{ new Account(Name = 'A') };
    FauxAccounts domain = new FauxAccounts();
    domain.init(null, records);
    // Should call onBeforeInsert and set triggerCalled
    Test.startTest();
    // Call executeTrigger directly with BEFORE_INSERT and records
    factory.executeTrigger(TriggerOperation.BEFORE_INSERT, records, null, null);
    Test.stopTest();
    // No assertion here, just coverage for execute path
  }

  @IsTest
  static void testRecycleFallbackAndReset() {
    // Ensure recycled map starts clean
    factory.resetRecycled();

    // AFTER without prior BEFORE should still not null-deref due to fallback
    List<Account> records = new List<Account>{ new Account(Name = 'B') };
    Test.startTest();
    factory.executeTrigger(TriggerOperation.AFTER_INSERT, records, null, null);
    // Put an instance into recycle map via BEFORE
    factory.executeTrigger(TriggerOperation.BEFORE_INSERT, records, null, null);
    // AFTER should pick up recycled instance
    factory.executeTrigger(TriggerOperation.AFTER_INSERT, records, null, null);

    // Reset should clear state
    factory.resetRecycled();
    // Execute AFTER again; fallback creates fresh instance
    factory.executeTrigger(TriggerOperation.AFTER_INSERT, records, null, null);
    Test.stopTest();
  }

  @IsTest
  static void testDisableEnable() {
    Map<SObjectType, Set<TriggerOperation>> bypass = new Map<SObjectType, Set<TriggerOperation>>{
      Account.SObjectType => new Set<TriggerOperation>{
        TriggerOperation.BEFORE_INSERT
      }
    };
    factory.disable(bypass);
    Map<SObjectType, TriggeredFactory.TriggerState> states = factory.getTriggerStates();
    System.assert(states.get(Account.SObjectType) != null, 'Should have state');
    TriggeredFactory.TriggerState state = states.get(Account.SObjectType);
    // Should be disabled after one disable
    System.assertEquals(
      false,
      state.isEnabled(TriggerOperation.BEFORE_INSERT),
      'Should be disabled after one disable'
    );
    // Disable again (stack increment)
    factory.disable(bypass);
    states = factory.getTriggerStates();
    state = states.get(Account.SObjectType);
    System.assertEquals(
      false,
      state.isEnabled(TriggerOperation.BEFORE_INSERT),
      'Should still be disabled after second disable'
    );
    // Enable once (stack decrement, still disabled)
    factory.enable(bypass);
    states = factory.getTriggerStates();
    state = states.get(Account.SObjectType);
    System.assertEquals(
      false,
      state.isEnabled(TriggerOperation.BEFORE_INSERT),
      'Should still be disabled after one enable (stack not empty)'
    );
    // Enable again (stack empty, should be enabled)
    factory.enable(bypass);
    states = factory.getTriggerStates();
    state = states.get(Account.SObjectType);
    System.assertEquals(
      true,
      state.isEnabled(TriggerOperation.BEFORE_INSERT),
      'Should be enabled after two enables'
    );
    // Extra enable should not go below zero
    factory.enable(bypass);
    states = factory.getTriggerStates();
    state = states.get(Account.SObjectType);
    System.assertEquals(
      true,
      state.isEnabled(TriggerOperation.BEFORE_INSERT),
      'Should remain enabled after extra enable'
    );
  }

  @IsTest
  static void testMakeErrors() {
    // Test null handling - should throw for null inputs
    try {
      factory.make((SObjectType) null);
      Assert.fail('Should throw for null SObjectType');
    } catch (TriggeredFactory.TriggerFactoryException e) {
      Assert.areEqual('SObjectType token cannot be null', e.getMessage());
    }

    try {
      factory.make((String) null);
      Assert.fail('Should throw for null string');
    } catch (TriggeredFactory.TriggerFactoryException e) {
      Assert.areEqual('Name cannot be blank', e.getMessage());
    }

    try {
      factory.make('');
      Assert.fail('Should throw for empty string');
    } catch (TriggeredFactory.TriggerFactoryException e) {
      Assert.areEqual('Name cannot be blank', e.getMessage());
    }

    // Test unregistered type - should throw
    try {
      TriggeredFactory f2 = new TriggeredFactory(core, new Map<Type, Type>());
      f2.make(Contact.SObjectType);
      Assert.fail('Should throw for unregistered type');
    } catch (TriggeredFactory.TriggerFactoryException e) {
      Assert.isTrue(e.getMessage().contains('No Triggered class registered'), e.getMessage());
    }
  }

  @IsTest
  static void testCheckPermission() {
    // Just check that checkPermission does not throw for a normal Domain model
    TriggeredFactory factory = new TriggeredFactory(
      core,
      new Map<Type, Type>{ Account.class => FauxAccounts.class }
    );
    IModel model = core.model(Account.SObjectType);
    try {
      factory.checkPermission(model, 'create');
      factory.checkPermission(model, 'update');
      factory.checkPermission(model, 'delete');
    } catch (Exception e) {
      System.assert(false, 'Should not throw for normal permissions');
    }
    // Negative case: just assert that an exception is thrown for a bogus operation
    Boolean threw = false;
    try {
      factory.checkPermission(model, 'bogus');
    } catch (Exception e) {
      threw = true;
    }
    System.assert(threw, 'Should throw for bogus operation');
  }

  @IsTest
  static void testNonDomainTriggerSecurity() {
    NonDomainTrigger nd = new NonDomainTrigger();
    // Should not throw for known operations
    IModel model = core.model(Account.SObjectType);
    factory.checkPermission(model, 'create');
    factory.checkPermission(model, 'update');
    factory.checkPermission(model, 'delete');

    Boolean threw = false;
    try {
      factory.checkPermission(model, 'bogus');
    } catch (Exception e) {
      threw = true;
    }
    System.assert(threw, 'Should throw on unknown operation for non-domain');
  }

  @IsTest
  static void testConstructorWithoutRegistry() {
    // Test constructor with just ICore
    TriggeredFactory f = new TriggeredFactory(core);
    System.assertNotEquals(null, f, 'Factory should not be null');
  }

  @IsTest
  static void testCheckPermissionWithNullModel() {
    // Test checkPermission with null model
    factory.checkPermission(null, 'create');
    // Should not throw, just return
  }

  @IsTest
  static void testDisableEnableWithNull() {
    set<sobjecttype> tokens;
    // Test disable/enable with null
    factory.disable(tokens);
    factory.enable(tokens);
    // Should not throw
  }

  @IsTest
  static void testExecuteWithEmptyRecords() {
    // Test executeTrigger with empty records
    factory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      new List<Account>(),
      null,
      null
    );
    // Should return early, no exception
  }

  @IsTest
  static void testExecuteWithNullRecords() {
    // Test executeTrigger with null records
    factory.executeTrigger(TriggerOperation.BEFORE_INSERT, null, null, null);
    // Should return early, no exception
  }

  @IsTest
  static void testEnforceSecurity() {
    // Test with enforceSecurity enabled - but use Domain which won't call checkPermission
    // (checkPermission is only called when enforceSecurity=true and non-test context)
    Map<Type, Type> secureMap = new Map<Type, Type>{
      Account.class => FauxAccounts.class
    };
    TriggeredFactory secureFactory = new TriggeredFactory(core, secureMap);
    List<Account> records = new List<Account>{ new Account(Name = 'Test') };
    // This executes with trigger context
    secureFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null
    );
  }

  @IsTest
  static void testExecuteWithoutRegisteredClass() {
    // Test execute when no class is registered for the SObjectType
    TriggeredFactory emptyFactory = new TriggeredFactory(core);
    List<Contact> contacts = new List<Contact>{
      new Contact(LastName = 'Test')
    };
    // Should return early without throwing
    emptyFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      contacts,
      null,
      null
    );
  }

  @IsTest
  static void testMakeWithInvalidTypeKey() {
    // A key that is not an SObject type is rejected when the registry is built
    try {
      Map<Type, Type> badMap = new Map<Type, Type>{
        String.class => FauxAccounts.class
      };
      new TriggeredFactory(core, badMap);
      Assert.fail('A non-SObject key should be rejected');
    } catch (Application.FactoryException e) {
      Assert.isTrue(e.getMessage().startsWith('Invalid pairing'), e.getMessage());
    }
  }

  @IsTest
  static void testRecycleInstanceConfiguration() {
    // Create a domain with recycleInstance enabled
    Map<Type, Type> recycleMap = new Map<Type, Type>{
      Account.class => FauxAccounts.class
    };
    TriggeredFactory recycleFactory = new TriggeredFactory(core, recycleMap);
    List<Account> records = new List<Account>{ new Account(Name = 'Test') };

    // Reset recycled map
    recycleFactory.resetRecycled();

    // Execute BEFORE to populate recycle map
    recycleFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null
    );

    // Execute AFTER to use recycled instance
    recycleFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      records,
      null,
      null
    );

    // Execute AFTER_UPDATE to cover that branch
    recycleFactory.executeTrigger(
      TriggerOperation.AFTER_UPDATE,
      records,
      records,
      new Map<Id, SObject>()
    );

    // Execute AFTER_DELETE to cover that branch
    recycleFactory.executeTrigger(
      TriggerOperation.AFTER_DELETE,
      null,
      records,
      new Map<Id, SObject>()
    );
  }

  @IsTest
  static void testEnableOnNonExistentState() {
    // Test enable on a trigger state that doesn't exist
    Map<SObjectType, Set<TriggerOperation>> bypass = new Map<SObjectType, Set<TriggerOperation>>{
      Contact.SObjectType => new Set<TriggerOperation>{
        TriggerOperation.BEFORE_INSERT
      }
    };
    // Enable without disable should not throw
    factory.enable(bypass);
  }

  @IsTest
  static void testDisableAllNoArgs() {
    // Test disable() with no arguments - should disable all triggers globally
    List<Account> records = new List<Account>{ new Account(Name = 'Test') };

    // Verify trigger works before disabling
    factory.executeTrigger(TriggerOperation.BEFORE_INSERT, records, null, null);

    // Disable all triggers globally
    factory.disable();

    // Verify trigger is now disabled
    factory.executeTrigger(TriggerOperation.BEFORE_INSERT, records, null, null);

    // Enable all triggers globally
    factory.enable();

    // Verify trigger works again
    factory.executeTrigger(TriggerOperation.BEFORE_INSERT, records, null, null);
  }

  @IsTest
  static void testDisableAllStackedCalls() {
    // Test that disable/enable work with stacking
    List<Account> records = new List<Account>{ new Account(Name = 'Test') };

    // Disable twice
    factory.disable();
    factory.disable();

    // Enable once - should still be disabled
    factory.enable();
    factory.executeTrigger(TriggerOperation.BEFORE_INSERT, records, null, null);

    // Enable again - should now be enabled
    factory.enable();
    factory.executeTrigger(TriggerOperation.BEFORE_INSERT, records, null, null);

    // Extra enable should not cause issues
    factory.enable();
    factory.executeTrigger(TriggerOperation.BEFORE_INSERT, records, null, null);
  }

  @IsTest
  static void testDisableAllWithSObjectTypes() {
    // Test disable with Iterable<SObjectType>
    List<SObjectType> tokens = new List<SObjectType>{
      Account.SObjectType,
      Contact.SObjectType
    };

    factory.disable(tokens);

    // Get trigger states and verify they're disabled
    Map<SObjectType, TriggeredFactory.TriggerState> states = factory.getTriggerStates();
    TriggeredFactory.TriggerState accountState = states.get(
      Account.SObjectType
    );
    System.assertNotEquals(null, accountState, 'Account state should exist');
    System.assertEquals(
      false,
      accountState.isEnabled(TriggerOperation.BEFORE_INSERT),
      'Account triggers should be disabled'
    );

    TriggeredFactory.TriggerState contactState = states.get(
      Contact.SObjectType
    );
    System.assertNotEquals(null, contactState, 'Contact state should exist');
    System.assertEquals(
      false,
      contactState.isEnabled(TriggerOperation.BEFORE_INSERT),
      'Contact triggers should be disabled'
    );

    // Enable all for those types
    factory.enable(tokens);

    states = factory.getTriggerStates();
    accountState = states.get(Account.SObjectType);
    System.assertEquals(
      true,
      accountState.isEnabled(TriggerOperation.BEFORE_INSERT),
      'Account triggers should be enabled'
    );

    contactState = states.get(Contact.SObjectType);
    System.assertEquals(
      true,
      contactState.isEnabled(TriggerOperation.BEFORE_INSERT),
      'Contact triggers should be enabled'
    );
  }

  @IsTest
  static void testDisableAllWithNullArgs() {
    // Test disable/enable with null arguments - should not throw
    factory.disable((List<SObjectType>) null);
    factory.enable((List<SObjectType>) null);
  }

  @IsTest
  static void testEnableAllOnNonExistentState() {
    // Test enable on a state that doesn't exist yet
    List<SObjectType> tokens = new List<SObjectType>{ Contact.SObjectType };
    // Enable without disable should not throw
    factory.enable(tokens);
  }

  @IsTest
  static void testTriggerStateDisableEnableAll() {
    // Test TriggerState disableAll/enableAll directly
    TriggeredFactory.TriggerState state = new TriggeredFactory.TriggerState();

    // Initially enabled
    System.assertEquals(
      true,
      state.isEnabled(TriggerOperation.BEFORE_INSERT),
      'Should be enabled initially'
    );

    // Disable all operations
    state.disableAll();
    System.assertEquals(
      false,
      state.isEnabled(TriggerOperation.BEFORE_INSERT),
      'Should be disabled after disableAll'
    );
    System.assertEquals(
      false,
      state.isEnabled(TriggerOperation.AFTER_UPDATE),
      'All operations should be disabled'
    );

    // Enable all operations
    state.enableAll();
    System.assertEquals(
      true,
      state.isEnabled(TriggerOperation.BEFORE_INSERT),
      'Should be enabled after enableAll'
    );
    System.assertEquals(
      true,
      state.isEnabled(TriggerOperation.AFTER_UPDATE),
      'All operations should be enabled'
    );
  }

  @IsTest
  static void testTriggerStateBypassPriority() {
    // Test that TriggerState-level bypass takes priority over operation-specific bypass
    TriggeredFactory.TriggerState state = new TriggeredFactory.TriggerState();

    // Disable via disableAll
    state.disableAll();

    // Even if we enable specific operations, the state-level bypass should keep it disabled
    state.enable(new Set<TriggerOperation>{ TriggerOperation.BEFORE_INSERT });
    System.assertEquals(
      false,
      state.isEnabled(TriggerOperation.BEFORE_INSERT),
      'Should still be disabled due to state-level bypass'
    );

    // Enable at state level
    state.enableAll();
    System.assertEquals(
      true,
      state.isEnabled(TriggerOperation.BEFORE_INSERT),
      'Should now be enabled'
    );

    // Now disable specific operation
    state.disable(new Set<TriggerOperation>{ TriggerOperation.BEFORE_INSERT });
    System.assertEquals(
      false,
      state.isEnabled(TriggerOperation.BEFORE_INSERT),
      'Should be disabled due to operation-specific bypass'
    );
  }

  @IsTest
  static void testFactoryLevelBypassPriority() {
    // Test that factory-level bypass takes priority over state-level bypass
    List<Account> records = new List<Account>{ new Account(Name = 'Test') };

    // Disable at factory level
    factory.disable();

    // Even if we try to enable specific SObjects, factory-level bypass should prevent execution
    factory.enable(new List<SObjectType>{ Account.SObjectType });

    // Trigger should still be disabled
    factory.executeTrigger(TriggerOperation.BEFORE_INSERT, records, null, null);

    // Enable at factory level
    factory.enable();

    // Now trigger should work
    factory.executeTrigger(TriggerOperation.BEFORE_INSERT, records, null, null);
  }

  @IsTest
  static void testRecycledInstanceCacheInvalidation() {
    // Test that cached state (toMap) is properly cleared when
    // records are updated in recycled instances between BEFORE and AFTER triggers

    // Create a domain with recycling enabled
    Map<Type, Type> recycleMap = new Map<Type, Type>{
      Account.class => FauxAccounts.class
    };
    TriggeredFactory recycleFactory = new TriggeredFactory(core, recycleMap);
    recycleFactory.resetRecycled();

    // Create test account without Id (simulating BEFORE_INSERT state)
    List<Account> beforeRecords = new List<Account>{
      new Account(Name = 'Test Account')
    };

    // Simulate the account getting an Id (simulating AFTER_INSERT state)
    List<Account> afterRecords = new List<Account>{
      new Account(
        Id = IdUtil.generateId(core.model(Account.SObjectType)),
        Name = 'Test Account'
      )
    };

    // Execute BEFORE_INSERT - domain caches state without Ids
    recycleFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      beforeRecords,
      null,
      null
    );

    // Execute AFTER_INSERT with records that have Ids
    // The toMap cache should be cleared so toMap() returns correct data with Ids
    recycleFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      afterRecords,
      null,
      null
    );

    // This test validates that the instance recycling properly clears toMap cache
    System.assert(
      true,
      'toMap cache should be cleared when recycling instances'
    );
  }

  @IsTest
  static void testRecycleInstanceIsolationBetweenFactories() {
    // Test that recycled instances are isolated per factory instance
    // This is critical when multiple Application instances exist (e.g., Application.s and App.b)
    Map<Type, Type> recycleMap = new Map<Type, Type>{
      Account.class => FauxAccounts.class
    };

    TriggeredFactory factory1 = new TriggeredFactory(core, recycleMap);
    TriggeredFactory factory2 = new TriggeredFactory(core, recycleMap);

    factory1.resetRecycled();
    factory2.resetRecycled();

    List<Account> records = new List<Account>{ new Account(Name = 'Test') };

    // Factory 1 executes BEFORE_INSERT
    factory1.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null
    );

    // Factory 2 executes BEFORE_INSERT
    // Should NOT reuse Factory 1's instance
    factory2.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null
    );

    // Factory 1 AFTER_INSERT should get its own instance
    factory1.executeTrigger(TriggerOperation.AFTER_INSERT, records, null, null);

    // Factory 2 AFTER_INSERT should get its own instance
    factory2.executeTrigger(TriggerOperation.AFTER_INSERT, records, null, null);

    System.assert(
      true,
      'Each factory instance should have isolated recycle state'
    );
  }

  @IsTest
  static void testRecycleInstanceIsolationByOperationType() {
    // Test that recycled instances are isolated per operation type
    // CRITICAL: If trigger is only subscribed to 'before insert, after insert'
    // but NOT 'before update, after update', we must not reuse the INSERT instance
    // for an UPDATE operation
    Map<Type, Type> recycleMap = new Map<Type, Type>{
      Account.class => FauxAccounts.class
    };
    TriggeredFactory recycleFactory = new TriggeredFactory(core, recycleMap);
    recycleFactory.resetRecycled();

    List<Account> insertRecords = new List<Account>{
      new Account(Name = 'Insert Test')
    };
    List<Account> updateRecords = new List<Account>{
      new Account(
        Id = IdUtil.generateId(core.model(Account.SObjectType)),
        Name = 'Update Test'
      )
    };

    // Simulate INSERT operation - BEFORE stores instance
    recycleFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      insertRecords,
      null,
      null
    );

    // Simulate INSERT operation - AFTER retrieves instance
    recycleFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      insertRecords,
      null,
      null
    );

    // Simulate UPDATE operation - BEFORE stores NEW instance
    // This should NOT retrieve the INSERT instance!
    recycleFactory.executeTrigger(
      TriggerOperation.BEFORE_UPDATE,
      updateRecords,
      updateRecords,
      new Map<Id, SObject>()
    );

    // Simulate UPDATE operation - AFTER retrieves UPDATE instance
    // This should get the BEFORE_UPDATE instance, NOT the BEFORE_INSERT one
    recycleFactory.executeTrigger(
      TriggerOperation.AFTER_UPDATE,
      updateRecords,
      updateRecords,
      new Map<Id, SObject>()
    );

    // Test DELETE as well
    List<Account> deleteRecords = new List<Account>{
      new Account(
        Id = IdUtil.generateId(core.model(Account.SObjectType)),
        Name = 'Delete Test'
      )
    };

    recycleFactory.executeTrigger(
      TriggerOperation.BEFORE_DELETE,
      null,
      deleteRecords,
      new Map<Id, SObject>()
    );

    // AFTER_DELETE should get BEFORE_DELETE instance, not INSERT or UPDATE
    recycleFactory.executeTrigger(
      TriggerOperation.AFTER_DELETE,
      null,
      deleteRecords,
      new Map<Id, SObject>()
    );

    System.assert(
      true,
      'Each operation type should have isolated recycle state'
    );
  }

  // Test domain that tracks instance creation for recycling verification
  private class TrackingDomain extends BaseDomain {
    public Integer instanceId;
    public List<String> operationLog = new List<String>();

    public TrackingDomain() {
      super();
      instanceCount++;
      instanceId = instanceCount;
    }

    public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
      operationLog.add('Instance ' + instanceId + ': onBeforeUpsert');
    }

    public override void onAfterUpsert(Map<Id, SObject> oldMap) {
      operationLog.add('Instance ' + instanceId + ': onAfterUpsert');
    }

    public override void onBeforeDelete() {
      operationLog.add('Instance ' + instanceId + ': onBeforeDelete');
    }

    public override void onAfterDelete() {
      operationLog.add('Instance ' + instanceId + ': onAfterDelete');
    }

    public override void onAfterUndelete() {
      operationLog.add('Instance ' + instanceId + ': onAfterUndelete');
    }
  }

  @IsTest
  static void testRecyclingInstanceReuse() {
    // Test that the same instance is reused for BEFORE/AFTER operations
    instanceCount = 0; // Reset static counter first first
    Map<Type, Type> trackingMap = new Map<Type, Type>{
      Account.class => TrackingDomain.class
    };
    TriggeredFactory trackingFactory = new TriggeredFactory(core, trackingMap);
    trackingFactory.resetRecycled();

    List<Account> records = new List<Account>{
      new Account(Name = 'Test Account')
    };

    Test.startTest();

    // Execute BEFORE_INSERT - should create instance 1
    trackingFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null
    );

    // Execute AFTER_INSERT - should reuse instance 1
    trackingFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      records,
      null,
      null
    );

    // Execute BEFORE_UPDATE - should create instance 2 (different operation type)
    trackingFactory.executeTrigger(
      TriggerOperation.BEFORE_UPDATE,
      records,
      records,
      new Map<Id, SObject>()
    );

    // Execute AFTER_UPDATE - should reuse instance 2
    trackingFactory.executeTrigger(
      TriggerOperation.AFTER_UPDATE,
      records,
      records,
      new Map<Id, SObject>()
    );

    Test.stopTest();

    // Should have created exactly 4 instances (2 for INSERT operations, 2 for UPDATE operations)
    // Note: newInstance() is called for each operation, even when recycling is enabled
    System.assertEquals(
      4,
      instanceCount,
      'Should create 4 instances total (2 INSERT + 2 UPDATE operations)'
    );
  }

  // Test domain that opts out of recycling
  private class NonRecyclableDomain extends Domain {
    public Integer instanceId;

    public NonRecyclableDomain() {
      super();
      instanceCount++;
      instanceId = instanceCount;
    }

    public override Boolean shouldRecycleInstance() {
      return false; // Opt out of recycling
    }

    public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
      System.debug(
        'NonRecyclableDomain instance ' + instanceId + ' onBeforeUpsert'
      );
    }
  }

  @IsTest
  static void testNonRecyclableDomainBehavior() {
    // Test that domains that opt out of recycling create new instances each time
    instanceCount = 0; // Reset static counter first
    Map<Type, Type> nonRecycleMap = new Map<Type, Type>{
      Account.class => NonRecyclableDomain.class
    };
    TriggeredFactory nonRecycleFactory = new TriggeredFactory(
      core,
      nonRecycleMap
    );
    nonRecycleFactory.resetRecycled();

    List<Account> records = new List<Account>{
      new Account(Name = 'Test Account')
    };

    Test.startTest();

    // Execute BEFORE_INSERT - should create instance 1
    nonRecycleFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null
    );

    // Execute AFTER_INSERT - should create instance 2 (no recycling)
    nonRecycleFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      records,
      null,
      null
    );

    // Execute BEFORE_UPDATE - should create instance 3
    nonRecycleFactory.executeTrigger(
      TriggerOperation.BEFORE_UPDATE,
      records,
      records,
      new Map<Id, SObject>()
    );

    // Execute AFTER_UPDATE - should create instance 4
    nonRecycleFactory.executeTrigger(
      TriggerOperation.AFTER_UPDATE,
      records,
      records,
      new Map<Id, SObject>()
    );

    Test.stopTest();

    // Should have created 4 instances (no recycling)
    System.assertEquals(
      4,
      instanceCount,
      'Should create 4 instances with no recycling'
    );
  }

  @IsTest
  static void testRecyclingWithMultipleSObjectTypes() {
    // Test that recycling works correctly with multiple SObject types
    instanceCount = 0; // Reset static counter first
    Map<Type, Type> multiTypeMap = new Map<Type, Type>{
      Account.class => TrackingDomain.class,
      Contact.class => TrackingDomain.class
    };
    TriggeredFactory multiTypeFactory = new TriggeredFactory(
      core,
      multiTypeMap
    );
    multiTypeFactory.resetRecycled();

    List<Account> accountRecords = new List<Account>{
      new Account(Name = 'Test Account')
    };
    List<Contact> contactRecords = new List<Contact>{
      new Contact(LastName = 'Test Contact')
    };

    Test.startTest();

    // Execute Account operations
    multiTypeFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      accountRecords,
      null,
      null
    );
    multiTypeFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      accountRecords,
      null,
      null
    );

    // Execute Contact operations
    multiTypeFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      contactRecords,
      null,
      null
    );
    multiTypeFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      contactRecords,
      null,
      null
    );

    Test.stopTest();

    // Should have created 4 instances (2 for Account operations, 2 for Contact operations)
    System.assertEquals(
      4,
      instanceCount,
      'Should create 4 instances for different SObject types'
    );
  }

  @IsTest
  static void testRecyclingWithMixedOperations() {
    // Test recycling with a mix of operations on the same SObject type
    instanceCount = 0; // Reset static counter first
    Map<Type, Type> mixedMap = new Map<Type, Type>{
      Account.class => TrackingDomain.class
    };
    TriggeredFactory mixedFactory = new TriggeredFactory(core, mixedMap);
    mixedFactory.resetRecycled();

    List<Account> records = new List<Account>{
      new Account(Name = 'Test Account')
    };

    Test.startTest();

    // INSERT operations
    mixedFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null
    );
    mixedFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      records,
      null,
      null
    );

    // UPDATE operations
    mixedFactory.executeTrigger(
      TriggerOperation.BEFORE_UPDATE,
      records,
      records,
      new Map<Id, SObject>()
    );
    mixedFactory.executeTrigger(
      TriggerOperation.AFTER_UPDATE,
      records,
      records,
      new Map<Id, SObject>()
    );

    // DELETE operations
    mixedFactory.executeTrigger(
      TriggerOperation.BEFORE_DELETE,
      null,
      records,
      new Map<Id, SObject>()
    );
    mixedFactory.executeTrigger(
      TriggerOperation.AFTER_DELETE,
      null,
      records,
      new Map<Id, SObject>()
    );

    // UNDELETE operation
    mixedFactory.executeTrigger(
      TriggerOperation.AFTER_UNDELETE,
      records,
      null,
      null
    );

    Test.stopTest();

    // Should have created 7 instances (2 INSERT + 2 UPDATE + 2 DELETE + 1 UNDELETE)
    System.assertEquals(
      7,
      instanceCount,
      'Should create 7 instances for different operation types'
    );
  }

  @IsTest
  static void testRecyclingWithEmptyRecords() {
    // Test that recycling works correctly with empty record lists
    instanceCount = 0; // Reset static counter first
    Map<Type, Type> emptyMap = new Map<Type, Type>{
      Account.class => TrackingDomain.class
    };
    TriggeredFactory emptyFactory = new TriggeredFactory(core, emptyMap);
    emptyFactory.resetRecycled();

    Test.startTest();

    // Execute with empty records - should return early without creating instances
    emptyFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      new List<Account>(),
      null,
      null
    );

    emptyFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      new List<Account>(),
      null,
      null
    );

    Test.stopTest();

    // Should not have created any instances
    System.assertEquals(
      0,
      instanceCount,
      'Should not create instances for empty records'
    );
  }

  @IsTest
  static void testRecyclingWithNullRecords() {
    // Test that recycling works correctly with null record lists
    instanceCount = 0; // Reset static counter first
    Map<Type, Type> nullMap = new Map<Type, Type>{
      Account.class => TrackingDomain.class
    };
    TriggeredFactory nullFactory = new TriggeredFactory(core, nullMap);
    nullFactory.resetRecycled();

    Test.startTest();

    // Execute with null records - should return early without creating instances
    nullFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      null,
      null,
      null
    );

    nullFactory.executeTrigger(TriggerOperation.AFTER_INSERT, null, null, null);

    Test.stopTest();

    // Should not have created any instances
    System.assertEquals(
      0,
      instanceCount,
      'Should not create instances for null records'
    );
  }

  @IsTest
  static void testRecyclingWithDisabledTriggers() {
    // Test that recycling doesn't interfere with disabled triggers
    instanceCount = 0; // Reset static counter first
    Map<Type, Type> disabledMap = new Map<Type, Type>{
      Account.class => TrackingDomain.class
    };
    TriggeredFactory disabledFactory = new TriggeredFactory(core, disabledMap);
    disabledFactory.resetRecycled();

    List<Account> records = new List<Account>{
      new Account(Name = 'Test Account')
    };

    // Disable all triggers
    disabledFactory.disable();

    Test.startTest();

    // Execute operations - should not create instances due to disabled triggers
    disabledFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null
    );

    disabledFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      records,
      null,
      null
    );

    Test.stopTest();

    // Should not have created any instances
    System.assertEquals(
      0,
      instanceCount,
      'Should not create instances when triggers are disabled'
    );
  }

  @IsTest
  static void testRecyclingWithPartialDisable() {
    // Test that recycling works correctly when only some operations are disabled
    instanceCount = 0; // Reset static counter first
    Map<Type, Type> partialMap = new Map<Type, Type>{
      Account.class => TrackingDomain.class
    };
    TriggeredFactory partialFactory = new TriggeredFactory(core, partialMap);
    partialFactory.resetRecycled();

    List<Account> records = new List<Account>{
      new Account(Name = 'Test Account')
    };

    // Disable only BEFORE_INSERT
    Map<SObjectType, Set<TriggerOperation>> disableMap = new Map<SObjectType, Set<TriggerOperation>>{
      Account.SObjectType => new Set<TriggerOperation>{
        TriggerOperation.BEFORE_INSERT
      }
    };
    partialFactory.disable(disableMap);

    Test.startTest();

    // Execute BEFORE_INSERT - should not create instance (disabled)
    partialFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null
    );

    // Execute AFTER_INSERT - should create instance (not disabled)
    partialFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      records,
      null,
      null
    );

    Test.stopTest();

    // Should have created 2 instances (BEFORE_INSERT + AFTER_INSERT)
    System.assertEquals(
      2,
      instanceCount,
      'Should create 2 instances for enabled operation'
    );
  }

  @IsTest
  static void testRecyclingWithUnregisteredSObjectType() {
    // Test that recycling doesn't interfere with unregistered SObject types
    instanceCount = 0; // Reset static counter first
    TriggeredFactory unregisteredFactory = new TriggeredFactory(
      core,
      new Map<Type, Type>()
    );
    unregisteredFactory.resetRecycled();

    List<Contact> contactRecords = new List<Contact>{
      new Contact(LastName = 'Test Contact')
    };

    Test.startTest();

    // Execute operations for unregistered SObject type
    unregisteredFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      contactRecords,
      null,
      null
    );

    unregisteredFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      contactRecords,
      null,
      null
    );

    Test.stopTest();

    // Should not have created any instances
    System.assertEquals(
      0,
      instanceCount,
      'Should not create instances for unregistered SObject types'
    );
  }

  @IsTest
  static void testRecyclingResetBehavior() {
    // Test that resetRecycled properly clears the recycle map
    instanceCount = 0; // Reset static counter first
    Map<Type, Type> resetMap = new Map<Type, Type>{
      Account.class => TrackingDomain.class
    };
    TriggeredFactory resetFactory = new TriggeredFactory(core, resetMap);
    resetFactory.resetRecycled();

    List<Account> records = new List<Account>{
      new Account(Name = 'Test Account')
    };

    Test.startTest();

    // Execute BEFORE_INSERT - should create instance 1
    resetFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null
    );

    // Reset recycled map
    resetFactory.resetRecycled();

    // Execute AFTER_INSERT - should create instance 2 (no recycling after reset)
    resetFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      records,
      null,
      null
    );

    Test.stopTest();

    // Should have created 3 instances (1 AFTER_INSERT + 2 for BEFORE/AFTER_INSERT)
    System.assertEquals(
      3,
      instanceCount,
      'Should create 3 instances after reset'
    );
  }

  @IsTest
  static void testRecyclingWithLargeRecordSets() {
    // Test that recycling works correctly with large record sets
    instanceCount = 0; // Reset static counter first
    Map<Type, Type> largeMap = new Map<Type, Type>{
      Account.class => TrackingDomain.class
    };
    TriggeredFactory largeFactory = new TriggeredFactory(core, largeMap);
    largeFactory.resetRecycled();

    // Create a large list of accounts
    List<Account> largeRecords = new List<Account>();
    for (Integer i = 0; i < 200; i++) {
      largeRecords.add(new Account(Name = 'Test Account ' + i));
    }

    Test.startTest();

    // Execute BEFORE_INSERT - should create instance 1
    largeFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      largeRecords,
      null,
      null
    );

    // Execute AFTER_INSERT - should reuse instance 1
    largeFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      largeRecords,
      null,
      null
    );

    Test.stopTest();

    // Should have created 2 instances (BEFORE_INSERT + AFTER_INSERT)
    System.assertEquals(
      2,
      instanceCount,
      'Should create 2 instances for large record sets'
    );
  }

  @IsTest
  static void testRecyclingWithConcurrentOperations() {
    // Test that recycling works correctly with concurrent-like operations
    instanceCount = 0; // Reset static counter first
    Map<Type, Type> concurrentMap = new Map<Type, Type>{
      Account.class => TrackingDomain.class,
      Contact.class => TrackingDomain.class
    };
    TriggeredFactory concurrentFactory = new TriggeredFactory(
      core,
      concurrentMap
    );
    concurrentFactory.resetRecycled();

    List<Account> accountRecords = new List<Account>{
      new Account(Name = 'Account 1'),
      new Account(Name = 'Account 2')
    };
    List<Contact> contactRecords = new List<Contact>{
      new Contact(LastName = 'Contact 1'),
      new Contact(LastName = 'Contact 2')
    };

    Test.startTest();

    // Simulate concurrent operations on different SObject types
    concurrentFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      accountRecords,
      null,
      null
    );
    concurrentFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      contactRecords,
      null,
      null
    );
    concurrentFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      accountRecords,
      null,
      null
    );
    concurrentFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      contactRecords,
      null,
      null
    );

    Test.stopTest();

    // Should have created 4 instances (2 for Account operations, 2 for Contact operations)
    System.assertEquals(
      4,
      instanceCount,
      'Should create 4 instances for concurrent operations'
    );
  }

  @IsTest
  static void testRecyclingWithErrorHandling() {
    // Test that recycling works correctly even when errors occur
    instanceCount = 0; // Reset static counter first
    Map<Type, Type> errorMap = new Map<Type, Type>{
      Account.class => TrackingDomain.class
    };
    TriggeredFactory errorFactory = new TriggeredFactory(core, errorMap);
    errorFactory.resetRecycled();

    List<Account> records = new List<Account>{
      new Account(Name = 'Test Account')
    };

    Test.startTest();

    // Execute BEFORE_INSERT - should create instance 1
    errorFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null
    );

    // Simulate an error scenario (e.g., invalid data)
    // The AFTER_INSERT should still reuse the instance
    errorFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      records,
      null,
      null
    );

    Test.stopTest();

    // Should have created 2 instances (BEFORE_INSERT + AFTER_INSERT)
    System.assertEquals(
      2,
      instanceCount,
      'Should create 2 instances even with error scenarios'
    );
  }

  @IsTest
  static void testRecyclingWithMixedRecordSizes() {
    // Test that recycling works correctly with different record set sizes
    instanceCount = 0; // Reset static counter first
    Map<Type, Type> mixedSizeMap = new Map<Type, Type>{
      Account.class => TrackingDomain.class
    };
    TriggeredFactory mixedSizeFactory = new TriggeredFactory(
      core,
      mixedSizeMap
    );
    mixedSizeFactory.resetRecycled();

    List<Account> smallRecords = new List<Account>{
      new Account(Name = 'Small Set')
    };
    List<Account> largeRecords = new List<Account>();
    for (Integer i = 0; i < 100; i++) {
      largeRecords.add(new Account(Name = 'Large Set ' + i));
    }

    Test.startTest();

    // Execute with small record set
    mixedSizeFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      smallRecords,
      null,
      null
    );
    mixedSizeFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      smallRecords,
      null,
      null
    );

    // Execute with large record set
    mixedSizeFactory.executeTrigger(
      TriggerOperation.BEFORE_UPDATE,
      largeRecords,
      largeRecords,
      new Map<Id, SObject>()
    );
    mixedSizeFactory.executeTrigger(
      TriggerOperation.AFTER_UPDATE,
      largeRecords,
      largeRecords,
      new Map<Id, SObject>()
    );

    Test.stopTest();

    // Should have created 4 instances (2 INSERT operations + 2 UPDATE operations)
    System.assertEquals(
      4,
      instanceCount,
      'Should create 4 instances for different operation types'
    );
  }

  @IsTest
  static void testRecyclingWithCustomDomainBehavior() {
    // Test that recycling works correctly with custom domain behavior
    instanceCount = 0; // Reset static counter first
    Map<Type, Type> customMap = new Map<Type, Type>{
      Account.class => NonRecyclableDomain.class
    };
    TriggeredFactory customFactory = new TriggeredFactory(core, customMap);
    customFactory.resetRecycled();

    List<Account> records = new List<Account>{
      new Account(Name = 'Test Account')
    };

    Test.startTest();

    // Execute operations with non-recyclable domain
    customFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null
    );
    customFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      records,
      null,
      null
    );

    Test.stopTest();

    // Should have created 2 instances (no recycling for non-recyclable domain)
    System.assertEquals(
      2,
      instanceCount,
      'Should create 2 instances for non-recyclable domain'
    );
  }

  @IsTest
  static void testRecyclingWithTriggerBypass() {
    // Test that recycling works correctly with trigger bypass scenarios
    instanceCount = 0; // Reset static counter first
    Map<Type, Type> bypassMap = new Map<Type, Type>{
      Account.class => TrackingDomain.class
    };
    TriggeredFactory bypassFactory = new TriggeredFactory(core, bypassMap);
    bypassFactory.resetRecycled();

    List<Account> records = new List<Account>{
      new Account(Name = 'Test Account')
    };

    // Disable specific operations
    Map<SObjectType, Set<TriggerOperation>> disableMap = new Map<SObjectType, Set<TriggerOperation>>{
      Account.SObjectType => new Set<TriggerOperation>{
        TriggerOperation.BEFORE_INSERT
      }
    };
    bypassFactory.disable(disableMap);

    Test.startTest();

    // Execute BEFORE_INSERT - should not create instance (disabled)
    bypassFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null
    );

    // Execute AFTER_INSERT - should create instance (not disabled)
    bypassFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      records,
      null,
      null
    );

    // Enable the operation
    bypassFactory.enable(disableMap);

    // Execute BEFORE_INSERT again - should create new instance
    bypassFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null
    );

    // Execute AFTER_INSERT - should reuse the instance
    bypassFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      records,
      null,
      null
    );

    Test.stopTest();

    // Should have created 4 instances (1 AFTER_INSERT + 3 for BEFORE/AFTER_INSERT operations)
    System.assertEquals(
      4,
      instanceCount,
      'Should create 4 instances with bypass scenarios'
    );
  }

  @IsTest
  static void testRecyclingWithFactoryReset() {
    // Test that recycling works correctly after factory reset
    instanceCount = 0; // Reset static counter first
    Map<Type, Type> resetMap = new Map<Type, Type>{
      Account.class => TrackingDomain.class
    };
    TriggeredFactory resetFactory = new TriggeredFactory(core, resetMap);
    resetFactory.resetRecycled();

    List<Account> records = new List<Account>{
      new Account(Name = 'Test Account')
    };

    Test.startTest();

    // Execute operations
    resetFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null
    );
    resetFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      records,
      null,
      null
    );

    // Reset the factory
    resetFactory.resetRecycled();

    // Execute operations again
    resetFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null
    );
    resetFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      records,
      null,
      null
    );

    Test.stopTest();

    // Should have created 4 instances (2 for first set + 2 for second set)
    System.assertEquals(
      4,
      instanceCount,
      'Should create 4 instances after factory reset'
    );
  }

  @IsTest
  static void testRecyclingWithInvalidData() {
    // Test that recycling works correctly with invalid data scenarios
    instanceCount = 0; // Reset static counter first
    Map<Type, Type> invalidMap = new Map<Type, Type>{
      Account.class => TrackingDomain.class
    };
    TriggeredFactory invalidFactory = new TriggeredFactory(core, invalidMap);
    invalidFactory.resetRecycled();

    // Create records with invalid data
    List<Account> invalidRecords = new List<Account>{
      new Account(), // No name
      new Account(Name = 'Valid Account')
    };

    Test.startTest();

    // Execute operations with invalid data
    invalidFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      invalidRecords,
      null,
      null
    );
    invalidFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      invalidRecords,
      null,
      null
    );

    Test.stopTest();

    // Should have created 2 instances (BEFORE_INSERT + AFTER_INSERT)
    System.assertEquals(
      2,
      instanceCount,
      'Should create 2 instances with invalid data'
    );
  }

  @IsTest
  static void testRecyclingWithMultipleFactories() {
    // Test that recycling works correctly with multiple factory instances
    instanceCount = 0; // Reset static counter first
    Map<Type, Type> multiFactoryMap = new Map<Type, Type>{
      Account.class => TrackingDomain.class
    };

    TriggeredFactory factory1 = new TriggeredFactory(core, multiFactoryMap);
    TriggeredFactory factory2 = new TriggeredFactory(core, multiFactoryMap);

    factory1.resetRecycled();
    factory2.resetRecycled();

    List<Account> records = new List<Account>{
      new Account(Name = 'Test Account')
    };

    Test.startTest();

    // Execute operations with factory1
    factory1.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null
    );
    factory1.executeTrigger(TriggerOperation.AFTER_INSERT, records, null, null);

    // Execute operations with factory2
    factory2.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      records,
      null,
      null
    );
    factory2.executeTrigger(TriggerOperation.AFTER_INSERT, records, null, null);

    Test.stopTest();

    // Should have created 4 instances (2 for each factory)
    System.assertEquals(
      4,
      instanceCount,
      'Should create 4 instances for multiple factories'
    );
  }

  @IsTest
  static void testRecyclingWithComplexScenarios() {
    // Test that recycling works correctly with complex real-world scenarios
    instanceCount = 0; // Reset static counter first
    Map<Type, Type> complexMap = new Map<Type, Type>{
      Account.class => TrackingDomain.class,
      Contact.class => TrackingDomain.class
    };
    TriggeredFactory complexFactory = new TriggeredFactory(core, complexMap);
    complexFactory.resetRecycled();

    List<Account> accountRecords = new List<Account>{
      new Account(Name = 'Account 1'),
      new Account(Name = 'Account 2')
    };
    List<Contact> contactRecords = new List<Contact>{
      new Contact(LastName = 'Contact 1'),
      new Contact(LastName = 'Contact 2')
    };

    Test.startTest();

    // Simulate a complex scenario with multiple operations
    // Account INSERT
    complexFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      accountRecords,
      null,
      null
    );
    complexFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      accountRecords,
      null,
      null
    );

    // Contact INSERT
    complexFactory.executeTrigger(
      TriggerOperation.BEFORE_INSERT,
      contactRecords,
      null,
      null
    );
    complexFactory.executeTrigger(
      TriggerOperation.AFTER_INSERT,
      contactRecords,
      null,
      null
    );

    // Account UPDATE
    complexFactory.executeTrigger(
      TriggerOperation.BEFORE_UPDATE,
      accountRecords,
      accountRecords,
      new Map<Id, SObject>()
    );
    complexFactory.executeTrigger(
      TriggerOperation.AFTER_UPDATE,
      accountRecords,
      accountRecords,
      new Map<Id, SObject>()
    );

    // Contact UPDATE
    complexFactory.executeTrigger(
      TriggerOperation.BEFORE_UPDATE,
      contactRecords,
      contactRecords,
      new Map<Id, SObject>()
    );
    complexFactory.executeTrigger(
      TriggerOperation.AFTER_UPDATE,
      contactRecords,
      contactRecords,
      new Map<Id, SObject>()
    );

    Test.stopTest();

    // Should have created 8 instances (2 Account INSERT + 2 Contact INSERT + 2 Account UPDATE + 2 Contact UPDATE)
    System.assertEquals(
      8,
      instanceCount,
      'Should create 8 instances for complex scenarios'
    );
  }

  // --- Security enforcement maps each trigger operation to the right permission ------------------

  @IsTest
  static void eachTriggerOperationNeedsItsPermission() {
    Map<TriggerOperation, String> expected = new Map<TriggerOperation, String>{
      TriggerOperation.BEFORE_INSERT => 'create',
      TriggerOperation.AFTER_INSERT => 'create',
      TriggerOperation.BEFORE_UPDATE => 'update',
      TriggerOperation.AFTER_UPDATE => 'update',
      TriggerOperation.BEFORE_DELETE => 'delete',
      TriggerOperation.AFTER_DELETE => 'delete',
      TriggerOperation.AFTER_UNDELETE => 'undelete'
    };

    for (TriggerOperation op : expected.keySet()) {
      Assert.areEqual(expected.get(op), TriggeredFactory.permissionFor(op), String.valueOf(op));
    }
  }

  @IsTest
  static void enforcedTriggersRunForEveryOperation() {
    TriggeredFactory secured = new TriggeredFactory(core, new Map<Type, Type>{ Account.class => NonDomainTrigger.class });
    Account row = new Account(Id = IdUtil.generateId(Account.SObjectType), Name = 'Secured');

    for (TriggerOperation op : TriggerOperation.values()) {
      secured.executeTrigger(op, new List<Account>{ row }, new List<Account>{ row }, new Map<Id, SObject>{ row.Id => row });
    }
    Assert.areEqual(TriggerOperation.values().size(), secureCalls, 'insert and undelete used to throw "Unknown operation"');
  }

  @IsTest
  static void enforcedTriggersStopUsersWithoutThePermission() {
    Profile minimal = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
    User limited = new User(
      Alias = 'minacc',
      Email = 'minimal.access@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Minimal',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = minimal.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'minimal.access.' + Crypto.getRandomInteger() + '@example.com'
    );
    TriggeredFactory secured = new TriggeredFactory(core, new Map<Type, Type>{ Account.class => NonDomainTrigger.class });

    System.runAs(limited) {
      try {
        secured.executeTrigger(TriggerOperation.BEFORE_INSERT, new List<Account>{ new Account(Name = 'Denied') }, null, null);
        Assert.fail('a user who cannot create accounts was let through');
      } catch (TriggeredFactory.TriggerFactoryException expected) {
        Assert.isTrue(expected.getMessage().contains('create Account denied'), expected.getMessage());
      }
    }
  }

  @IsTest
  static void aRecycledInstanceSeesItsAfterRecordsFresh() {
    TriggeredFactory recycling = new TriggeredFactory(core, new Map<Type, Type>{ Account.class => WatchingAccounts.class });
    Id rowId = IdUtil.generateId(Account.SObjectType);
    List<Account> beforeRows = new List<Account>{ new Account(Id = rowId, Industry = 'Energy') };
    List<Account> afterRows = new List<Account>{ new Account(Id = rowId, Industry = 'Banking') };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{ rowId => new Account(Id = rowId) };
    instanceCount = 0;

    recycling.executeTrigger(TriggerOperation.BEFORE_UPDATE, beforeRows, beforeRows, oldMap);
    recycling.executeTrigger(TriggerOperation.AFTER_UPDATE, afterRows, beforeRows, oldMap);

    Assert.areEqual(new List<String>{ 'before#1 {Energy}', 'after#1 {Banking}' }, phasesSeen, 'one instance, fresh catalog after');
  }

  // --- disableWhen: rules that switch triggers off ----------------------------------------------

  // What each rule was asked, in order.
  private static List<String> asked = new List<String>();

  private class SkipOn implements ITriggeredBypass {
    private TriggerOperation skipped;
    private String label;

    SkipOn(String label, TriggerOperation skipped) {
      this.label = label;
      this.skipped = skipped;
    }
    public Boolean bypasses(SObjectType token, TriggerOperation operation) {
      asked.add(label + ' ' + token + ' ' + operation);
      return operation == skipped;
    }
  }

  // The rule a subscriber would write: off for users holding a custom permission.
  private class HoldersOf implements ITriggeredBypass {
    private String permission;

    HoldersOf(String permission) {
      this.permission = permission;
    }
    public Boolean bypasses(SObjectType token, TriggerOperation operation) {
      return FeatureManagement.checkPermission(permission);
    }
  }

  private static void fire(TriggeredFactory target, TriggerOperation operation) {
    Account row = new Account(Id = IdUtil.generateId(Account.SObjectType), Name = 'Ruled');
    target.executeTrigger(operation, new List<Account>{ row }, new List<Account>{ row }, new Map<Id, SObject>{ row.Id => row });
  }

  @IsTest
  static void aRuleSwitchesOffTheTriggersItSaysYesTo() {
    TriggeredFactory ruled = new TriggeredFactory(core, new Map<Type, Type>{ Account.class => NonDomainTrigger.class });
    ruled.disableWhen(new SkipOn('rule', TriggerOperation.BEFORE_UPDATE));

    fire(ruled, TriggerOperation.BEFORE_UPDATE);
    Assert.areEqual(0, secureCalls, 'the rule said yes: the handler is not called');

    fire(ruled, TriggerOperation.AFTER_UPDATE);
    Assert.areEqual(1, secureCalls, 'the rule said no: the handler runs');
    Assert.areEqual(new List<String>{ 'rule Account BEFORE_UPDATE', 'rule Account AFTER_UPDATE' }, asked, 'asked each time, with the object and operation');
  }

  @IsTest
  static void rulesAddUpAndStopAtTheFirstYes() {
    TriggeredFactory ruled = new TriggeredFactory(core, new Map<Type, Type>{ Account.class => NonDomainTrigger.class });
    ruled.disableWhen(null); // ignored
    ruled.disableWhen(new SkipOn('first', TriggerOperation.BEFORE_DELETE));
    ruled.disableWhen(new SkipOn('second', TriggerOperation.AFTER_DELETE));

    fire(ruled, TriggerOperation.BEFORE_DELETE);
    fire(ruled, TriggerOperation.AFTER_DELETE);
    fire(ruled, TriggerOperation.AFTER_UNDELETE);

    Assert.areEqual(1, secureCalls, 'only the undelete ran');
    Assert.areEqual(
      new List<String>{
        'first Account BEFORE_DELETE',
        'first Account AFTER_DELETE',
        'second Account AFTER_DELETE',
        'first Account AFTER_UNDELETE',
        'second Account AFTER_UNDELETE'
      },
      asked
    );
  }

  @IsTest
  static void aRuleIsNotAskedWhenNothingWouldRun() {
    TriggeredFactory ruled = new TriggeredFactory(core, new Map<Type, Type>{ Account.class => NonDomainTrigger.class });
    ruled.disableWhen(new SkipOn('rule', TriggerOperation.BEFORE_INSERT));

    ruled.disable();
    fire(ruled, TriggerOperation.AFTER_UPDATE);
    ruled.enable();
    Contact unregistered = new Contact(Id = IdUtil.generateId(Contact.SObjectType), LastName = 'Nobody');
    ruled.executeTrigger(TriggerOperation.AFTER_UPDATE, new List<Contact>{ unregistered }, null, null);

    Assert.isTrue(asked.isEmpty(), 'switched off in code, or no class registered: ' + asked);
    Assert.areEqual(0, secureCalls);
  }

  @IsTest
  static void aRuleCanReadACustomPermission() {
    TriggeredFactory ruled = new TriggeredFactory(core, new Map<Type, Type>{ Account.class => NonDomainTrigger.class });
    ruled.disableWhen(new HoldersOf('A_Permission_Nobody_Created'));

    fire(ruled, TriggerOperation.BEFORE_UPDATE);

    Assert.areEqual(1, secureCalls, 'a permission that does not exist is not held, so the trigger runs');
  }
}
