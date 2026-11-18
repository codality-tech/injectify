@IsTest
public class DomainRecordsTest {
  // Test domain class that extends Domain
  public class TestDomain extends DomainRecords {
    public Boolean onBeforeInsertCalled = false;
    public Boolean onAfterInsertCalled = false;
    public Boolean onBeforeUpdateCalled = false;
    public Boolean onAfterUpdateCalled = false;
    public Boolean onBeforeDeleteCalled = false;
    public Boolean onAfterDeleteCalled = false;
    public Boolean onAfterUndeleteCalled = false;

    public TestDomain() {
      super();
    }

    public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
      if (oldMap == null) {
        onBeforeInsertCalled = true;
      } else {
        onBeforeUpdateCalled = true;
      }
    }

    public override void onAfterUpsert(Map<Id, SObject> oldMap) {
      if (oldMap == null) {
        onAfterInsertCalled = true;
      } else {
        onAfterUpdateCalled = true;
      }
    }

    public override void onBeforeDelete() {
      onBeforeDeleteCalled = true;
    }

    public override void onAfterDelete() {
      onAfterDeleteCalled = true;
    }

    public override void onAfterUndelete() {
      onAfterUndeleteCalled = true;
    }
  }

  @TestSetup
  static void setup() {
    // Create test data
    List<Account> accounts = new List<Account>{
      new Account(Name = 'Test Account 1', Industry = 'Technology'),
      new Account(Name = 'Test Account 2', Industry = 'Healthcare'),
      new Account(Name = 'Test Account 3', Industry = 'Technology')
    };
    insert accounts;
  }

  @IsTest
  static void testConstructors() {
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 2];

    // Test constructor with records
    DomainRecords domain3 = new DomainRecords(null, accounts);
    System.assertEquals(
      2,
      domain3.records().size(),
      'Domain should have 2 records after constructor with records'
    );

    // Test init method
    DomainRecords domain1 = new DomainRecords(null, accounts);
    System.assertEquals(
      2,
      domain1.records().size(),
      'Domain should have 2 records after init'
    );

    DomainRecords domain2 = new DomainRecords(
      Application.s.model(Account.sobjecttype),
      new List<Account>{ accounts[0] }
    );
    System.assertEquals(
      1,
      domain2.records().size(),
      'Domain should have 1 record after init'
    );
  }

  @IsTest
  static void testBasicDomainOperations() {
    List<Account> accounts = [
      SELECT Id, Name, Industry, OwnerId
      FROM Account
      LIMIT 3
    ];
    DomainRecords domain = new DomainRecords();
    domain.init(null, accounts);

    // Test size
    System.assertEquals(3, domain.records().size(), 'Size should be 3');

    // Test records method
    List<SObject> allRecords = domain.records();
    System.assertEquals(3, allRecords.size(), 'Should return all records');

    // Test toMap method
    Map<Id, SObject> recordMap = domain.toMap();
    System.assertEquals(
      3,
      recordMap.size(),
      'Should return map with 3 records'
    );
    System.assert(
      recordMap.containsKey(accounts[0].Id),
      'Should contain first account'
    );
    System.assert(
      recordMap.containsKey(accounts[1].Id),
      'Should contain second account'
    );
    System.assert(
      recordMap.containsKey(accounts[2].Id),
      'Should contain third account'
    );

    // Test source method
    IModel source = domain.source();
    System.assert(source != null, 'Source should not be null');
    System.assertEquals(
      'Account',
      source.name(),
      'Source name should be Account'
    );
  }

  @IsTest
  static void testFiltering() {
    List<Account> accounts = [
      SELECT Id, Name, Industry, OwnerId
      FROM Account
      LIMIT 3
    ];
    DomainRecords domain = new DomainRecords();
    domain.init(null, accounts);

    // Test filter with condition
    ICondition condition = Application.s.eq('Industry', 'Technology');
    List<SObject> techAccounts = domain.filter(condition);
    System.assertEquals(
      2,
      techAccounts.size(),
      'Should filter to 2 technology accounts'
    );

    // Test filter with different condition
    ICondition healthcareCondition = Application.s.eq('Industry', 'Healthcare');
    List<SObject> healthcareAccounts = domain.filter(healthcareCondition);
    System.assertEquals(
      1,
      healthcareAccounts.size(),
      'Should filter to 1 healthcare account'
    );
  }

  @IsTest
  static void testSorting() {
    List<Account> accounts = [
      SELECT Id, Name, Industry, OwnerId
      FROM Account
      LIMIT 3
    ];
    DomainRecords domain = new DomainRecords();
    domain.init(null, accounts);

    // Test sort with ordering
    IOrdering ordering = Application.s.ordering('Name', true);
    List<SObject> sortedByName = domain.sort(ordering);
    System.assertEquals(
      3,
      sortedByName.size(),
      'Should return 3 sorted records'
    );

    // Test sort with descending ordering
    IOrdering descOrdering = Application.s.ordering('Name', false);
    List<SObject> sortedByNameDesc = domain.sort(descOrdering);
    System.assertEquals(
      3,
      sortedByNameDesc.size(),
      'Should return 3 sorted records'
    );
  }

  @IsTest
  static void testGetChangedRecords() {
    List<Account> accounts = [
      SELECT Id, Name, Industry, OwnerId
      FROM Account
      LIMIT 3
    ];
    DomainRecords domain = new DomainRecords();
    domain.init(null, accounts);

    // Test with null existing records (should return all records)
    List<SObject> changedRecords = domain.getChangedRecords(
      null,
      new Set<String>{ 'Name' }
    );
    System.assertEquals(
      3,
      changedRecords.size(),
      'Should return all records when no existing records'
    );

    // Test with empty existing records (should return all records)
    changedRecords = domain.getChangedRecords(
      new Map<Id, SObject>(),
      new Set<String>{ 'Name' }
    );
    System.assertEquals(
      3,
      changedRecords.size(),
      'Should return all records when existing records is empty'
    );

    // Test with existing records but no changes
    Map<Id, SObject> existingRecords = new Map<Id, SObject>(accounts);
    changedRecords = domain.getChangedRecords(
      existingRecords,
      new Set<String>{ 'Name' }
    );
    System.assertEquals(
      0,
      changedRecords.size(),
      'Should return no records when no changes'
    );

    // Test with field tokens
    Set<SObjectField> fieldTokens = new Set<SObjectField>{ Account.Name };
    changedRecords = domain.getChangedRecords(existingRecords, fieldTokens);
    System.assertEquals(
      0,
      changedRecords.size(),
      'Should return no records when no changes with field tokens'
    );
  }

  @IsTest
  static void testCataloging() {
    List<Account> accounts = [
      SELECT Id, Name, Industry, OwnerId
      FROM Account
      LIMIT 3
    ];
    DomainRecords domain = new DomainRecords();
    domain.init(null, accounts);

    // Test catalog by field name
    Map<String, List<SObject>> industryGroups = domain.catalog('Industry');
    System.assertEquals(
      2,
      industryGroups.size(),
      'Should have 2 industry groups'
    );
    System.assert(
      industryGroups.containsKey('Technology'),
      'Should have Technology group'
    );
    System.assert(
      industryGroups.containsKey('Healthcare'),
      'Should have Healthcare group'
    );
    System.assertEquals(
      2,
      industryGroups.get('Technology').size(),
      'Technology should have 2 accounts'
    );
    System.assertEquals(
      1,
      industryGroups.get('Healthcare').size(),
      'Healthcare should have 1 account'
    );

    // Test catalogId with a valid Id field
    Map<Id, List<SObject>> ownerGroups = domain.catalogId('OwnerId');
    System.assert(ownerGroups.size() > 0, 'Should have owner groups');

    // Test forget
    domain.forget('Industry');
    // Note: We can't easily test the memory clearing, but it shouldn't throw an error
  }

  @IsTest
  static void testAggregation() {
    List<Account> accounts = [
      SELECT Id, Name, Industry, OwnerId
      FROM Account
      LIMIT 3
    ];
    DomainRecords domain = new DomainRecords();
    domain.init(null, accounts);

    // Test aggregate by field name
    Object countResult = domain.aggregate(Application.s.count('Name'));
    System.assertEquals(3, countResult, 'Count should be 3');
  }

  @IsTest
  static void testUpdateDifferentCopiesTemplateAndTracksOnlyChangedRecords() {
    List<Account> accounts = new List<Account>{
      new Account(Name = 'Already Software', Industry = 'Software'),
      new Account(Name = 'Retail', Industry = 'Retail')
    };
    DomainRecords domain = new DomainRecords();
    domain.init(null, accounts);
    IWork work = new Work();

    domain.updateDifferent(new Account(Industry = 'Software'), work);
    Assert.areEqual('Software', accounts[0].Industry);
    Assert.areEqual('Software', accounts[1].Industry);

    work.apply();
    List<Account> inserted = [
      SELECT Name, Industry
      FROM Account
      WHERE Name IN ('Already Software', 'Retail')
    ];
    Assert.areEqual(1, inserted.size(), 'only the changed record is tracked');
    Assert.areEqual('Retail', inserted[0].Name);
  }

  @IsTest
  static void testUpdateBlankFillsOnlyNullOrBlankFields() {
    List<Account> accounts = new List<Account>{
      new Account(Name = 'A', Description = '   ', Industry = 'Software'),
      new Account(Name = 'B', Description = 'keep me')
    };
    DomainRecords domain = new DomainRecords();
    domain.init(null, accounts);

    domain.updateBlank(
      new Account(Description = 'filled', Industry = 'Energy'),
      null
    );

    Assert.areEqual('filled', accounts[0].Description, 'whitespace is blank');
    Assert.areEqual('Software', accounts[0].Industry, 'non-blank kept');
    Assert.areEqual('keep me', accounts[1].Description, 'non-blank kept');
    Assert.areEqual('Energy', accounts[1].Industry, 'null filled');
  }

  @IsTest
  static void testTemplateUpdatesRejectMismatchedTemplateType() {
    DomainRecords domain = new DomainRecords();
    domain.init(null, new List<Account>{ new Account(Name = 'A') });
    try {
      domain.updateDifferent(new Contact(LastName = 'wrong'), null);
      Assert.fail('expected IllegalArgumentException');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Account'), e.getMessage());
    }
  }

  // Helper to reset flags for TestDomain
  private static void resetTestDomainFlags(TestDomain d) {
    d.onBeforeInsertCalled = false;
    d.onAfterInsertCalled = false;
    d.onBeforeUpdateCalled = false;
    d.onAfterUpdateCalled = false;
    d.onBeforeDeleteCalled = false;
    d.onAfterDeleteCalled = false;
    d.onAfterUndeleteCalled = false;
  }

  @IsTest
  static void testHandleTrigger() {
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 2];
    Map<Id, SObject> oldMap = new Map<Id, SObject>(accounts);
    List<SObject> emptyList = new List<SObject>();
    Map<Id, SObject> emptyMap = new Map<Id, SObject>();

    // Test all trigger operations with state disabled (default)
    TestDomain domain;

    // BEFORE_INSERT
    domain = new TestDomain();
    domain.setTriggerMock(TriggerOperation.BEFORE_INSERT, accounts, null, null);
    domain.handleTrigger();
    System.assert(
      domain.onBeforeInsertCalled,
      'onBeforeInsert should be called'
    );
    System.assertEquals(
      accounts,
      domain.records(),
      'Records should be set for BEFORE_INSERT'
    );

    // AFTER_INSERT
    domain = new TestDomain();
    domain.setTriggerMock(TriggerOperation.AFTER_INSERT, accounts, null, null);
    domain.handleTrigger();
    System.assert(domain.onAfterInsertCalled, 'onAfterInsert should be called');
    System.assertEquals(
      accounts,
      domain.records(),
      'Records should be set for AFTER_INSERT'
    );

    // BEFORE_UPDATE
    domain = new TestDomain();
    domain.setTriggerMock(
      TriggerOperation.BEFORE_UPDATE,
      accounts,
      null,
      oldMap
    );
    domain.handleTrigger();
    System.assert(
      domain.onBeforeUpdateCalled,
      'onBeforeUpdate should be called'
    );
    System.assertEquals(
      accounts,
      domain.records(),
      'Records should be set for BEFORE_UPDATE'
    );

    // AFTER_UPDATE
    domain = new TestDomain();
    domain.setTriggerMock(
      TriggerOperation.AFTER_UPDATE,
      accounts,
      null,
      oldMap
    );
    domain.handleTrigger();
    System.assert(domain.onAfterUpdateCalled, 'onAfterUpdate should be called');
    System.assertEquals(
      accounts,
      domain.records(),
      'Records should be set for AFTER_UPDATE'
    );

    // BEFORE_DELETE
    domain = new TestDomain();
    domain.setTriggerMock(
      TriggerOperation.BEFORE_DELETE,
      null,
      accounts,
      oldMap
    );
    domain.handleTrigger();
    System.assert(
      domain.onBeforeDeleteCalled,
      'onBeforeDelete should be called'
    );
    System.assertEquals(
      accounts,
      domain.records(),
      'Records should be set for BEFORE_DELETE'
    );

    // AFTER_DELETE
    domain = new TestDomain();
    domain.setTriggerMock(
      TriggerOperation.AFTER_DELETE,
      null,
      accounts,
      oldMap
    );
    domain.handleTrigger();
    System.assert(domain.onAfterDeleteCalled, 'onAfterDelete should be called');
    System.assertEquals(
      accounts,
      domain.records(),
      'Records should be set for AFTER_DELETE'
    );

    // AFTER_UNDELETE
    domain = new TestDomain();
    domain.setTriggerMock(
      TriggerOperation.AFTER_UNDELETE,
      accounts,
      null,
      null
    );
    domain.handleTrigger();
    System.assert(
      domain.onAfterUndeleteCalled,
      'onAfterUndelete should be called'
    );
    System.assertEquals(
      accounts,
      domain.records(),
      'Records should be set for AFTER_UNDELETE'
    );
  }

  @IsTest
  static void testConfiguration() {
    DomainRecords domain = new DomainRecords();

    System.assertEquals(
      false,
      domain.shouldRecycleInstance(),
      'Default shouldRecycleInstance should be false'
    );
    System.assertEquals(
      false,
      domain.shouldEnforceSecurity(),
      'Default shouldEnforceSecurity should be false'
    );
  }

  @IsTest
  static void testSegmentOperations() {
    List<Account> accounts = [
      SELECT Id, Name, Industry, OwnerId
      FROM Account
      LIMIT 3
    ];
    DomainRecords domain = new DomainRecords(null, accounts);

    // Test segment by field name
    Map<String, List<SObject>> segments = domain.segment('Industry');
    System.assertEquals(2, segments.size(), 'Should have 2 segments');
    System.assert(
      segments.containsKey('Technology'),
      'Should have Technology segment'
    );
    System.assert(
      segments.containsKey('Healthcare'),
      'Should have Healthcare segment'
    );

    // Test segmentId with a valid Id field
    Map<Id, List<SObject>> segmentsById = domain.segmentId('OwnerId');
    System.assert(segmentsById.size() > 0, 'Should have segments by Id');
  }

  @IsTest
  static void testCollectRecords() {
    List<Account> accounts = [
      SELECT Id, Name, Industry, OwnerId
      FROM Account
      LIMIT 3
    ];
    DomainRecords domain = new DomainRecords(null, accounts);

    // Test collectRecords with a non-lookup field (should throw exception)
    try {
      Map<Id, SObject> collected = domain.collectRecords('Name');
      System.assert(false, 'Should have thrown exception for non-lookup field');
    } catch (IllegalArgumentException e) {
      System.assert(
        e.getMessage().contains('Path is not a lookup relationship'),
        'Should throw correct exception'
      );
    }
  }

  @IsTest
  static void testSource() {
    List<Account> accounts = [
      SELECT Id, Name, Industry, OwnerId
      FROM Account
      LIMIT 1
    ];
    DomainRecords domain = new DomainRecords(null, accounts);

    IModel source = domain.source();
    System.assert(source != null, 'Source should not be null');
    System.assertEquals(
      'Account',
      source.name(),
      'Source name should be Account'
    );
  }

  @IsTest
  static void testToMapWithNewRecords() {
    // Test toMap with records that don't have IDs yet
    List<Account> newAccounts = new List<Account>{
      new Account(Name = 'New Account 1'),
      new Account(Name = 'New Account 2')
    };
    DomainRecords domain = new DomainRecords();
    domain.init(null, newAccounts);

    Map<Id, SObject> recordMap = domain.toMap();
    System.assertEquals(
      0,
      recordMap.size(),
      'Should return empty map for records without IDs'
    );
  }

  @IsTest
  static void testFilterWithNullCondition() {
    List<Account> accounts = [
      SELECT Id, Name, Industry, OwnerId
      FROM Account
      LIMIT 3
    ];
    DomainRecords domain = new DomainRecords();
    domain.init(null, accounts);

    try {
      domain.filter(null);
      System.assert(false, 'Should have thrown exception for null condition');
    } catch (IllegalArgumentException e) {
      System.assert(
        e.getMessage().contains('Condition cannot be null'),
        'Should throw correct exception'
      );
    }
  }

  @IsTest
  static void testGetChangedRecordsWithNullFieldTokens() {
    List<Account> accounts = [
      SELECT Id, Name, Industry, OwnerId
      FROM Account
      LIMIT 3
    ];
    DomainRecords domain = new DomainRecords();
    domain.init(null, accounts);

    try {
      domain.getChangedRecords(
        new Map<Id, SObject>(),
        (Set<SObjectField>) null
      );
      System.assert(
        false,
        'Should have thrown exception for null field tokens'
      );
    } catch (IllegalArgumentException e) {
      System.assert(
        e.getMessage().contains('Field tokens cannot be null/empty'),
        'Should throw correct exception'
      );
    }
  }

  @IsTest
  static void testGetChangedRecordsWithEmptyFieldTokens() {
    List<Account> accounts = [
      SELECT Id, Name, Industry, OwnerId
      FROM Account
      LIMIT 3
    ];
    DomainRecords domain = new DomainRecords();
    domain.init(null, accounts);

    try {
      domain.getChangedRecords(new Map<Id, SObject>(), new Set<SObjectField>());
      System.assert(
        false,
        'Should have thrown exception for empty field tokens'
      );
    } catch (IllegalArgumentException e) {
      System.assert(
        e.getMessage().contains('Field tokens cannot be null/empty'),
        'Should throw correct exception'
      );
    }
  }

  @IsTest
  static void testInitWithNullRecords() {
    DomainRecords domain = new DomainRecords();
    domain.init(null, null);
    System.assertEquals(
      0,
      domain.records().size(),
      'Should handle null records'
    );
    System.assert(domain.isInitialized(), 'Should be initialized');
  }

  @IsTest
  static void testInitWithEmptyRecords() {
    DomainRecords domain = new DomainRecords();
    domain.init(null, new List<SObject>());
    System.assertEquals(
      0,
      domain.records().size(),
      'Should handle empty records'
    );
    System.assert(domain.isInitialized(), 'Should be initialized');
  }

  @IsTest
  static void testDoubleInitThrowsException() {
    IModel accountModel = Application.s.model(Account.SObjectType);
    IModel contactModel = Application.s.model(Contact.SObjectType);
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 1];
    DomainRecords domain = new DomainRecords();
    domain.init(accountModel, accounts);

    // Same model: idempotent, should not throw
    domain.init(accountModel, accounts);
    System.assert(domain.isInitialized(), 'Domain should still be initialized');

    // Different model: should throw
    try {
      domain.init(contactModel, new List<Contact>());
      System.assert(
        false,
        'Should have thrown exception for init with different model'
      );
    } catch (IllegalArgumentException e) {
      System.assert(
        e.getMessage()
          .contains('already been initialized with a different model'),
        'Should throw correct exception: ' + e.getMessage()
      );
    }
  }

  @IsTest
  static void testHandleTriggerWithAlreadyInitialized() {
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 1];
    TestDomain domain = new TestDomain();
    domain.init(null, accounts);

    // Should not re-initialize when already initialized
    domain.setTriggerMock(null, accounts, null, null);
    domain.handleTrigger();
    System.assertEquals(
      accounts,
      domain.records(),
      'Records should remain the same'
    );
  }

  @IsTest
  static void testRecordsReturnsClone() {
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 1];
    DomainRecords domain = new DomainRecords(null, accounts);

    List<SObject> records1 = domain.records();
    List<SObject> records2 = domain.records();

    System.assert(
      records1 !== records2,
      'Should return different list instances'
    );
  }

  @IsTest
  static void testToMapReturnsClone() {
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 1];
    DomainRecords domain = new DomainRecords(null, accounts);

    Map<Id, SObject> map1 = domain.toMap();
    Map<Id, SObject> map2 = domain.toMap();

    System.assert(map1 !== map2, 'Should return different list instances');
  }

  @IsTest
  static void testSegmentWithNullValues() {
    List<Account> accounts = [
      SELECT Id, Name, Industry, Description
      FROM Account
      LIMIT 3
    ];
    // Set some descriptions to null
    for (Account acc : accounts) {
      acc.Description = null;
    }
    update accounts;

    DomainRecords domain = new DomainRecords(null, accounts);
    Map<String, List<SObject>> segments = domain.segment('Description');

    System.assert(segments.containsKey('null'), 'Should handle null values');
    System.assertEquals(
      3,
      segments.get('null').size(),
      'Should group all null values'
    );
  }

  @IsTest
  static void testSegmentIdWithNonIdValues() {
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 3];
    DomainRecords domain = new DomainRecords(null, accounts);

    // Test segmentId with a field that doesn't contain Id values
    Map<Id, List<SObject>> segments = domain.segmentId('Name');
    System.assertEquals(
      0,
      segments.size(),
      'Should return empty map for non-Id field'
    );
  }

  @IsTest
  static void testAggregationWithNumericValues() {
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 3];
    DomainRecords domain = new DomainRecords(null, accounts);

    // Test aggregation with different aggregate functions
    Object countResult = domain.aggregate(Application.s.count('Name'));
    System.assertEquals(3, countResult, 'Count should be 3');

    Object minResult = domain.aggregate(Application.s.min('Name'));
    System.assertNotEquals(null, minResult, 'Min should not be null');

    Object maxResult = domain.aggregate(Application.s.max('Name'));
    System.assertNotEquals(null, maxResult, 'Max should not be null');
  }

  @IsTest
  static void testCatalogMemoryCaching() {
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 3];
    DomainRecords domain = new DomainRecords(null, accounts);

    // First call should populate cache
    Map<String, List<SObject>> result1 = domain.catalog('Industry');
    System.assertEquals(2, result1.size(), 'Should have 2 industry groups');

    // Second call should use cache
    Map<String, List<SObject>> result2 = domain.catalog('Industry');
    System.assertEquals(2, result2.size(), 'Should have 2 industry groups');

    // Clear cache
    domain.forget('Industry');

    // Third call should repopulate cache
    Map<String, List<SObject>> result3 = domain.catalog('Industry');
    System.assertEquals(2, result3.size(), 'Should have 2 industry groups');
  }

  @IsTest
  static void testCatalogIdMemoryCaching() {
    List<Account> accounts = [
      SELECT Id, Name, Industry, OwnerId
      FROM Account
      LIMIT 3
    ];
    DomainRecords domain = new DomainRecords(null, accounts);

    // First call should populate cache
    Map<Id, List<SObject>> result1 = domain.catalogId('OwnerId');
    System.assert(result1.size() > 0, 'Should have owner groups');

    // Second call should use cache
    Map<Id, List<SObject>> result2 = domain.catalogId('OwnerId');
    System.assert(result2.size() > 0, 'Should have owner groups');

    // Clear cache
    domain.forget('OwnerId');

    // Third call should repopulate cache
    Map<Id, List<SObject>> result3 = domain.catalogId('OwnerId');
    System.assert(result3.size() > 0, 'Should have owner groups');
  }

  @IsTest
  static void testForgetWithNonExistentField() {
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 1];
    DomainRecords domain = new DomainRecords(null, accounts);

    // Should not throw exception for non-existent field
    domain.forget('NonExistentField');
  }

  @IsTest
  static void testCollectRecordsWithNullPath() {
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 1];
    DomainRecords domain = new DomainRecords(null, accounts);

    try {
      domain.collectRecords('NonExistentField');
      System.assert(
        false,
        'Should have thrown exception for non-existent field'
      );
    } catch (IllegalArgumentException e) {
      System.assert(
        e.getMessage().contains('Field not found'),
        'Should throw correct exception'
      );
    }
  }

  @IsTest
  static void testAggregateWithNullPath() {
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 1];
    DomainRecords domain = new DomainRecords(null, accounts);

    try {
      domain.aggregate(Application.s.count('NonExistentField'));
      System.assert(
        false,
        'Should have thrown exception for non-existent field'
      );
    } catch (IllegalArgumentException e) {
      System.assert(
        e.getMessage().contains('Field not found'),
        'Should throw correct exception'
      );
    }
  }

  @IsTest
  static void testSegmentWithNullPath() {
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 1];
    DomainRecords domain = new DomainRecords(null, accounts);

    try {
      domain.segment('NonExistentField');
      System.assert(
        false,
        'Should have thrown exception for non-existent field'
      );
    } catch (IllegalArgumentException e) {
      System.assert(
        e.getMessage().contains('Field not found'),
        'Should throw correct exception'
      );
    }
  }

  @IsTest
  static void testSegmentIdWithNullPath() {
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 1];
    DomainRecords domain = new DomainRecords(null, accounts);

    try {
      domain.segmentId('NonExistentField');
      System.assert(
        false,
        'Should have thrown exception for non-existent field'
      );
    } catch (IllegalArgumentException e) {
      System.assert(
        e.getMessage().contains('Field not found'),
        'Should throw correct exception'
      );
    }
  }

  @IsTest
  static void testCatalogWithNullPath() {
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 1];
    DomainRecords domain = new DomainRecords(null, accounts);

    try {
      domain.catalog('NonExistentField');
      System.assert(
        false,
        'Should have thrown exception for non-existent field'
      );
    } catch (IllegalArgumentException e) {
      System.assert(
        e.getMessage().contains('Field not found'),
        'Should throw correct exception'
      );
    }
  }

  @IsTest
  static void testCatalogIdWithNullPath() {
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 1];
    DomainRecords domain = new DomainRecords(null, accounts);

    try {
      domain.catalogId('NonExistentField');
      System.assert(
        false,
        'Should have thrown exception for non-existent field'
      );
    } catch (IllegalArgumentException e) {
      System.assert(
        e.getMessage().contains('Field not found'),
        'Should throw correct exception'
      );
    }
  }

  @IsTest
  static void testGetChangedRecordsWithChangedValues() {
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 1];
    DomainRecords domain = new DomainRecords(null, accounts);

    // Create existing records with different values
    Account existingAccount = accounts[0].clone(true, true, true, true);
    existingAccount.Name = 'Different Name';
    Map<Id, SObject> existingRecords = new Map<Id, SObject>{
      existingAccount.Id => existingAccount
    };

    List<SObject> changedRecords = domain.getChangedRecords(
      existingRecords,
      new Set<String>{ 'Name' }
    );
    System.assertEquals(
      1,
      changedRecords.size(),
      'Should return record with changed Name'
    );
  }

  @IsTest
  static void testGetChangedRecordsWithNewRecords() {
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 1];
    DomainRecords domain = new DomainRecords(null, accounts);

    // Create existing records map without the current record
    Map<Id, SObject> existingRecords = new Map<Id, SObject>();

    List<SObject> changedRecords = domain.getChangedRecords(
      existingRecords,
      new Set<String>{ 'Name' }
    );
    System.assertEquals(
      1,
      changedRecords.size(),
      'Should return record that is new'
    );
  }

  @IsTest
  static void testIsInitialized() {
    DomainRecords domain = new DomainRecords();
    System.assert(
      !domain.isInitialized(),
      'Should not be initialized initially'
    );

    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 1];
    domain.init(null, accounts);
    System.assert(domain.isInitialized(), 'Should be initialized after init');
  }

  @IsTest
  static void testConstructorWithRecords() {
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 2];
    DomainRecords domain = new DomainRecords(null, accounts);

    System.assertEquals(2, domain.records().size(), 'Should have 2 records');
    System.assert(domain.isInitialized(), 'Should be initialized');
    System.assert(domain.source() != null, 'Source should be set');
  }

  @IsTest
  static void testSizeMethod() {
    List<Account> accounts = [
      SELECT Id, Name, Industry, OwnerId
      FROM Account
      LIMIT 3
    ];
    DomainRecords domain = new DomainRecords();
    domain.init(null, accounts);

    // Test size method with records
    System.assertEquals(3, domain.size(), 'Size should be 3');

    // Test size method with empty records
    DomainRecords emptyDomain = new DomainRecords();
    emptyDomain.init(null, new List<SObject>());
    System.assertEquals(
      0,
      emptyDomain.size(),
      'Size should be 0 for empty records'
    );

    // Test size method with null records (should return 0)
    DomainRecords nullDomain = new DomainRecords();
    nullDomain.init(null, null);
    System.assertEquals(
      0,
      nullDomain.size(),
      'Size should be 0 for null records'
    );
  }

  // ========================================
  // Enhanced Trigger Lifecycle Tests
  // ========================================

  @IsTest
  static void testTriggerLifecycle_instanceRecycling() {
    // Test that same instance can be reused across BEFORE/AFTER phases
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 2];
    Map<Id, SObject> oldMap = new Map<Id, SObject>();
    for (Account acc : accounts) {
      Account oldAcc = acc.clone(true, true, true, true);
      oldAcc.Name = 'Old Name';
      oldMap.put(acc.Id, oldAcc);
    }

    TestDomain domain = new TestDomain();

    // BEFORE UPDATE
    domain.setTriggerMock(
      TriggerOperation.BEFORE_UPDATE,
      accounts,
      null,
      oldMap
    );
    domain.handleTrigger();
    System.assert(
      domain.onBeforeUpdateCalled,
      'onBeforeUpdate should be called'
    );

    // Reset flag but keep instance
    domain.onBeforeUpdateCalled = false;
    domain.onAfterUpdateCalled = false;

    // AFTER UPDATE - same instance
    domain.setTriggerMock(
      TriggerOperation.AFTER_UPDATE,
      accounts,
      null,
      oldMap
    );
    domain.handleTrigger();
    System.assert(domain.onAfterUpdateCalled, 'onAfterUpdate should be called');
    System.assertEquals(
      accounts,
      domain.records(),
      'Records should still be set'
    );
  }

  @IsTest
  static void testTriggerLifecycle_multipleRecordsInsert() {
    // Test handling multiple records in insert operation
    List<Account> newAccounts = new List<Account>{
      new Account(Name = 'Bulk Account 1', Industry = 'Technology'),
      new Account(Name = 'Bulk Account 2', Industry = 'Healthcare'),
      new Account(Name = 'Bulk Account 3', Industry = 'Finance'),
      new Account(Name = 'Bulk Account 4', Industry = 'Retail'),
      new Account(Name = 'Bulk Account 5', Industry = 'Manufacturing')
    };

    TestDomain domain = new TestDomain();
    domain.setTriggerMock(
      TriggerOperation.BEFORE_INSERT,
      newAccounts,
      null,
      null
    );
    domain.handleTrigger();

    System.assert(
      domain.onBeforeInsertCalled,
      'onBeforeInsert should be called'
    );
    System.assertEquals(
      5,
      domain.records().size(),
      'Should have 5 records in domain'
    );
  }

  @IsTest
  static void testTriggerLifecycle_multipleRecordsUpdate() {
    // Test handling multiple records in update operation
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 3];
    Map<Id, SObject> oldMap = new Map<Id, SObject>();

    for (Account acc : accounts) {
      Account oldAcc = acc.clone(true, true, true, true);
      oldAcc.Name = 'Old ' + acc.Name;
      oldAcc.Industry = 'Old Industry';
      oldMap.put(acc.Id, oldAcc);
    }

    TestDomain domain = new TestDomain();
    domain.setTriggerMock(
      TriggerOperation.BEFORE_UPDATE,
      accounts,
      null,
      oldMap
    );
    domain.handleTrigger();

    System.assert(
      domain.onBeforeUpdateCalled,
      'onBeforeUpdate should be called for bulk update'
    );
    System.assertEquals(
      3,
      domain.records().size(),
      'Should have 3 records in domain'
    );

    // Test getChangedRecords in the context
    List<SObject> changedRecords = domain.getChangedRecords(
      oldMap,
      new Set<String>{ 'Name' }
    );
    System.assertEquals(
      3,
      changedRecords.size(),
      'All records should show Name as changed'
    );
  }

  @IsTest
  static void testTriggerLifecycle_multipleRecordsDelete() {
    // Test handling multiple records in delete operation
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 3];
    Map<Id, SObject> oldMap = new Map<Id, SObject>(accounts);

    TestDomain domain = new TestDomain();
    domain.setTriggerMock(
      TriggerOperation.BEFORE_DELETE,
      null,
      accounts,
      oldMap
    );
    domain.handleTrigger();

    System.assert(
      domain.onBeforeDeleteCalled,
      'onBeforeDelete should be called for bulk delete'
    );
    System.assertEquals(
      3,
      domain.records().size(),
      'Should have 3 records in domain from oldList'
    );
  }

  @IsTest
  static void testTriggerLifecycle_completeCycle() {
    // Test a complete insert -> update -> delete lifecycle
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 1];

    TestDomain domain = new TestDomain();

    // INSERT lifecycle
    domain.setTriggerMock(TriggerOperation.BEFORE_INSERT, accounts, null, null);
    domain.handleTrigger();
    System.assert(
      domain.onBeforeInsertCalled,
      'BEFORE_INSERT should be called'
    );

    resetTestDomainFlags(domain);
    domain.setTriggerMock(TriggerOperation.AFTER_INSERT, accounts, null, null);
    domain.handleTrigger();
    System.assert(domain.onAfterInsertCalled, 'AFTER_INSERT should be called');

    // UPDATE lifecycle
    Map<Id, SObject> oldMap = new Map<Id, SObject>();
    Account oldAcc = accounts[0].clone(true, true, true, true);
    oldAcc.Name = 'Old Name';
    oldMap.put(oldAcc.Id, oldAcc);

    resetTestDomainFlags(domain);
    domain.setTriggerMock(
      TriggerOperation.BEFORE_UPDATE,
      accounts,
      null,
      oldMap
    );
    domain.handleTrigger();
    System.assert(
      domain.onBeforeUpdateCalled,
      'BEFORE_UPDATE should be called'
    );

    resetTestDomainFlags(domain);
    domain.setTriggerMock(
      TriggerOperation.AFTER_UPDATE,
      accounts,
      null,
      oldMap
    );
    domain.handleTrigger();
    System.assert(domain.onAfterUpdateCalled, 'AFTER_UPDATE should be called');

    // DELETE lifecycle
    resetTestDomainFlags(domain);
    domain.setTriggerMock(
      TriggerOperation.BEFORE_DELETE,
      null,
      accounts,
      oldMap
    );
    domain.handleTrigger();
    System.assert(
      domain.onBeforeDeleteCalled,
      'BEFORE_DELETE should be called'
    );

    resetTestDomainFlags(domain);
    domain.setTriggerMock(
      TriggerOperation.AFTER_DELETE,
      null,
      accounts,
      oldMap
    );
    domain.handleTrigger();
    System.assert(domain.onAfterDeleteCalled, 'AFTER_DELETE should be called');

    // UNDELETE lifecycle
    resetTestDomainFlags(domain);
    domain.setTriggerMock(
      TriggerOperation.AFTER_UNDELETE,
      accounts,
      null,
      null
    );
    domain.handleTrigger();
    System.assert(
      domain.onAfterUndeleteCalled,
      'AFTER_UNDELETE should be called'
    );
  }

  @IsTest
  static void testTriggerLifecycle_oldMapAccess() {
    // Test that oldMap is properly accessible in update and delete operations
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 2];

    Map<Id, SObject> oldMap = new Map<Id, SObject>();
    for (Account acc : accounts) {
      Account oldAcc = acc.clone(true, true, true, true);
      oldAcc.Name = 'Previous Name';
      oldAcc.Industry = 'Previous Industry';
      oldMap.put(acc.Id, oldAcc);
    }

    // Test domain class that verifies oldMap access
    TestDomain domain = new TestDomain();
    domain.setTriggerMock(
      TriggerOperation.BEFORE_UPDATE,
      accounts,
      null,
      oldMap
    );
    domain.handleTrigger();

    System.assert(
      domain.onBeforeUpdateCalled,
      'onBeforeUpdate should be called'
    );

    // Verify we can detect field changes using getChangedRecords
    List<SObject> nameChanges = domain.getChangedRecords(
      oldMap,
      new Set<String>{ 'Name' }
    );
    System.assertEquals(
      2,
      nameChanges.size(),
      'Both records should have Name changes'
    );

    List<SObject> industryChanges = domain.getChangedRecords(
      oldMap,
      new Set<String>{ 'Industry' }
    );
    System.assertEquals(
      2,
      industryChanges.size(),
      'Both records should have Industry changes'
    );
  }

  @IsTest
  static void testTriggerLifecycle_filterRecordsInTrigger() {
    // Test using domain filtering within trigger context
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 3];

    TestDomain domain = new TestDomain();
    domain.setTriggerMock(TriggerOperation.BEFORE_INSERT, accounts, null, null);
    domain.handleTrigger();

    // Filter records by Industry
    ICondition techCondition = Application.s.eq('Industry', 'Technology');
    List<SObject> techAccounts = domain.filter(techCondition);
    System.assertEquals(
      2,
      techAccounts.size(),
      'Should filter to Technology accounts in trigger context'
    );
  }

  @IsTest
  static void testTriggerLifecycle_segmentRecordsInTrigger() {
    // Test using domain segmentation within trigger context
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account LIMIT 3];

    TestDomain domain = new TestDomain();
    domain.setTriggerMock(TriggerOperation.AFTER_INSERT, accounts, null, null);
    domain.handleTrigger();

    // Segment records by Industry
    Map<String, List<SObject>> segments = domain.segment('Industry');
    System.assertEquals(2, segments.size(), 'Should have 2 industry segments');
    System.assert(
      segments.containsKey('Technology'),
      'Should have Technology segment'
    );
    System.assert(
      segments.containsKey('Healthcare'),
      'Should have Healthcare segment'
    );
  }

  // Test domain with security enforcement enabled
  public class SecuredTestDomain extends DomainRecords {
    public override Boolean shouldEnforceSecurity() {
      return true;
    }
  }

  @IsTest
  static void testSecurityEnforcement_configuration() {
    // Test that security enforcement can be configured
    SecuredTestDomain securedDomain = new SecuredTestDomain();
    System.assertEquals(
      true,
      securedDomain.shouldEnforceSecurity(),
      'Secured domain should enforce security'
    );

    DomainRecords normalDomain = new DomainRecords();
    System.assertEquals(
      false,
      normalDomain.shouldEnforceSecurity(),
      'Normal domain should not enforce security by default'
    );
  }

  // Test domain with instance recycling enabled
  public class RecyclableDomain extends DomainRecords {
    public override Boolean shouldRecycleInstance() {
      return true;
    }
  }

  @IsTest
  static void testInstanceRecycling_configuration() {
    // Test that instance recycling can be configured
    RecyclableDomain recyclableDomain = new RecyclableDomain();
    System.assertEquals(
      true,
      recyclableDomain.shouldRecycleInstance(),
      'Recyclable domain should enable instance recycling'
    );

    DomainRecords normalDomain = new DomainRecords();
    System.assertEquals(
      false,
      normalDomain.shouldRecycleInstance(),
      'Normal domain should not recycle by default'
    );
  }

  @IsTest
  static void testAggregateResultCatalog() {
    // Test that catalog/segment operations work with AggregateResult sources
    // (which don't have field describes available)
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account];

    // Create opportunities linked to accounts
    List<Opportunity> opps = new List<Opportunity>();
    for (Account acc : accounts) {
      opps.add(
        new Opportunity(
          Name = 'Test Opp for ' + acc.Name,
          AccountId = acc.Id,
          StageName = 'Prospecting',
          CloseDate = Date.today().addDays(30),
          Amount = 10000
        )
      );
    }
    insert opps;

    // Create aggregate query
    IAggregateQuery aggQuery = Application.s
      .model(Opportunity.SObjectType)
      .aggregateQuery();
    aggQuery.groupBys().add(Application.s.path(Opportunity.AccountId));
    aggQuery.aggregates().add(Application.s.count(Opportunity.Id));
    aggQuery.aggregates().add(Application.s.sum(Opportunity.Amount));

    // Create domain from AggregateResult
    IDomain aggDomain = Application.s.df().make(aggQuery.run());

    System.assert(aggDomain.size() > 0, 'Should have aggregate results');

    // Test catalogId with string path (uses StringPath fallback)
    Map<Id, List<SObject>> catalogById = aggDomain.catalogId('AccountId');
    System.assertEquals(
      accounts.size(),
      catalogById.size(),
      'Should have one catalog entry per account'
    );

    // Test segment with string path
    Map<String, List<SObject>> segments = aggDomain.segment('AccountId');
    System.assert(segments.size() > 0, 'Should have segments');

    // Test catalog with string path
    Map<String, List<SObject>> catalog = aggDomain.catalog('AccountId');
    System.assert(catalog.size() > 0, 'Should have catalog entries');

    // Verify we can access aggregate values
    for (SObject agg : aggDomain.records()) {
      Id accountId = (Id) agg.get('AccountId');
      System.assertNotEquals(null, accountId, 'Should have AccountId');

      Object count = agg.get('Id_cnt');
      System.assertEquals(1, count, 'Should have count of 1');

      Object sumAmount = agg.get('Amount_sum');
      System.assertEquals(10000, sumAmount, 'Should have sum of 10000');
    }

    // Test segmentId as well
    Map<Id, List<SObject>> segmentsById = aggDomain.segmentId('AccountId');
    System.assertEquals(
      accounts.size(),
      segmentsById.size(),
      'Should have one segment per account'
    );
  }

  @IsTest
  static void minAndMaxCompareValuesNotPositions() {
    List<Account> rows = new List<Account>{
      new Account(Name = 'b', AnnualRevenue = 5, NumberOfEmployees = 20),
      new Account(Name = 'a', AnnualRevenue = 1, NumberOfEmployees = 7),
      new Account(Name = 'c', AnnualRevenue = 3)
    };
    IDomain domain = Application.s.model(Account.SObjectType).domain(rows);

    Assert.areEqual((Decimal) 1, domain.aggregate(Application.s.min(Account.AnnualRevenue)), 'used to return the first value');
    Assert.areEqual((Decimal) 5, domain.aggregate(Application.s.max(Account.AnnualRevenue)));
    Assert.areEqual('a', domain.aggregate(Application.s.min(Account.Name)));
    Assert.areEqual('c', domain.aggregate(Application.s.max(Account.Name)));
    Assert.areEqual((Decimal) 27, domain.aggregate(Application.s.sum(Account.NumberOfEmployees)), 'nulls are skipped');
    Assert.areEqual(13.5, domain.aggregate(Application.s.avg(Account.NumberOfEmployees)));
  }

  @IsTest
  static void minAndMaxWorkOnDates() {
    Date early = Date.newInstance(2026, 1, 5);
    Date late = Date.newInstance(2026, 3, 9);
    List<Opportunity> deals = new List<Opportunity>{
      new Opportunity(Name = 'mid', CloseDate = early.addDays(10)),
      new Opportunity(Name = 'late', CloseDate = late),
      new Opportunity(Name = 'early', CloseDate = early)
    };
    IDomain domain = Application.s.model(Opportunity.SObjectType).domain(deals);

    Assert.areEqual(early, domain.aggregate(Application.s.min(Opportunity.CloseDate)));
    Assert.areEqual(late, domain.aggregate(Application.s.max(Opportunity.CloseDate)));
  }
}
