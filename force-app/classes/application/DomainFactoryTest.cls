@IsTest
private class DomainFactoryTest {
  // Faux domain for testing state and config
  private class FauxAccounts extends DomainRecords {
    public Boolean domainInitialized = false;
    public List<SObject> domainRecords = new List<SObject>();
    public IModel domainSource = null;

    public override void init(IModel source, List<SObject> records) {
      domainInitialized = true;
      domainSource = source;
      domainRecords = records;
      super.init(source, records);
    }
  }

  // BaseDomain test implementation
  private class BaseAccountDomain extends BaseDomain {
    public Integer onInitializedCallCount = 0;
    public IModel initializedSource = null;
    public List<SObject> initializedRecords = null;

    public override void onInitialized(IModel source, List<SObject> records) {
      onInitializedCallCount++;
      initializedSource = source;
      initializedRecords = records;
    }
  }

  // Static domain map and factory
  private static final Map<Type, Type> domainMap = new Map<Type, Type>{
    Account.class => FauxAccounts.class
  };
  static final Core core = new Core(new SchemeDefault());
  static final DomainFactory factory = new DomainFactory(core, domainMap);

  @IsTest
  static void testMakeWithTokenAndRecords() {
    System.assert(
      factory.getRegistry().containsKey(Account.class),
      'Should be registered'
    );
    List<Account> testRecords = new List<Account>{
      new Account(Name = 'Test Account')
    };
    IDomain domain = factory.make(Account.SObjectType, testRecords);
    System.assertNotEquals(null, domain, 'Domain instance should not be null');
    System.assert(domain instanceof FauxAccounts, 'Should be FauxAccounts');
  }

  @IsTest
  static void testMakeWithRecords() {
    List<Account> testAccounts = new List<Account>{
      new Account(Name = 'Test1'),
      new Account(Name = 'Test2')
    };
    IDomain domain = factory.make(testAccounts);
    System.assertNotEquals(
      null,
      domain,
      'Domain should be created from records'
    );
    System.assert(domain instanceof FauxAccounts, 'Should be FauxAccounts');
  }

  @IsTest
  static void testInitAndState() {
    // Test domain initialization and state tracking
    FauxAccounts domain = new FauxAccounts();
    System.assertEquals(
      false,
      domain.domainInitialized,
      'Should not be initialized initially'
    );

    List<Account> testRecords = new List<Account>{
      new Account(Name = 'Test Account')
    };
    IModel testModel = null; // Mock model would be used here

    Test.startTest();
    domain.init(testModel, testRecords);
    Test.stopTest();

    System.assertEquals(
      true,
      domain.domainInitialized,
      'Should be initialized'
    );
    System.assertEquals(
      testRecords.size(),
      domain.records().size(),
      'Should have correct record count'
    );
  }

  @IsTest
  static void testToMap() {
    FauxAccounts domain = new FauxAccounts();
    List<Account> testRecords = new List<Account>{
      new Account(Name = 'Test Account')
    };
    domain.init(null, testRecords);

    Map<Id, SObject> recordMap = domain.toMap();
    System.assertNotEquals(null, recordMap, 'Should return map');
    // Note: Map will be empty since test records don't have IDs
  }

  @IsTest
  static void testConstructorWithMap() {
    Map<Type, Type> customDomainMap = new Map<Type, Type>{
      Account.class => FauxAccounts.class
    };
    DomainFactory customFactory = new DomainFactory(core, customDomainMap);
    System.assert(
      customFactory.getRegistry().containsKey(Account.class),
      'Should be registered from constructor'
    );
  }

  @IsTest
  static void testMakeUnregistered() {
    // Test fallback behavior - should return base Domain instance
    IDomain domain = factory.make(Contact.SObjectType);
    System.assertNotEquals(
      null,
      domain,
      'Should return base Domain for unregistered type'
    );
    System.assert(domain instanceof DomainRecords, 'Should be base Domain class');
  }

  @IsTest
  static void testMakeWithSObjectType() {
    // Test make with SObjectType token
    IDomain domain = factory.make(Account.SObjectType);
    System.assertNotEquals(
      null,
      domain,
      'Domain should be created from SObjectType'
    );
    System.assert(domain instanceof FauxAccounts, 'Should be FauxAccounts');
  }

