@IsTest
public class WorkTest {
  @TestSetup
  static void setup() {
    // Create test data if needed
  }

  @IsTest
  static void testBasicTracking() {
    // Test basic record tracking
    IWork work = Work.make();

    Account acc = new Account(Name = 'Test Account');
    work.track(acc);

    System.assert(work.hasWork(), 'Work should have pending work');

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Verify the record was inserted by Id
    System.assertNotEquals(
      null,
      acc.Id,
      'Account Id should be populated after apply'
    );
    Account fetched = [SELECT Id, Name FROM Account WHERE Id = :acc.Id];
    System.assertEquals(
      acc.Id,
      fetched.Id,
      'Account should have been inserted'
    );
  }

  @IsTest
  static void testDependentWorkWithParentChildRelationship() {
    // This test replicates the scenario from the anonymous apex
    IWork work = Work.make();

    // Create a list of accounts
    List<Account> accList = new List<Account>();
    for (Integer i = 0; i < 3; i++) {
      Account acc = new Account(Name = String.valueOf(i));
      accList.add(acc);
    }

    // Track accounts with parent-child relationships
    for (Integer i = 0; i < 3; i++) {
      if (i == 0) {
        work.track(accList[i]);
      } else {
        work.track(accList[i], Account.ParentId, accList[i - 1]);
      }
    }

    System.assert(work.hasWork(), 'Work should have pending work');

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Verify all accounts were inserted (by Id) and relationships established
    System.assertNotEquals(null, accList[0].Id);
    System.assertNotEquals(null, accList[1].Id);
    System.assertNotEquals(null, accList[2].Id);
    Account a0 = [SELECT Id, ParentId FROM Account WHERE Id = :accList[0].Id];
    Account a1 = [SELECT Id, ParentId FROM Account WHERE Id = :accList[1].Id];
    Account a2 = [SELECT Id, ParentId FROM Account WHERE Id = :accList[2].Id];
    System.assertEquals(
      null,
      a0.ParentId,
      'First account should have no parent'
    );
    System.assertEquals(
      a0.Id,
      a1.ParentId,
      'Second account should have first account as parent'
    );
    System.assertEquals(
      a1.Id,
      a2.ParentId,
      'Third account should have second account as parent'
    );
  }

  @IsTest
  static void testDependentWorkWithContactAccountRelationship() {
    IWork work = Work.make();

    // Create account and contact
    Account acc = new Account(Name = 'Test Account');
    Contact con = new Contact(FirstName = 'John', LastName = 'Doe');

    // Track with relationship - should automatically track both records
    work.track(con, Contact.AccountId, acc);

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Verify relationship was established by Id
    System.assertNotEquals(null, con.Id, 'Contact should be inserted');
    System.assertNotEquals(null, acc.Id, 'Account should be inserted');
    Contact conFetched = [SELECT Id, AccountId FROM Contact WHERE Id = :con.Id];
    System.assertEquals(
      acc.Id,
      conFetched.AccountId,
      'Contact should be linked to the correct account'
    );
  }

  @IsTest
  static void testDependentWorkWithExternalId() {
    IWork work = Work.make();

    // Test external ID validation - this should throw an exception since AccountNumber is not marked as external ID
    Account acc = new Account(Name = 'Test Account', AccountNumber = 'ACC001');
    Contact con = new Contact(FirstName = 'Jane', LastName = 'Smith');

    work.track(acc);

    try {
      work.track(con, Contact.AccountId, Account.AccountNumber, 'ACC001');
      System.assert(
        false,
        'Should have thrown exception for non-external ID field'
      );
    } catch (Work.WorkException e) {
      System.assert(
        e.getMessage()
          .contains('externalIdField must be marked as External ID'),
        'Should throw appropriate error message for non-external ID field'
      );
    }

    // Test null parameter validation
    try {
      work.track(con, Contact.AccountId, null, 'ACC001');
      System.assert(
        false,
        'Should have thrown exception for null externalIdField'
      );
    } catch (Work.WorkException e) {
      System.assert(
        e.getMessage().contains('externalIdField cannot be null'),
        'Should throw appropriate error message for null externalIdField'
      );
    }

    // Test null relatedToField validation
    try {
      work.track(con, null, Account.AccountNumber, 'ACC001');
      System.assert(
        false,
        'Should have thrown exception for null relatedToField'
      );
    } catch (Work.WorkException e) {
      System.assert(
        e.getMessage().contains('relatedToField cannot be null'),
        'Should throw appropriate error message for null relatedToField'
      );
    }
  }

  @IsTest
  static void testMultipleDependentRecords() {
    IWork work = Work.make();

    // Create multiple accounts
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < 5; i++) {
      accounts.add(new Account(Name = 'Account ' + i));
    }

    // Create contacts for each account
    List<Contact> contacts = new List<Contact>();
    for (Integer i = 0; i < 5; i++) {
      Contact con = new Contact(
        FirstName = 'Contact',
        LastName = String.valueOf(i)
      );
      contacts.add(con);
    }

    // Track contacts with relationships - should automatically track accounts too
    for (Integer i = 0; i < 5; i++) {
      work.track(contacts[i], Contact.AccountId, accounts[i]);
    }

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Verify all records were inserted with correct relationships
    List<Contact> insertedContacts = [
      SELECT Id, AccountId, Account.Name
      FROM Contact
      WHERE FirstName = 'Contact'
      ORDER BY LastName
    ];
    System.assertEquals(
      5,
      insertedContacts.size(),
      'All contacts should have been inserted'
    );

