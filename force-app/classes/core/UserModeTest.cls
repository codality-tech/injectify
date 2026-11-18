/**
 * Queries, searches and units of work run as a user who is not an administrator: what user mode
 * (withSharing(true)) enforces, and what system mode leaves alone.
 *
 * The users are made on the Minimum Access profile and given exactly the access a test names
 * through a permission set. Records are owned by that user, so the tests do not depend on the
 * org's sharing defaults.
 */
@IsTest
private class UserModeTest {
  private static User userWith(ObjectPermissions onAccount, Map<String, Boolean> editByField) {
    User made = new User(
      ProfileId = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1].Id,
      LastName = 'Restricted',
      Alias = 'rstrctd',
      Email = 'restricted@usermode.example.com',
      Username = 'restricted.' + UserInfo.getOrganizationId() + '.' + System.now().getTime() + '@usermode.example.com',
      TimeZoneSidKey = 'GMT',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    // Users and permission sets are setup objects: saved as another "user" so records can be saved afterwards.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert made;
      PermissionSet granted = new PermissionSet(Name = 'User_Mode_Test', Label = 'User Mode Test');
      insert granted;
      onAccount.ParentId = granted.Id;
      onAccount.SobjectType = 'Account';
      insert onAccount;
      List<FieldPermissions> fields = new List<FieldPermissions>();
      for (String fieldName : editByField.keySet()) {
        fields.add(
          new FieldPermissions(
            ParentId = granted.Id,
            SobjectType = 'Account',
            Field = 'Account.' + fieldName,
            PermissionsRead = true,
            PermissionsEdit = editByField.get(fieldName)
          )
        );
      }
      insert fields;
      insert new PermissionSetAssignment(AssigneeId = made.Id, PermissionSetId = granted.Id);
    }
    return made;
  }

  private static User reader() {
    return userWith(new ObjectPermissions(PermissionsRead = true), new Map<String, Boolean>{ 'Industry' => false });
  }

  private static User editor() {
    return userWith(
      new ObjectPermissions(PermissionsRead = true, PermissionsCreate = true, PermissionsEdit = true),
      new Map<String, Boolean>{ 'Industry' => true, 'Rating' => false }
    );
  }

  private static Account acmeOwnedBy(User owner) {
    Account made = new Account(Name = 'Acme', Industry = 'Energy', Rating = 'Hot', OwnerId = owner.Id);
    insert made;
    return made;
  }

  // The type of the exception applying the work throws, or null when it goes through.
  private static String refusal(IWork work) {
    try {
      work.apply();
    } catch (Exception refused) {
      return refused.getTypeName() + ': ' + refused.getMessage();
    }
    return null;
  }

  // --- queries --------------------------------------------------------------------------------

  @IsTest
  static void defaultFieldsTheUserCannotReadAreLeftOutInUserMode() {
    User reader = reader();
    acmeOwnedBy(reader);

    System.runAs(reader) {
      IQuery asUser = Application.s.qf().make(Account.SObjectType).withSharing(true);

      String soql = asUser.toSoql();
      Assert.isTrue(soql.contains('Industry'), soql);
      Assert.isFalse(soql.contains('Rating'), 'a default the user cannot read: ' + soql);
      Assert.isFalse(soql.contains('AnnualRevenue'), soql);
      Assert.areEqual(soql, asUser.deepClone().toSoql(), 'a copy knows its defaults too');

      List<Account> rows = (List<Account>) asUser.run();
      Assert.areEqual(1, rows.size());
      Assert.areEqual('Energy', rows[0].Industry);
      Assert.isFalse(rows[0].isSet(Account.Rating));
      Assert.areEqual(1, asUser.count());

      // System mode is untouched: every default is selected, and read.
      IQuery asSystem = Application.s.qf().make(Account.SObjectType);
      Assert.isTrue(asSystem.toSoql().contains('Rating'), asSystem.toSoql());
      Assert.areEqual('Hot', ((Account) asSystem.fetch()).Rating);
    }
  }

  @IsTest
  static void aFieldAskedForByNameStillFailsInUserMode() {
    User reader = reader();
    acmeOwnedBy(reader);

    System.runAs(reader) {
      // Not from the factory, so the query has no defaults: Rating is there because it was asked for.
      IQuery named = Application.s.model(Account.SObjectType).query().withSharing(true);
      named.fields().add(new Set<SObjectField>{ Account.Rating });
      Assert.isTrue(named.toSoql().contains('Rating'), named.toSoql());
      try {
        named.run();
        Assert.fail('A field the user cannot read was returned');
      } catch (QueryException refused) {
        Assert.isTrue(refused.getMessage().contains('Rating'), refused.getMessage());
      }
    }
  }

  @IsTest
  static void aSubqueryFollowsTheModeOfItsParent() {
    User reader = reader();

    System.runAs(reader) {
      IQuery children = Application.s.qf().make(Account.SObjectType);
      IQuery parents = Application.s.qf().make(Account.SObjectType).addSubquery('ChildAccounts', children).withSharing(true);

      String nested = parents.toSoql().substringBetween('(', ')');
      Assert.isTrue(nested.contains('Industry'), nested);
      Assert.isFalse(nested.contains('Rating'), nested);
      Assert.isTrue(children.toSoql().contains('Rating'), 'on its own the child is still in system mode');
    }
  }

  @IsTest
  static void aUserModeSearchLeavesOutUnreadableDefaultsToo() {
    User reader = reader();

    System.runAs(reader) {
      IQuery asUser = Application.s.qf().make(Account.SObjectType).withSharing(true);
      String sosl = Application.s.searchQuery(new List<IQuery>{ asUser }).toSosl('Acme');
      Assert.isTrue(sosl.contains('Industry'), sosl);
      Assert.isFalse(sosl.contains('Rating'), sosl);

      IQuery asSystem = Application.s.qf().make(Account.SObjectType);
      Assert.isTrue(Application.s.searchQuery(new List<IQuery>{ asSystem }).toSosl('Acme').contains('Rating'));
    }
  }

  // --- units of work --------------------------------------------------------------------------

  @IsTest
  static void workInUserModeIsHeldToTheUsersObjectPermissions() {
    User reader = reader();
    Account stored = acmeOwnedBy(reader);

    System.runAs(reader) {
      Assert.isNotNull(refusal(Application.s.work().withSharing(true).track(new Account(Name = 'Mine'))), 'insert');
      Assert.isNotNull(refusal(Application.s.work().withSharing(true).track(new Account(Id = stored.Id, Name = 'Renamed'))), 'update');
      Assert.isNotNull(refusal(Application.s.work().withSharing(true).purge(stored)), 'delete');

      // Without it the work runs in system mode, as before, and the same statements go through.
      Assert.isNull(refusal(Application.s.work().track(new Account(Name = 'Mine'))));
      Assert.isNull(refusal(Application.s.work().withSharing(true).withSharing(false).track(new Account(Id = stored.Id, Name = 'Renamed'))));
    }

    Assert.areEqual('Renamed', [SELECT Name FROM Account WHERE Id = :stored.Id].Name);
    Assert.areEqual(2, [SELECT COUNT() FROM Account]);
  }

  @IsTest
  static void workInUserModeRefusesAFieldTheUserCannotChange() {
    User editor = editor();
    Account stored = acmeOwnedBy(editor);

    System.runAs(editor) {
      Assert.isNull(refusal(Application.s.work().withSharing(true).track(new Account(Id = stored.Id, Industry = 'Banking'))));
      Assert.isNotNull(
        refusal(Application.s.work().withSharing(true).track(new Account(Id = stored.Id, Rating = 'Cold'))),
        'Rating is read-only for this user'
      );
      Assert.isNull(refusal(Application.s.work().withSharing(true).track(new Account(Name = 'Globex', Industry = 'Energy'))));
      Assert.isNotNull(refusal(Application.s.work().withSharing(true).track(new Account(Name = 'Initech', Rating = 'Hot'))));
    }

    Account edited = [SELECT Industry, Rating FROM Account WHERE Id = :stored.Id];
    Assert.areEqual('Banking', edited.Industry);
    Assert.areEqual('Hot', edited.Rating);
    Assert.areEqual(2, [SELECT COUNT() FROM Account], 'Acme and Globex');
  }

  @IsTest
  static void theRefusalsAreThePlatformsOwnExceptions() {
    User editor = editor();
    Account stored = acmeOwnedBy(editor);

    System.runAs(editor) {
      // No permission on the object for the operation (this user may not delete).
      Assert.areEqual(
        'System.TypeException: DML operation DELETE not allowed on Account',
        refusal(Application.s.work().withSharing(true).purge(stored))
      );
      // A field the user may not write.
      String field = refusal(Application.s.work().withSharing(true).track(new Account(Id = stored.Id, Rating = 'Cold')));
      Assert.isTrue(field.startsWith('System.DmlException: Operation failed due to fields being inaccessible on Sobject Account'), field);

      // With partial success allowed nothing is thrown: the record is not saved, and the work says so.
      Account initech = new Account(Name = 'Initech', Rating = 'Hot');
      IWork partial = Application.s.work().withSharing(true).track(initech);
      partial.options().optAllOrNone = false;
      Assert.isNull(refusal(partial));
      Assert.areEqual(1, partial.failures().size());
      Assert.isTrue(partial.failureOf(initech).getMessage().contains('Rating'), partial.failureOf(initech).getMessage());
    }

    Assert.areEqual(1, [SELECT COUNT() FROM Account], 'Initech was not saved');
  }
}