  @IsTest
  static void testConstructorWithoutMap() {
    // Test constructor without map parameter
    DomainFactory simpleFactory = new DomainFactory(core);
    System.assertNotEquals(null, simpleFactory, 'Factory should be created');
    System.assertNotEquals(
      null,
      simpleFactory.getRegistry(),
      'Registry should be initialized'
    );
  }

  @IsTest
  static void testRegisteredDomainUsed() {
    // Test that registered domains are used when available
    DomainFactory testFactory = new DomainFactory(core, domainMap);
    IDomain domain = testFactory.make(Account.SObjectType);
    System.assert(
      domain instanceof FauxAccounts,
      'Registered domain class should be used'
    );

    // Test fallback when not registered
    IDomain contactDomain = testFactory.make(Contact.SObjectType);
    System.assert(
      contactDomain instanceof DomainRecords,
      'Should fall back to base Domain'
    );
    System.assert(
      !(contactDomain instanceof FauxAccounts),
      'Should not be FauxAccounts'
    );
  }

  @IsTest
  static void testMakeWithToken() {
    // Test make with just SObjectType (no records)
    IDomain domain = factory.make(Account.SObjectType);
    System.assertNotEquals(null, domain, 'Domain should be created from token');
    System.assert(domain instanceof FauxAccounts, 'Should be FauxAccounts');
  }

  // BaseDomain Tests

  @IsTest
  static void testBaseDomainInitialization() {
    // Test that BaseDomain onInitialized() hook is called by factory
    Map<Type, Type> baseDomainMap = new Map<Type, Type>{
      Account.class => BaseAccountDomain.class
    };
    DomainFactory baseFactory = new DomainFactory(core, baseDomainMap);

    List<Account> testRecords = new List<Account>{
      new Account(Name = 'Test Account')
    };

    Test.startTest();
    IDomain domain = baseFactory.make(Account.SObjectType, testRecords);
    Test.stopTest();

    System.assert(
      domain instanceof BaseAccountDomain,
      'Should be BaseAccountDomain'
    );
    BaseAccountDomain baseDomain = (BaseAccountDomain) domain;
    System.assertEquals(
      1,
      baseDomain.onInitializedCallCount,
      'onInitialized should be called once'
    );
    System.assertNotEquals(
      null,
      baseDomain.initializedSource,
      'Should have source'
    );
    System.assertEquals(
      testRecords.size(),
      baseDomain.initializedRecords.size(),
      'Should have correct records'
    );
  }

  @IsTest
  static void testBaseDomainTemplateMethodEnforcement() {
    // Verify that base initialization runs before onInitialized
    Map<Type, Type> baseDomainMap = new Map<Type, Type>{
      Account.class => BaseAccountDomain.class
    };
    DomainFactory baseFactory = new DomainFactory(core, baseDomainMap);

    List<Account> testRecords = new List<Account>{
      new Account(Name = 'Test Account')
    };

    Test.startTest();
    BaseAccountDomain domain = (BaseAccountDomain) baseFactory.make(
      Account.SObjectType,
      testRecords
    );
    Test.stopTest();

    // Verify initialization happened in correct order
    System.assert(
      domain.isInitialized(),
      'Base initialization should be complete'
    );
    System.assertEquals(
      1,
      domain.onInitializedCallCount,
      'onInitialized should be called'
    );
    System.assertNotEquals(
      null,
      domain.source(),
      'Source should be set by base init'
    );
  }

  @IsTest
  static void testBaseDomainWithEmptyRecords() {
    // Test that BaseDomain works with empty records list
    Map<Type, Type> baseDomainMap = new Map<Type, Type>{
      Account.class => BaseAccountDomain.class
    };
    DomainFactory baseFactory = new DomainFactory(core, baseDomainMap);

    Test.startTest();
    BaseAccountDomain domain = (BaseAccountDomain) baseFactory.make(
      Account.SObjectType
    );
    Test.stopTest();

    System.assertEquals(
      1,
      domain.onInitializedCallCount,
      'onInitialized should be called even with empty records'
    );
    System.assertEquals(
      0,
      domain.records().size(),
      'Should have empty records list'
    );
  }