    for (Contact con : insertedContacts) {
      System.assertNotEquals(
        null,
        con.AccountId,
        'Each contact should have an AccountId'
      );
    }
  }

  @IsTest
  static void testPurgeRecords() {
    // First create some test data
    Account acc1 = new Account(Name = 'Account to Delete');
    Account acc2 = new Account(Name = 'Account to Keep');
    insert acc1;
    insert acc2;

    IWork work = Work.make();

    // Track for deletion
    work.purge(acc1);

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Verify deletion
    List<Account> remainingAccounts = [
      SELECT Id, Name
      FROM Account
      WHERE Name IN ('Account to Delete', 'Account to Keep')
    ];
    System.assertEquals(
      1,
      remainingAccounts.size(),
      'Only one account should remain'
    );
    System.assertEquals(
      'Account to Keep',
      remainingAccounts[0].Name,
      'Correct account should remain'
    );
  }

  @IsTest
  static void testUpdateRecords() {
    // Create test data
    Account acc = new Account(Name = 'Original Name');
    insert acc;

    IWork work = Work.make();

    // Update the record
    acc.Name = 'Updated Name';
    work.track(acc);

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Verify update
    Account updatedAcc = [SELECT Id, Name FROM Account WHERE Id = :acc.Id];
    System.assertEquals(
      'Updated Name',
      updatedAcc.Name,
      'Account name should have been updated'
    );
  }

  @IsTest
  static void testEmailTracking() {
    IWork work = Work.make();

    // Create test email
    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setToAddresses(new List<String>{ 'test@example.com' });
    email.setSubject('Test Subject');
    email.setPlainTextBody('Test Body');

    work.track(email);

    System.assert(work.hasWork(), 'Work should have pending work');

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Note: In test context, emails are not actually sent, but the method should execute without error
  }

  @IsTest
  static void testNullHandling() {
    IWork work = Work.make();

    // Test null record handling
    work.track((SObject) null);
    work.track((List<SObject>) null);
    work.purge((SObject) null);
    work.purge((List<SObject>) null);
    work.track((Messaging.Email) null);
    work.track((List<Messaging.Email>) null);

    // Should not throw exceptions and should not have work
    System.assert(
      !work.hasWork(),
      'Work should not have pending work when tracking null values'
    );
  }

  @IsTest
  static void testErrorHandling() {
    IWork work = Work.make();

    // Try to purge a new record (should throw exception)
    Account acc = new Account(Name = 'Test');

    try {
      work.purge(acc);
      System.assert(
        false,
        'Should have thrown exception when trying to purge new record'
      );
    } catch (Exception e) {
      System.assert(
        e.getMessage().contains('New records cannot be registered for purge'),
        'Should throw appropriate error message'
      );
    }
  }

  @IsTest
  static void testComplexDependencyChain() {
    IWork work = Work.make();

    // Create a complex dependency chain: Account -> Contact -> Case
    Account acc = new Account(Name = 'Parent Account');
    Contact con = new Contact(FirstName = 'John', LastName = 'Doe');
    Case c = new Case(Subject = 'Test Case');

    // Track with dependencies - should automatically track all related records
    work.track(con, Contact.AccountId, acc);
    work.track(c, Case.ContactId, con);

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Verify the entire chain was created correctly
    Case fetched = [
      SELECT Id, ContactId, Contact.AccountId
      FROM Case
      WHERE Id = :c.Id
    ];
    System.assertEquals(
      con.Id,
      fetched.ContactId,
      'Case should be linked to correct contact'
    );
    Contact cf = [SELECT Id, AccountId FROM Contact WHERE Id = :con.Id];
    System.assertEquals(
      acc.Id,
      cf.AccountId,
      'Contact should be linked to correct account'
    );
  }

  @IsTest
  static void testJunctionInsert_Account_Case_Contact() {
    // A < B > C pattern using Case as the junction between Account and Contact
    IWork work = Work.make();

    Account a = new Account(Name = 'Junction A');
    Contact c = new Contact(LastName = 'Junction C');
    Case b = new Case(Subject = 'Junction B');

    // Track parents
    work.track(a);
    work.track(c);

    // Track junction with both relations to be resolved after insert
    work.track(b, Case.AccountId, a);
    work.track(b, Case.ContactId, c);

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Verify all were created and relationships established using Ids
    Account qa = [SELECT Id, Name FROM Account WHERE Id = :a.Id];
    Contact qc = [SELECT Id, LastName FROM Contact WHERE Id = :c.Id];
    Case qb = [SELECT Id, AccountId, ContactId FROM Case WHERE Id = :b.Id];

    System.assertNotEquals(null, qa, 'Account should be inserted');
    System.assertNotEquals(null, qc, 'Contact should be inserted');
    System.assertNotEquals(null, qb, 'Case should be inserted');
    System.assertEquals(qa.Id, qb.AccountId, 'Case should point to Account');
    System.assertEquals(qc.Id, qb.ContactId, 'Case should point to Contact');
  }

  @IsTest
  static void testUpdateMergeById_differentShapes() {
    // Seed an existing contact
    Contact seeded = new Contact(LastName = 'Seed');
    insert seeded;

    // Two separate updates for same Id with different shapes
    Contact u1 = new Contact(Id = seeded.Id, FirstName = 'Ryan');
    Contact u2 = new Contact(Id = seeded.Id, LastName = 'McCloskey');

    IWork work = Work.make();
    work.track(u1); // register update
    work.track(u2); // merge onto same Id

    Test.startTest();
    work.apply();
    Test.stopTest();

    Contact got = [
      SELECT FirstName, LastName
      FROM Contact
      WHERE Id = :seeded.Id
    ];
    System.assertEquals('Ryan', got.FirstName, 'FirstName should be merged');
    System.assertEquals('McCloskey', got.LastName, 'LastName should be merged');
  }

  @IsTest
  static void testUpdateOverwriteSameShape() {
    Contact seeded = new Contact(LastName = 'Seed');
    insert seeded;

    // Two updates with same populated field set → last one wins
    Contact u1 = new Contact(Id = seeded.Id, FirstName = 'R', LastName = 'M');
    Contact u2 = new Contact(
      Id = seeded.Id,
      FirstName = 'Ryan2',
      LastName = 'McCloskey2'
    );

    IWork work = Work.make();
    work.track(u1);
    work.track(u2); // same shape; should overwrite u1

    Test.startTest();
    work.apply();
    Test.stopTest();

    Contact got = [
      SELECT FirstName, LastName
      FROM Contact
      WHERE Id = :seeded.Id
    ];
    System.assertEquals(
      'Ryan2',
      got.FirstName,
      'FirstName should be overwritten by same-shape update'
    );
    System.assertEquals(
      'McCloskey2',
      got.LastName,
      'LastName should be overwritten by same-shape update'
    );
  }

  @IsTest
  static void testInsertDedupSameInstance() {
    IWork work = Work.make();
    Account a = new Account(Name = 'Dedup Instance');
    work.track(a);
    work.track(a); // same instance, should be ignored second time

    Test.startTest();
    work.apply();
    Test.stopTest();

    System.assertNotEquals(null, a.Id);
    Account only = [SELECT Id FROM Account WHERE Id = :a.Id];
    System.assertEquals(
      a.Id,
      only.Id,
      'Only one account should be inserted for same instance tracked twice'
    );
  }

  @IsTest
  static void testPurgeDependencyOrdering() {
    // Create parent-child account hierarchy
    Account parent = new Account(Name = 'Parent Account');
    insert parent;

    Account child = new Account(Name = 'Child Account', ParentId = parent.Id);
    insert child;

    // Verify the hierarchy was created
    System.assertNotEquals(null, parent.Id);
    System.assertNotEquals(null, child.Id);

    IWork work = Work.make();

    // Track both for purge - child should be deleted before parent
    work.purge(parent);
    work.purge(child);

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Verify both were deleted
    List<Account> remainingAccounts = [
      SELECT Id
      FROM Account
      WHERE Id IN (:parent.Id, :child.Id)
    ];
    System.assertEquals(
      0,
      remainingAccounts.size(),
      'Both accounts should be deleted'
    );
  }

  @IsTest
  static void testPurgeComplexDependencyChain() {
    // Create a chain: Account -> Contact -> Case
    Account acc = new Account(Name = 'Parent Account');
    insert acc;

    Contact con = new Contact(
      FirstName = 'John',
      LastName = 'Doe',
      AccountId = acc.Id
    );
    insert con;

    Case c = new Case(Subject = 'Test Case', ContactId = con.Id);
    insert c;

    IWork work = Work.make();

    // Track all for purge in wrong order - dependency resolution should handle it
    work.purge(acc);
    work.purge(con);
    work.purge(c);

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Verify all were deleted
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Account WHERE Id = :acc.Id],
      'Account should be deleted'
    );
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Contact WHERE Id = :con.Id],
      'Contact should be deleted'
    );
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Case WHERE Id = :c.Id],
      'Case should be deleted'
    );
  }

  @IsTest
  static void testUpsertValidation() {
    IWork work = Work.make();

    // Test null externalIdField validation
    List<Account> accounts = new List<Account>{
      new Account(Name = 'Test Account')
    };

    try {
      work.track(accounts, null);
      System.assert(
        false,
        'Should have thrown exception for null externalIdField'
      );
    } catch (Work.WorkException e) {
      System.assert(
        e.getMessage().contains('externalIdField cannot be null'),
        'Should throw appropriate error message for null externalIdField'
      );
    }

    // Test non-external ID field validation
    // AccountNumber is not marked as External ID by default
    try {
      work.track(accounts, Account.AccountNumber);
      System.assert(
        false,
        'Should have thrown exception for non-external ID field'
      );
    } catch (Work.WorkException e) {
      System.assert(
        e.getMessage()
          .contains('externalIdField must be marked as External ID'),
        'Should throw appropriate error message for non-external ID field'
      );
    }

    // Test null records handling
    work.track((List<Account>) null, Account.AccountNumber);
    System.assert(
      !work.hasWork(),
      'Should not have work for null records list'
    );

    // Test empty list handling
    work.track(new List<Account>(), Account.AccountNumber);
    System.assert(
      !work.hasWork(),
      'Should not have work for empty records list'
    );
  }

  @IsTest
  static void testDmlOptionsExposed() {
    IWork work = Work.make();

    // Verify options() returns a DmlOptions instance
    Database.DmlOptions opts = work.options();
    System.assertNotEquals(
      null,
      opts,
      'options() should return a DmlOptions instance'
    );

    // Verify we can modify the returned object
    opts.optAllOrNone = false;
    System.assertEquals(
      false,
      work.options().optAllOrNone,
      'Should be able to modify DmlOptions'
    );
  }

  @IsTest
  static void testDmlOptionsAllOrNoneTrue() {
    IWork work = Work.make();

    // Configure allOrNone = true (default behavior)
    work.options().optAllOrNone = true;

    // Create one valid and one invalid account
    List<Account> accounts = new List<Account>{
      new Account(Name = 'Valid Account'),
      new Account() // Invalid - no required fields
    };

    work.track(accounts);

    Test.startTest();
    try {
      work.apply();
      System.assert(false, 'Should have thrown exception with allOrNone=true');
    } catch (Exception e) {
      // Expected - allOrNone=true means all records must succeed
      System.assert(true, 'Exception expected with allOrNone=true');
    }
    Test.stopTest();

    // Verify no records were inserted
    List<Account> inserted = [
      SELECT Id
      FROM Account
      WHERE Name = 'Valid Account'
    ];
    System.assertEquals(
      0,
      inserted.size(),
      'No records should be inserted when allOrNone=true and one fails'
    );
  }

  @IsTest
  static void testDmlOptionsAllOrNoneFalse() {
    IWork work = Work.make();

    // Configure allOrNone = false (partial success allowed)
    work.options().optAllOrNone = false;

    // Create one valid and one invalid account
    List<Account> accounts = new List<Account>{
      new Account(Name = 'Valid Account'),
      new Account() // Invalid - no required fields
    };

    work.track(accounts);

    Test.startTest();
    work.apply(); // with allOrNone=false the invalid record fails alone; nothing throws
    Test.stopTest();

    // Verify the valid record was inserted
    List<Account> inserted = [
      SELECT Id
      FROM Account
      WHERE Name = 'Valid Account'
    ];
    System.assertEquals(
      1,
      inserted.size(),
      'Valid record should be inserted when allOrNone=false'
    );
  }

  @IsTest
  static void testDmlOptionsAllowFieldTruncation() {
    IWork work = Work.make();

    // Configure to allow field truncation
    work.options().allowFieldTruncation = true;

    // Create account with a field that would be truncated
    Account acc = new Account(Name = 'Test');
    work.track(acc);

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Verify record was inserted
    System.assertNotEquals(
      null,
      acc.Id,
      'Account should be inserted with allowFieldTruncation=true'
    );
  }

  @IsTest
  static void testSetOrderManualOrdering() {
    // Create parent and child accounts with dependency
    Account parent = new Account(Name = 'Parent Account');
    insert parent;
    Account child = new Account(Name = 'Child Account', ParentId = parent.Id);
    insert child;

    IWork work = Work.make();
    work.purge(parent);
    work.purge(child);

    // Manually set order - child before parent
    work.setOrder(new List<SObjectType>{ Account.SObjectType });

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Verify both deleted
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Account WHERE Id = :parent.Id],
      'Parent should be deleted'
    );
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Account WHERE Id = :child.Id],
      'Child should be deleted'
    );
  }

  @IsTest
  static void testSetOrderWithMultipleTypes() {
    // Create Account -> Contact -> Case chain
    Account acc = new Account(Name = 'Test Account');
    insert acc;
    Contact con = new Contact(
      FirstName = 'John',
      LastName = 'Doe',
      AccountId = acc.Id
    );
    insert con;
    Case c = new Case(Subject = 'Test Case', ContactId = con.Id);
    insert c;

    IWork work = Work.make();
    work.purge(acc);
    work.purge(con);
    work.purge(c);

    // Set explicit order: Case -> Contact -> Account
    work.setOrder(
      new List<SObjectType>{
        Case.SObjectType,
        Contact.SObjectType,
        Account.SObjectType
      }
    );

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Verify all deleted
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Account WHERE Id = :acc.Id],
      'Account should be deleted'
    );
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Contact WHERE Id = :con.Id],
      'Contact should be deleted'
    );
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Case WHERE Id = :c.Id],
      'Case should be deleted'
    );
  }

  @IsTest
  static void testSetOrderIncompleteValidation() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;
    Contact con = new Contact(
      FirstName = 'John',
      LastName = 'Doe',
      AccountId = acc.Id
    );
    insert con;

    IWork work = Work.make();
    work.purge(acc);
    work.purge(con);

    // Set order but only include Account, missing Contact
    work.setOrder(new List<SObjectType>{ Account.SObjectType });

    Test.startTest();
    try {
      work.apply();
      System.assert(false, 'Should have thrown exception for incomplete order');
    } catch (Work.WorkException e) {
      System.assert(
        e.getMessage().contains('Purge order is incomplete'),
        'Should throw error about incomplete order: ' + e.getMessage()
      );
      System.assert(
        e.getMessage().contains('Contact'),
        'Error should mention missing Contact type: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testSetOrderChainable() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    IWork work = Work.make();

    // Verify setOrder is chainable
    IWork chainedWork = work
      .purge(acc)
      .setOrder(new List<SObjectType>{ Account.SObjectType });

    System.assertNotEquals(
      null,
      chainedWork,
      'setOrder should return IWork for chaining'
    );

    Test.startTest();
    chainedWork.apply();
    Test.stopTest();

    System.assertEquals(
      0,
      [SELECT COUNT() FROM Account WHERE Id = :acc.Id],
      'Account should be deleted'
    );
  }

  @IsTest
  static void testSetOrderNullOrEmptyUsesAutomaticOrdering() {
    // Create parent and child accounts
    Account parent = new Account(Name = 'Parent Account');
    insert parent;
    Account child = new Account(Name = 'Child Account', ParentId = parent.Id);
    insert child;

    // Test null order - should use automatic ordering
    IWork work1 = Work.make();
    work1.purge(parent);
    work1.purge(child);
    work1.setOrder(null);

    Test.startTest();
    work1.apply(); // Should succeed with automatic ordering
    Test.stopTest();

    System.assertEquals(
      0,
      [SELECT COUNT() FROM Account],
      'All accounts should be deleted'
    );

    // Test empty list - should also use automatic ordering
    Account parent2 = new Account(Name = 'Parent Account 2');
    insert parent2;
    Account child2 = new Account(
      Name = 'Child Account 2',
      ParentId = parent2.Id
    );
    insert child2;

    IWork work2 = Work.make();
    work2.purge(parent2);
    work2.purge(child2);
    work2.setOrder(new List<SObjectType>());

    work2.apply(); // Should succeed with automatic ordering

    System.assertEquals(
      0,
      [SELECT COUNT() FROM Account],
      'All accounts should be deleted'
    );
  }

  @IsTest
  static void testTrackNullList() {
    IWork work = Work.make();

    // Test tracking null list
    work.track((List<Account>) null);

    System.assert(!work.hasWork(), 'Should not have work for null list');
  }

  @IsTest
  static void testPurgeNullRecord() {
    IWork work = Work.make();

    // Test purging null record - should not throw, just ignore
    work.purge((Account) null);

    System.assert(!work.hasWork(), 'Should not have work for null purge');
  }

  @IsTest
  static void testTrackNullEmail() {
    IWork work = Work.make();

    // Test tracking null email - should not throw, just ignore
    work.track((Messaging.Email) null);

    System.assert(!work.hasWork(), 'Should not have work for null email');
  }

  @IsTest
  static void testTrackNullEmailList() {
    IWork work = Work.make();

    // Test tracking null email list
    work.track((List<Messaging.Email>) null);

    System.assert(!work.hasWork(), 'Should not have work for null email list');
  }

  @IsTest
  static void testConstructorWithNullScheme() {
    // Test Work constructor with null scheme - should use default
    Work work = new Work(null);

    System.assertNotEquals(
      null,
      work,
      'Work should be created with default scheme'
    );
    System.assertNotEquals(
      null,
      work.options(),
      'DmlOptions should be initialized'
    );
  }

  @IsTest
  static void testDefaultConstructor() {
    // Test Work default constructor
    Work work = new Work();

    System.assertNotEquals(null, work, 'Work should be created');
    System.assertNotEquals(
      null,
      work.options(),
      'DmlOptions should be initialized'
    );
    System.assertEquals(
      true,
      work.options().optAllOrNone,
      'Default optAllOrNone should be true'
    );
  }

  @IsTest
  static void testTrackEmailList() {
    IWork work = Work.make();

    // Track multiple emails
    List<Messaging.Email> emails = new List<Messaging.Email>();
    for (Integer i = 0; i < 3; i++) {
      Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
      email.setToAddresses(new List<String>{ 'test' + i + '@example.com' });
      email.setSubject('Test ' + i);
      email.setPlainTextBody('Body ' + i);
      emails.add(email);
    }

    work.track(emails);
    System.assert(work.hasWork(), 'Should have work for email list');

    Test.startTest();
    work.apply();
    Test.stopTest();
    // Emails sent (in test context they don't actually send but no error)
  }

  @IsTest
  static void testUpdateMergeSameInstanceTwice() {
    // Test that tracking the same instance twice doesn't duplicate it
    Account acc = new Account(Name = 'Test');
    insert acc;

    IWork work = Work.make();
    acc.Name = 'Updated';
    work.track(acc);
    work.track(acc); // Same instance - should return early on line 220

    Test.startTest();
    work.apply();
    Test.stopTest();

    Account updated = [SELECT Name FROM Account WHERE Id = :acc.Id];
    System.assertEquals('Updated', updated.Name);
  }

  @IsTest
  static void testHasWorkVariations() {
    IWork work = Work.make();

    // Test hasWork returns false when empty
    System.assert(!work.hasWork(), 'Should not have work initially');

    // Add work of various types
    Account acc = new Account(Name = 'Test');
    work.track(acc);
    System.assert(work.hasWork(), 'Should have work after tracking record');
  }

  @IsTest
  static void testCircularDependencyInPurge() {
    // Note: In a real scenario, circular dependencies in SF are prevented by the platform
    // But we can test that our topological sort handles visiting/visited correctly
    Account acc1 = new Account(Name = 'Account 1');
    Account acc2 = new Account(Name = 'Account 2');
    insert new List<Account>{ acc1, acc2 };

    IWork work = Work.make();
    work.purge(acc1);
    work.purge(acc2);

    Test.startTest();
    work.apply(); // Should handle without circular dependency issues
    Test.stopTest();

    System.assertEquals(
      0,
      [SELECT COUNT() FROM Account WHERE Id IN (:acc1.Id, :acc2.Id)],
      'Both accounts should be deleted'
    );
  }

  @IsTest
  static void testNoWorkToApply() {
    IWork work = Work.make();

    // No records tracked
    System.assert(!work.hasWork(), 'Should not have work');

    Test.startTest();
    work.apply(); // Should return immediately without error
    Test.stopTest();

    // No assertions needed - just verify it doesn't throw
  }

  @IsTest
  static void testRelateNullRelatedToField() {
    IWork work = Work.make();
    Account acc = new Account(Name = 'Test');
    Contact con = new Contact(FirstName = 'Test', LastName = 'Contact');

    try {
      work.track(con, null, acc);
      System.assert(false, 'Should throw exception for null relatedToField');
    } catch (Work.WorkException e) {
      System.assert(e.getMessage().contains('relatedToField cannot be null'));
    }
  }

  @IsTest
  static void testTrackWithRelationshipExternalIdChaining() {
    // Test the track(record, relatedToField, externalIdField, externalId) method
    // This should call track() then relate() and return this for chaining
    IWork work = Work.make();
    Account acc = new Account(Name = 'Test');
    Contact con = new Contact(FirstName = 'Test', LastName = 'Contact');

    work.track(acc);

    // Try to track with external ID relationship (will fail validation, but tests the code path)
    try {
      work.track(con, Contact.AccountId, Account.AccountNumber, 'TEST001');
      System.assert(false, 'Should throw for non-external ID field');
    } catch (Work.WorkException e) {
      // Expected - AccountNumber is not an external ID
      System.assert(
        e.getMessage().contains('externalIdField must be marked as External ID')
      );
    }
  }

  // ========== USAGE PATTERNS ==========

  @IsTest
  static void testMultipleWorkInstancesInTransaction() {
    // Pattern: Creating multiple IWork instances and calling apply() separately
    Account acc1 = new Account(Name = 'Account 1');
    Account acc2 = new Account(Name = 'Account 2');

    Test.startTest();

    // First work unit
    IWork work1 = Application.s.work();
    work1.track(acc1);
    work1.apply();

    System.assertNotEquals(null, acc1.Id, 'First account should be inserted');

    // Second work unit in same transaction
    IWork work2 = Application.s.work();
    acc2.Name = 'Account 2 Updated';
    work2.track(acc2);
    acc1.Name = 'Account 1 Updated'; // Update record from first work unit
    work2.track(acc1);
    work2.apply();

    Test.stopTest();

    Account fetchedAcc1 = [SELECT Name FROM Account WHERE Id = :acc1.Id];
    Account fetchedAcc2 = [SELECT Name FROM Account WHERE Id = :acc2.Id];
    System.assertEquals(
      'Account 1 Updated',
      fetchedAcc1.Name,
      'First account should be updated by second work unit'
    );
    System.assertEquals(
      'Account 2 Updated',
      fetchedAcc2.Name,
      'Second account should be inserted'
    );
  }

  @IsTest
  static void testEmailWithAttachments() {
    // Pattern: Sending emails with file attachments
    IWork work = Application.s.work();

    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setToAddresses(new List<String>{ 'test@example.com' });
    email.setSubject('Test with Attachment');
    email.setPlainTextBody('Test Body');

    // Add file attachment
    Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
    attachment.setFileName('test.txt');
    attachment.setBody(Blob.valueOf('Test content'));
    attachment.setContentType('text/plain');
    email.setFileAttachments(
      new List<Messaging.EmailFileAttachment>{ attachment }
    );

    work.track(email);

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Email sent successfully (not actually sent in test context)
    System.assert(true, 'Email with attachment should be tracked and applied');
  }

  @IsTest
  static void testBulkEmailTracking() {
    // Pattern: Tracking multiple emails in bulk
    IWork work = Application.s.work();

    List<Messaging.Email> emails = new List<Messaging.Email>();
    for (Integer i = 0; i < 10; i++) {
      Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
      email.setToAddresses(new List<String>{ 'test' + i + '@example.com' });
      email.setSubject('Bulk Email ' + i);
      email.setPlainTextBody('Body ' + i);
      emails.add(email);
    }

    work.track(emails);

    Test.startTest();
    work.apply();
    Test.stopTest();

    System.assert(true, 'Multiple emails should be sent successfully');
  }

  @IsTest
  static void testLargeScaleInserts() {
    // Pattern: Tracking many records at once
    IWork work = Application.s.work();

    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < 100; i++) {
      accounts.add(new Account(Name = 'Bulk Account ' + i));
    }

    work.track(accounts);

    Test.startTest();
    work.apply();
    Test.stopTest();

    List<Account> inserted = [
      SELECT Id, Name
      FROM Account
      WHERE Name LIKE 'Bulk Account%'
      ORDER BY Name
    ];
    System.assertEquals(
      100,
      inserted.size(),
      'All 100 accounts should be inserted'
    );
  }

  @IsTest
  static void testMixedInsertsUpdatesInSameWork() {
    // Pattern: Mixing inserts and updates in the same work unit
    Account existingAcc = new Account(Name = 'Existing Account');
    insert existingAcc;

    IWork work = Application.s.work();

    // Track new account (insert)
    Account newAcc = new Account(Name = 'New Account');
    work.track(newAcc);

    // Track existing account (update)
    existingAcc.Name = 'Updated Existing Account';
    work.track(existingAcc);

    // Track contact with relationship to new account
    Contact newCon = new Contact(FirstName = 'John', LastName = 'Doe');
    work.track(newCon, Contact.AccountId, newAcc);

    Test.startTest();
    work.apply();
    Test.stopTest();

    Account fetchedNew = [SELECT Name FROM Account WHERE Id = :newAcc.Id];
    Account fetchedExisting = [
      SELECT Name
      FROM Account
      WHERE Id = :existingAcc.Id
    ];
    Contact fetchedCon = [
      SELECT AccountId
      FROM Contact
      WHERE Id = :newCon.Id
    ];

    System.assertEquals('New Account', fetchedNew.Name);
    System.assertEquals('Updated Existing Account', fetchedExisting.Name);
    System.assertEquals(
      newAcc.Id,
      fetchedCon.AccountId,
      'Contact should be linked to new account'
    );
  }

  @IsTest
  static void testRelationshipTrackingPattern() {
    // Pattern: track(child, field, parent) where parent is also tracked separately
    IWork work = Application.s.work();

    Account acc = new Account(Name = 'Parent Account');
    Contact con1 = new Contact(FirstName = 'John', LastName = 'Doe');
    Contact con2 = new Contact(FirstName = 'Jane', LastName = 'Smith');

    // Track parent
    work.track(acc);

    // Track children with relationships
    work.track(con1, Contact.AccountId, acc);
    work.track(con2, Contact.AccountId, acc);

    Test.startTest();
    work.apply();
    Test.stopTest();

    List<Contact> contacts = [
      SELECT Id, AccountId
      FROM Contact
      WHERE Id IN (:con1.Id, :con2.Id)
    ];
    System.assertEquals(2, contacts.size(), 'Both contacts should be inserted');
    for (Contact con : contacts) {
      System.assertEquals(
        acc.Id,
        con.AccountId,
        'Contact should be linked to account'
      );
    }
  }

  @IsTest
  static void testComplexBulkRelationships() {
    // Pattern: Many children linked to many parents
    IWork work = Application.s.work();

    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < 5; i++) {
      accounts.add(new Account(Name = 'Account ' + i));
    }

    List<Contact> contacts = new List<Contact>();
    for (Integer i = 0; i < 5; i++) {
      for (Integer j = 0; j < 3; j++) {
        Contact con = new Contact(
          FirstName = 'Contact',
          LastName = i + '-' + j
        );
        work.track(con, Contact.AccountId, accounts[i]);
        contacts.add(con);
      }
    }

    Test.startTest();
    work.apply();
    Test.stopTest();

    System.assertEquals(
      15,
      [SELECT COUNT() FROM Contact],
      '15 contacts should be created (5 accounts × 3 contacts)'
    );
    System.assertEquals(
      5,
      [SELECT COUNT() FROM Account],
      '5 accounts should be created'
    );

    // Verify relationships
    Map<Id, Integer> contactsPerAccount = new Map<Id, Integer>();
    for (AggregateResult row : [SELECT AccountId, COUNT(Id) total FROM Contact GROUP BY AccountId]) {
      contactsPerAccount.put((Id) row.get('AccountId'), (Integer) row.get('total'));
    }
    for (Account account : accounts) {
      Assert.areEqual(3, contactsPerAccount.get(account.Id), 'Each account should have 3 contacts');
    }
  }

  @IsTest
  static void testUpdateWithPartialFieldSets() {
    // Pattern: Multiple updates to same record with different field sets should merge
    Contact seeded = new Contact(
      FirstName = 'Original',
      LastName = 'Name',
      Email = 'original@example.com'
    );
    insert seeded;

    IWork work = Application.s.work();

    // Update 1: Change first name only
    Contact u1 = new Contact(Id = seeded.Id, FirstName = 'Updated');

    // Update 2: Change last name only
    Contact u2 = new Contact(Id = seeded.Id, LastName = 'NewName');

    // Update 3: Change email only
    Contact u3 = new Contact(Id = seeded.Id, Email = 'new@example.com');

    work.track(u1);
    work.track(u2);
    work.track(u3);

    Test.startTest();
    work.apply();
    Test.stopTest();

    Contact result = [
      SELECT FirstName, LastName, Email
      FROM Contact
      WHERE Id = :seeded.Id
    ];
    System.assertEquals('Updated', result.FirstName, 'FirstName should merge');
    System.assertEquals('NewName', result.LastName, 'LastName should merge');
    System.assertEquals('new@example.com', result.Email, 'Email should merge');
  }

  @IsTest
  static void testEmptyListHandling() {
    // Pattern: callers often pass empty lists straight through
    IWork work = Application.s.work();

    work.track(new List<Account>());
    work.purge(new List<Account>());
    work.track(new List<Messaging.Email>());

    System.assert(!work.hasWork(), 'Empty lists should not create work');

    Test.startTest();
    work.apply(); // Should not throw
    Test.stopTest();
  }

  @IsTest
  static void testPurgeWithQueryResults() {
    // Pattern: Purging records from query results
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < 5; i++) {
      accounts.add(new Account(Name = 'Purge Test ' + i));
    }
    insert accounts;

    IWork work = Application.s.work();

    // Query and purge
    List<Account> toDelete = [
      SELECT Id
      FROM Account
      WHERE Name LIKE 'Purge Test%'
    ];
    work.purge(toDelete);

    Test.startTest();
    work.apply();
    Test.stopTest();

    List<Account> remaining = [
      SELECT Id
      FROM Account
      WHERE Name LIKE 'Purge Test%'
    ];
    System.assertEquals(
      0,
      remaining.size(),
      'All queried accounts should be purged'
    );
  }

  @IsTest
  static void testSameRecordTrackedMultipleTimesAcrossRelationships() {
    // Pattern: Same parent record tracked in multiple relationship calls
    IWork work = Application.s.work();

    Account acc = new Account(Name = 'Shared Account');
    Contact con1 = new Contact(FirstName = 'Contact', LastName = '1');
    Contact con2 = new Contact(FirstName = 'Contact', LastName = '2');

    // Track account explicitly
    work.track(acc);

    // Track contacts with relationships (account gets implicitly tracked again)
    work.track(con1, Contact.AccountId, acc);
    work.track(con2, Contact.AccountId, acc);

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Should only insert account once despite multiple track calls
    List<Account> accounts = [
      SELECT Id
      FROM Account
      WHERE Name = 'Shared Account'
    ];
    System.assertEquals(
      1,
      accounts.size(),
      'Account should only be inserted once'
    );

    List<Contact> contacts = [
      SELECT AccountId
      FROM Contact
      WHERE AccountId = :acc.Id
    ];
    System.assertEquals(
      2,
      contacts.size(),
      'Both contacts should be linked to same account'
    );
  }

  @IsTest
  static void testWorkWithNoRecordsButHasEmails() {
    // Pattern: Work that only contains emails, no DML
    IWork work = Application.s.work();

    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setToAddresses(new List<String>{ 'test@example.com' });
    email.setSubject('Test');
    email.setPlainTextBody('Body');

    work.track(email);

    System.assert(work.hasWork(), 'Work should have pending work (email)');

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Email tracked successfully
    System.assert(true, 'Should apply successfully with only emails');
  }

  @IsTest
  static void testDmlOptionsWithPartialSuccess() {
    // Pattern: Using allOrNone=false for partial success scenarios
    IWork work = Application.s.work();
    work.options().optAllOrNone = false;

    List<Account> accounts = new List<Account>{
      new Account(Name = 'Valid 1'),
      new Account(Name = 'Valid 2')
    };

    work.track(accounts);

    Test.startTest();
    work.apply();
    Test.stopTest();

    List<Account> inserted = [
      SELECT Id
      FROM Account
      WHERE Name IN ('Valid 1', 'Valid 2')
    ];
    System.assertEquals(
      2,
      inserted.size(),
      'Both valid accounts should be inserted'
    );
  }

  @IsTest
  static void testChainedRelationshipsThreeLevels() {
    // Pattern: Account -> Contact -> Case chain
    IWork work = Application.s.work();

    Account acc = new Account(Name = 'Top Level');
    Contact con = new Contact(FirstName = 'Middle', LastName = 'Level');
    Case cas = new Case(Subject = 'Bottom Level');

    work.track(con, Contact.AccountId, acc);
    work.track(cas, Case.ContactId, con);

    Test.startTest();
    work.apply();
    Test.stopTest();

    Case fetchedCase = [
      SELECT Id, ContactId, Contact.AccountId
      FROM Case
      WHERE Id = :cas.Id
    ];
    System.assertEquals(
      con.Id,
      fetchedCase.ContactId,
      'Case should link to Contact'
    );
    System.assertEquals(
      acc.Id,
      fetchedCase.Contact.AccountId,
      'Contact should link to Account'
    );
  }

  @IsTest
  static void testUpdateMergeWithNullValues() {
    // Pattern: Ensure null values in updates don't overwrite existing data
    Account acc = new Account(
      Name = 'Test',
      Phone = '555-1234',
      Website = 'example.com'
    );
    insert acc;

    IWork work = Application.s.work();

    // Update 1: Set name, leave other fields null
    Account u1 = new Account(Id = acc.Id, Name = 'Updated Name');

    // Update 2: Set phone, leave other fields null
    Account u2 = new Account(Id = acc.Id, Phone = '555-5678');

    work.track(u1);
    work.track(u2);

    Test.startTest();
    work.apply();
    Test.stopTest();

    Account result = [
      SELECT Name, Phone, Website
      FROM Account
      WHERE Id = :acc.Id
    ];
    System.assertEquals('Updated Name', result.Name);
    System.assertEquals('555-5678', result.Phone);
    System.assertEquals(
      'example.com',
      result.Website,
      'Website should remain unchanged'
    );
  }

  @IsTest
  static void testImplicitParentTrackingViaRelationship() {
    // Pattern: Parent is NOT explicitly tracked, only children with relationships
    // The parent is never tracked itself, but must be inserted before its children
    IWork work = Application.s.work();

    // Create new parent (like an order)
    Account parent = new Account(Name = 'Implicit Parent');

    // Create multiple children (like its order items)
    Contact child1 = new Contact(FirstName = 'Child', LastName = '1');
    Contact child2 = new Contact(FirstName = 'Child', LastName = '2');
    Contact child3 = new Contact(FirstName = 'Child', LastName = '3');

    // CRITICAL: Only track children with relationships - parent is NOT explicitly tracked
    // As in: work.track(item, OrderItem.OrderId, order)
    work.track(child1, Contact.AccountId, parent);
    work.track(child2, Contact.AccountId, parent);
    work.track(child3, Contact.AccountId, parent);

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Verify parent was implicitly tracked and inserted
    System.assertNotEquals(
      null,
      parent.Id,
      'Parent should be inserted even though not explicitly tracked'
    );

    // Verify all children were inserted with correct relationships
    List<Contact> children = [
      SELECT Id, AccountId
      FROM Contact
      WHERE AccountId = :parent.Id
      ORDER BY LastName
    ];
    System.assertEquals(
      3,
      children.size(),
      'All 3 children should be inserted'
    );
    for (Contact child : children) {
      System.assertEquals(
        parent.Id,
        child.AccountId,
        'Child should be linked to parent'
      );
    }
  }

  @IsTest
  static void testImplicitParentWithEmptyChildList() {
    // Pattern: Parent referenced in relationship loop, but loop produces no children
    // e.g. a lookup for template children that comes back empty
    // The relationship call never runs, but the parent is still tracked explicitly
    IWork work = Application.s.work();

    // Simulate a parent that finds no children
    Account parent1 = new Account(Name = 'Order with No Items');
    List<Contact> emptyChildren = new List<Contact>(); // Like a lookup that returns no rows

    // Simulate the loop over the children
    for (Contact child : emptyChildren) {
      // This line never executes because list is empty
      work.track(child, Contact.AccountId, parent1);
    }

    // But we still add the parent to a collection
    List<Account> parents = new List<Account>();
    parents.add(parent1);

    // And explicitly track it
    work.track(parents);

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Verify parent was inserted even though no children were tracked
    System.assertNotEquals(
      null,
      parent1.Id,
      'Parent should be inserted via explicit track even with no children'
    );

    List<Account> inserted = [
      SELECT Id, Name
      FROM Account
      WHERE Name = 'Order with No Items'
    ];
    System.assertEquals(1, inserted.size(), 'Parent should be inserted');
  }

  @IsTest
  static void testOrderItemPattern_WithAndWithoutItems() {
    // Pattern: parents with children and parents without, tracked together
    // Tests both cases: Orders with OrderItems AND Orders without OrderItems
    IWork work = Application.s.work();

    // Simulate 2 Orders being created
    Account order1 = new Account(Name = 'Order 1 - Has Items');
    Account order2 = new Account(Name = 'Order 2 - No Items');

    // Simulate Order 1 finding template items
    List<Contact> items1 = new List<Contact>{
      new Contact(FirstName = 'Item', LastName = '1A'),
      new Contact(FirstName = 'Item', LastName = '1B')
    };

    // Simulate Order 2 finding NO template items
    List<Contact> items2 = new List<Contact>();

    // Track Order 1's items (implicit parent tracking)
    for (Contact item : items1) {
      work.track(item, Contact.AccountId, order1);
    }

    // Track Order 2's items (loop doesn't execute)
    for (Contact item : items2) {
      work.track(item, Contact.AccountId, order2);
    }

    // Collect all orders for explicit tracking
    List<Account> allOrders = new List<Account>{ order1, order2 };

    // Explicitly track the orders
    work.track(allOrders);

    Test.startTest();
    work.apply();
    Test.stopTest();

    // Verify both orders were inserted
    System.assertNotEquals(null, order1.Id, 'Order 1 should be inserted');
    System.assertNotEquals(null, order2.Id, 'Order 2 should be inserted');

    // Verify Order 1 has 2 items
    List<Contact> order1Items = [
      SELECT Id
      FROM Contact
      WHERE AccountId = :order1.Id
    ];
    System.assertEquals(2, order1Items.size(), 'Order 1 should have 2 items');

    // Verify Order 2 has 0 items
    List<Contact> order2Items = [
      SELECT Id
      FROM Contact
      WHERE AccountId = :order2.Id
    ];
    System.assertEquals(0, order2Items.size(), 'Order 2 should have 0 items');

    // Both orders should exist in database
    List<Account> allInsertedOrders = [
      SELECT Id, Name
      FROM Account
      WHERE Name LIKE 'Order%'
      ORDER BY Name
    ];
    System.assertEquals(
      2,
      allInsertedOrders.size(),
      'Both orders should be inserted'
    );
  }

  // --- New records are tracked by identity, not by value -------------------------------------------

  @IsTest
  static void equalNewRecordsAreBothInserted() {
    IWork work = Work.make();
    work.track(new Account(Name = 'Twin'));
    work.track(new Account(Name = 'Twin'));

    work.apply();

    Assert.areEqual(2, [SELECT COUNT() FROM Account WHERE Name = 'Twin'], 'equal values, two records');
  }

  @IsTest
  static void aParentSharedByTwoChildrenIsInsertedOnce() {
    Account shared = new Account(Name = 'Shared parent');
    IWork work = Work.make();
    work.track(new Contact(LastName = 'One'), Contact.AccountId, shared);
    work.track(new Contact(LastName = 'Two'), Contact.AccountId, shared);

    work.apply();

    Assert.areEqual(1, [SELECT COUNT() FROM Account WHERE Name = 'Shared parent']);
    Assert.areEqual(2, [SELECT COUNT() FROM Contact WHERE AccountId = :shared.Id]);
  }

  @IsTest
  static void aChildWithTwoNewParentsGetsBothLookups() {
    Account company = new Account(Name = 'Company');
    Contact boss = new Contact(LastName = 'Boss');
    Contact worker = new Contact(LastName = 'Worker');
    IWork work = Work.make();
    work.track(worker, Contact.AccountId, company);
    work.track(worker, Contact.ReportsToId, boss);

    work.apply();

    Contact saved = [SELECT AccountId, ReportsToId FROM Contact WHERE Id = :worker.Id];
    Assert.areEqual(company.Id, saved.AccountId);
    Assert.areEqual(boss.Id, saved.ReportsToId);
  }

  @IsTest
  static void aRequiredLookupToAnExistingParentIsFilledBeforeInsert() {
    Case ticket = new Case(Subject = 'Existing');
    insert ticket;
    CaseComment note = new CaseComment(CommentBody = 'Filled before insert');
    IWork work = Work.make();
    work.track(note, CaseComment.ParentId, ticket);

    work.apply();

    Assert.areEqual(ticket.Id, [SELECT ParentId FROM CaseComment WHERE Id = :note.Id].ParentId);
  }

  @IsTest
  static void newRecordsThatDependOnEachOtherAreRejected() {
    Account first = new Account(Name = 'First');
    Account second = new Account(Name = 'Second');
    IWork work = Work.make();
    work.track(first, Account.ParentId, second);
    work.track(second, Account.ParentId, first);

    try {
      work.apply();
      Assert.fail('a cycle has no insert order');
    } catch (Work.WorkException expected) {
      Assert.isTrue(expected.getMessage().contains('cycle'), expected.getMessage());
    }
  }

  // Partial success

  private static IWork partialWork() {
    IWork work = Work.make();
    work.options().optAllOrNone = false;
    return work;
  }

  @IsTest
  static void partialSuccessReportsEachRecordThatWasNotSaved() {
    Account good = new Account(Name = 'Saved');
    Account bad = new Account();
    IWork work = partialWork();
    Assert.isTrue(work.failures().isEmpty(), 'nothing has been tried yet');
    work.track(new List<Account>{ good, bad });

    work.apply();

    Assert.isNotNull(good.Id);
    Assert.isNull(bad.Id);
    List<IWorkFailure> failures = work.failures();
    Assert.areEqual(1, failures.size());
    Assert.isTrue(failures[0].getRecord() === bad, 'the instance that was tracked');
    Assert.areEqual(1, failures[0].getErrors().size());
    Assert.areEqual(StatusCode.REQUIRED_FIELD_MISSING, failures[0].getErrors()[0].getStatusCode());
    Assert.areEqual(failures[0].getErrors()[0].getMessage(), failures[0].getMessage());
    Assert.isTrue(failures[0].getMessage().contains('Name'), failures[0].getMessage());
    Assert.isNull(work.failureOf(good));
    Assert.isTrue(work.failureOf(bad) === failures[0]);
    Assert.isNull(work.failureOf(null));
  }

  @IsTest
  static void failuresAreToldApartByInstanceNotByValue() {
    Account first = new Account();
    Account second = new Account();
    IWork work = partialWork();
    work.track(first).track(second);

    work.apply();

    Assert.areEqual(2, work.failures().size(), 'two records that look alike are two records');
    Assert.isTrue(work.failureOf(first).getRecord() === first);
    Assert.isTrue(work.failureOf(second).getRecord() === second);
    Assert.isNull(work.failureOf(new Account()), 'a record that only looks like them was never tracked');
  }

  @IsTest
  static void aChildOfANewParentThatFailedIsHeldBackWithIt() {
    Account lost = new Account();
    Contact child = new Contact(LastName = 'Held Child');
    Case grandchild = new Case(Subject = 'Held Grandchild');
    Account kept = new Account(Name = 'Kept');
    Contact keptChild = new Contact(LastName = 'Kept Child');
    IWork work = partialWork();
    work.track(child, Contact.AccountId, lost);
    work.track(grandchild, Case.ContactId, child);
    work.track(keptChild, Contact.AccountId, kept);

    work.apply();

    Assert.isNull(child.Id, 'not inserted without its parent');
    Assert.isNull(grandchild.Id);
    Assert.areEqual(0, [SELECT COUNT() FROM Contact WHERE LastName = 'Held Child']);
    Assert.areEqual(3, work.failures().size());
    Assert.areEqual(1, work.failureOf(lost).getErrors().size(), 'the platform refused the parent');
    Assert.areEqual('Not saved: the Account it is related to was not saved', work.failureOf(child).getMessage());
    Assert.isTrue(work.failureOf(child).getErrors().isEmpty(), 'the work held it back; the platform never saw it');
    Assert.areEqual('Not saved: the Contact it is related to was not saved', work.failureOf(grandchild).getMessage());
    Assert.areEqual(kept.Id, [SELECT AccountId FROM Contact WHERE Id = :keptChild.Id].AccountId, 'the others are saved as usual');
  }

  @IsTest
  static void anExistingRecordRelatedToANewParentThatFailedIsLeftAsItIs() {
    Contact existing = new Contact(LastName = 'Before');
    insert existing;
    existing.LastName = 'After';
    Account lost = new Account();
    IWork work = partialWork();
    work.track(existing, Contact.AccountId, lost);

    work.apply();

    Contact stored = [SELECT LastName, AccountId FROM Contact WHERE Id = :existing.Id];
    Assert.areEqual('Before', stored.LastName, 'none of its changes are saved, not half of them');
    Assert.isNull(stored.AccountId);
    Assert.areEqual(2, work.failures().size());
    Assert.areEqual('Not saved: the Account it is related to was not saved', work.failureOf(existing).getMessage());
  }

  @IsTest
  static void aFailedUpdateAndAFailedDeleteAreReported() {
    Account renamed = new Account(Name = 'Renamed');
    Account gone = new Account(Name = 'Gone');
    Account fine = new Account(Name = 'Fine');
    insert new List<Account>{ renamed, gone, fine };
    delete gone;
    Account blanked = new Account(Id = renamed.Id, Name = null);
    Account changed = new Account(Id = fine.Id, Name = 'Changed');
    IWork work = partialWork();
    work.track(blanked).track(changed).purge(gone);

    work.apply();

    Assert.areEqual(2, work.failures().size(), String.valueOf(work.failures()));
    Assert.isNotNull(work.failureOf(blanked));
    Assert.isNotNull(work.failureOf(gone));
    Assert.isTrue(String.isNotBlank(work.failureOf(gone).getMessage()));
    Assert.isNull(work.failureOf(changed));
    Assert.areEqual('Changed', [SELECT Name FROM Account WHERE Id = :fine.Id].Name);
    Assert.areEqual('Renamed', [SELECT Name FROM Account WHERE Id = :renamed.Id].Name);
  }

  @IsTest
  static void allOrNoneThrowsAndLeavesNothingToReport() {
    IWork work = Work.make();
    work.track(new Account());

    try {
      work.apply();
      Assert.fail('all or none throws on the first failure');
    } catch (DmlException expected) {
      Assert.isTrue(work.failures().isEmpty(), 'failures are for partial success');
    }
  }
}