  @IsTest
  static void testBaseDomainAccessViaBaseMethod() {
    // Test that base() method provides IDomain access
    Map<Type, Type> baseDomainMap = new Map<Type, Type>{
      Account.class => BaseAccountDomain.class
    };
    DomainFactory baseFactory = new DomainFactory(core, baseDomainMap);

    List<Account> testRecords = new List<Account>{
      new Account(Name = 'Test 1'),
      new Account(Name = 'Test 2')
    };

    Test.startTest();
    BaseAccountDomain domain = (BaseAccountDomain) baseFactory.make(
      Account.SObjectType,
      testRecords
    );
    IDomain baseDomain = domain.base();
    Test.stopTest();

    System.assertNotEquals(null, baseDomain, 'base() should return IDomain');
    System.assertEquals(
      2,
      baseDomain.records().size(),
      'Should have correct record count'
    );
    System.assertNotEquals(
      null,
      baseDomain.source(),
      'Should have correct source'
    );
  }

  @IsTest
  static void testMakeWithNullRecordsList() {
    // Test that null records list returns null instead of throwing
    IDomain domain = factory.make((List<SObject>) null);
    System.assertEquals(
      null,
      domain,
      'Should return null for null records list'
    );
  }

  @IsTest
  static void testMakeWithEmptyRecordsList() {
    // Test that empty records list returns null (can't determine SObjectType from empty list)
    List<Account> emptyList = new List<Account>();
    IDomain domain = factory.make(emptyList);
    System.assertEquals(
      null,
      domain,
      'Should return null for empty records list (cannot determine SObjectType)'
    );
  }

  @IsTest
  static void testMakeWithNullSObjectType() {
    // Test that make(SObjectType, records) with null token returns null
    List<Account> testRecords = new List<Account>{ new Account(Name = 'Test') };
    IDomain domain = factory.make((SObjectType) null, testRecords);
    System.assertEquals(
      null,
      domain,
      'Should return null when SObjectType is null'
    );
  }

  @IsTest
  static void testMakeWithNullSObjectTypeAndNullRecords() {
    // Test that make(SObjectType, records) with both null returns null
    IDomain domain = factory.make((SObjectType) null, null);
    System.assertEquals(
      null,
      domain,
      'Should return null when both SObjectType and records are null'
    );
  }

  @IsTest
  static void testMakeWithNullObjectName() {
    // Test that make(String name) with null throws exception
    Test.startTest();
    try {
      factory.make((String) null);
      System.assert(false, 'Should throw exception for null object name');
    } catch (DomainFactory.DomainFactoryException e) {
      System.assert(
        e.getMessage().contains('Object name cannot be null'),
        'Should throw exception with appropriate message'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testMakeWithRecordsUnableToDetermineType() {
    // Test make(records) when records can't determine SObjectType
    List<SObject> genericList = new List<SObject>();
    // Add a non-typed record that might not have a determinable SObjectType
    // This is a difficult case to create in Apex, but we can test the null path

    Test.startTest();
    IDomain domain = factory.make(genericList);
    Test.stopTest();

    System.assertEquals(
      null,
      domain,
      'Should return null when unable to determine SObjectType from records'
    );
  }

  @IsTest
  static void testMakeWithRecordsFromMixedTypes() {
    // Test make(records) when we have a properly typed list
    List<SObject> testRecords = new List<SObject>();
    Account acc = new Account(Name = 'Test Account');
    testRecords.add(acc);

    Test.startTest();
    IDomain domain = factory.make(testRecords);
    Test.stopTest();

    System.assertNotEquals(
      null,
      domain,
      'Should create domain from typed records'
    );
    System.assert(
      domain instanceof FauxAccounts,
      'Should be FauxAccounts type'
    );
  }

  @IsTest
  static void testMakeWithRecordsListSingleElement() {
    // Test that make(records) works with a single record
    // This tests the fallback logic: token = records[0].getSObjectType()
    List<SObject> singleRecord = new List<SObject>{
      new Account(Name = 'Single Account')
    };

    Test.startTest();
    IDomain domain = factory.make(singleRecord);
    Test.stopTest();

    System.assertNotEquals(
      null,
      domain,
      'Should create domain from single record'
    );
    System.assert(
      domain instanceof FauxAccounts,
      'Should be FauxAccounts for Account record'
    );
    System.assertEquals(
      1,
      domain.records().size(),
      'Should have exactly one record'
    );
  }

  @IsTest
  static void testIsValidPairBehaviorWithNullKey() {
    // Test that factory throws exception for null keys in registry
    Map<Type, Type> registryWithNullKey = new Map<Type, Type>{
      Account.class => FauxAccounts.class,
      null => FauxAccounts.class // null key - should throw exception
    };

    Test.startTest();
    try {
      DomainFactory testFactory = new DomainFactory(core, registryWithNullKey);
      System.assert(false, 'Should throw exception for null key in registry');
    } catch (Application.FactoryException e) {
      System.assert(
        e.getMessage().contains('Invalid pairing'),
        'Should mention invalid pairing: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testIsValidPairBehaviorWithNullValue() {
    // Test that factory handles null values in registry (filters them out)
    Map<Type, Type> registryWithNullValue = new Map<Type, Type>{
      Account.class => FauxAccounts.class,
      Contact.class => null // null value - should be filtered
    };

    Test.startTest();
    DomainFactory testFactory = new DomainFactory(core, registryWithNullValue);
    Test.stopTest();

    // The factory should filter out null value entries
    System.assertNotEquals(null, testFactory, 'Factory should be created');
    System.assertNotEquals(
      null,
      testFactory.getRegistry(),
      'Registry should exist'
    );
  }

  @IsTest
  static void testMakeWithTokenReturnsNewInstance() {
    // Test that each call to make() returns a new domain instance
    Test.startTest();
    IDomain domain1 = factory.make(Account.SObjectType);
    IDomain domain2 = factory.make(Account.SObjectType);
    Test.stopTest();

    System.assertNotEquals(null, domain1, 'First domain should be created');
    System.assertNotEquals(null, domain2, 'Second domain should be created');
    System.assert(domain1 !== domain2, 'Should create new instances each time');
  }

  @IsTest
  static void testMakeWithRecordsAndTokenConsistency() {
    // Test that make(token, records) produces same result as make(records)
    List<Account> testRecords = new List<Account>{
      new Account(Name = 'Test 1'),
      new Account(Name = 'Test 2')
    };

    Test.startTest();
    IDomain domain1 = factory.make(Account.SObjectType, testRecords);
    IDomain domain2 = factory.make(testRecords);
    Test.stopTest();

    System.assertNotEquals(null, domain1, 'Domain from token should exist');
    System.assertNotEquals(null, domain2, 'Domain from records should exist');
    System.assert(
      domain1 instanceof FauxAccounts,
      'Domain from token should be FauxAccounts'
    );
    System.assert(
      domain2 instanceof FauxAccounts,
      'Domain from records should be FauxAccounts'
    );
    System.assertEquals(
      domain1.records().size(),
      domain2.records().size(),
      'Both should have same number of records'
    );
  }

  @IsTest
  static void testBaseDomainOnInitializedCalledViaFactory() {
    // Verify that factory properly calls BaseDomain init which triggers onInitialized
    Map<Type, Type> baseDomainRegistry = new Map<Type, Type>{
      Contact.class => BaseAccountDomain.class
    };
    DomainFactory baseFactory = new DomainFactory(core, baseDomainRegistry);

    List<Contact> contacts = new List<Contact>{
      new Contact(LastName = 'Test')
    };

    Test.startTest();
    IDomain domain = baseFactory.make(contacts);
    Test.stopTest();

    System.assert(
      domain instanceof BaseAccountDomain,
      'Should be BaseAccountDomain'
    );
    BaseAccountDomain baseDomain = (BaseAccountDomain) domain;
    System.assertEquals(
      1,
      baseDomain.onInitializedCallCount,
      'Factory should trigger onInitialized hook'
    );
  }
}
