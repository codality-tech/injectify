@IsTest
private class MockSchemeTest {
  private static List<Account> cannedAccounts() {
    return new List<Account>{
      new Account(Id = IdUtil.generateId(Account.SObjectType), Name = 'Acme'),
      new Account(Id = IdUtil.generateId(Account.SObjectType), Name = 'Globex')
    };
  }

  @IsTest
  static void queriesReturnTheRegisteredRowsTyped() {
    List<Account> canned = cannedAccounts();
    MockScheme scheme = new MockScheme().returning(Account.SObjectType, canned);
    Core mocked = new Core(scheme);

    List<Account> found = (List<Account>) mocked.model(Account.SObjectType).query().run();

    Assert.areEqual(canned, found, 'no rows were inserted');
    Assert.areEqual(1, scheme.queries().size());
    Assert.isTrue(scheme.queries()[0].startsWith('SELECT Id FROM Account'), scheme.queries()[0]);
  }

  @IsTest
  static void bindValuesAreRecorded() {
    MockScheme scheme = new MockScheme().returning(Account.SObjectType, cannedAccounts());
    Core mocked = new Core(scheme);
    IQuery named = mocked.model(Account.SObjectType).query();
    named.filters().add(mocked.eq(Account.Name, 'Acme'));

    named.run();

    Assert.isTrue(scheme.queries()[0].contains('WHERE (Name = :a0)'), scheme.queries()[0]);
    Assert.areEqual('Acme', scheme.bindMaps()[0].get('a0'));
  }

  @IsTest
  static void theOuterObjectDecidesWhatComesBack() {
    Assert.areEqual('Account', MockScheme.outerObject('SELECT Id, (SELECT Id FROM Contacts) FROM Account WHERE Name = :a0'));
    Assert.areEqual('Contact', MockScheme.outerObject('select id from Contact'));
    try {
      MockScheme.outerObject('SELECT Id');
      Assert.fail('no FROM');
    } catch (IllegalArgumentException expected) {
      Assert.isTrue(expected.getMessage().startsWith('No FROM'));
    }
  }

  @IsTest
  static void aSemiJoinIsMockedByItsOuterObject() {
    MockScheme scheme = new MockScheme()
      .returning(Account.SObjectType, cannedAccounts())
      .returning(Contact.SObjectType, new List<Contact>{ new Contact(LastName = 'Inner') });
    Core mocked = new Core(scheme);
    IQuery innerQuery = mocked.model(Contact.SObjectType).query();
    innerQuery.fields().add(new Set<SObjectField>{ Contact.AccountId });
    innerQuery.filters().add(mocked.eq(Contact.MailingCity, 'Seattle'));
    IQuery outerQuery = mocked.model(Account.SObjectType).query();
    outerQuery.filters().add(mocked.eq(Account.Industry, 'Energy'));
    outerQuery.filters().add(mocked.iin(Account.Id, innerQuery));
    outerQuery.filters().add(mocked.ne(Account.Name, 'Initech'));

    List<SObject> found = outerQuery.run();
    Integer counted = outerQuery.count();

    String filter = ' FROM Account WHERE (Industry = :a0 AND Id IN (SELECT AccountId FROM Contact WHERE (MailingCity = :a1)) AND Name != :a2)';
    Assert.areEqual(2, found.size(), 'the rows of the outer object, not the one contact');
    Assert.isInstanceOfType(found, List<Account>.class);
    Assert.areEqual(2, counted);
    Assert.areEqual(new List<String>{ 'SELECT Id' + filter, 'SELECT COUNT()' + filter }, scheme.queries());
    Map<String, Object> expected = new Map<String, Object>{ 'a0' => 'Energy', 'a1' => 'Seattle', 'a2' => 'Initech' };
    Assert.areEqual(expected, scheme.bindMaps()[0], 'the inner value is bound with the outer ones');
    Assert.areEqual(expected, scheme.bindMaps()[1]);
    Assert.areEqual(
      'Account',
      MockScheme.outerObject(
        'SELECT Id, (SELECT Id FROM Contacts WHERE (Id IN (SELECT ContactId FROM Case))) FROM Account WHERE (Id NOT IN (SELECT AccountId FROM Opportunity))'
      )
    );
  }

  @IsTest
  static void unregisteredObjectsCountsAndAggregates() {
    MockScheme scheme = new MockScheme().returning(Account.SObjectType, cannedAccounts());
    Core mocked = new Core(scheme);
    IAggregateQuery totals = mocked.model(Account.SObjectType).aggregateQuery();
    totals.aggregates().add(mocked.count(Account.Id));

    List<SObject> contacts = mocked.model(Contact.SObjectType).query().run();

    Assert.isTrue(contacts.isEmpty());
    Assert.isTrue(contacts instanceof List<Contact>, 'typed even when empty');
    Assert.areEqual(2, mocked.model(Account.SObjectType).query().count());
    Assert.isTrue(totals.run().isEmpty(), 'aggregates are not mocked');
    Assert.areEqual(3, scheme.queries().size());
  }

  @IsTest
  static void locatorsComeFromTheDatabase() {
    insert new Account(Name = 'Stored');
    MockScheme scheme = new MockScheme().returning(Account.SObjectType, cannedAccounts());

    Database.QueryLocator locator = new Core(scheme).model(Account.SObjectType).query().toLocator();

    Assert.areEqual(1, Database.query(locator.getQuery()).size(), 'the real row, not the canned ones');
    Assert.areEqual(1, scheme.queries().size());
  }

  @IsTest
  static void describesAreReal() {
    MockScheme scheme = new MockScheme();

    Assert.isTrue(scheme.getFieldMap(Account.SObjectType).containsKey('name'));
    Assert.areEqual('Account', scheme.getDescribe(Account.SObjectType).getName());
    Assert.areEqual(Account.SObjectType, scheme.getSObjectType('Account'));
    Assert.areEqual('Account Name', scheme.getFieldDescribe(Account.Name).getLabel());
    Assert.isNotNull(scheme.getFieldsetMap(Account.SObjectType));
    Assert.areEqual(MockScheme.class, scheme.getTypeForName('MockScheme'));
    Assert.isTrue(scheme.returning(Contact.SObjectType, null) === scheme, 'chainable');
  }

  @IsTest
  static void searchesReturnTheRegisteredRowsOfEachReturningObject() {
    MockScheme scheme = new MockScheme().returning(Account.SObjectType, cannedAccounts());
    Core mocked = new Core(scheme);
    IQuery accounts = mocked.model(Account.SObjectType).query();
    accounts.fields().add(new Set<SObjectField>{ Account.Name });
    accounts.filters().add(mocked.eq(Account.Name, 'Acme (West), Inc'));
    IQuery contacts = mocked.model(Contact.SObjectType).query();
    ISearchQuery search = mocked.searchQuery(new List<IQuery>{ accounts, contacts }).setLimit(5);

    List<List<SObject>> found = search.run('Acme');

    Assert.areEqual(2, found.size(), 'one list per object, hits or not');
    Assert.areEqual(2, found[0].size());
    Assert.isInstanceOfType(found[0], List<Account>.class);
    Assert.isTrue(found[1].isEmpty(), 'no contacts were registered');
    Assert.isInstanceOfType(found[1], List<Contact>.class);
    Assert.areEqual(1, scheme.queries().size(), 'the search was recorded');
    Assert.areEqual(search.toSosl('Acme'), scheme.queries()[0]);
    Assert.isTrue(scheme.bindMaps()[0].isEmpty(), 'SOSL has no bind values');
    Assert.areEqual(new Set<SObjectType>{ Account.SObjectType }, search.runAsMap('Acme').keySet());
  }

  @IsTest
  static void theObjectsAfterReturningAreReadPastTheirClauses() {
    Assert.areEqual(
      new List<String>{ 'Account', 'Contact' },
      MockScheme.returningObjects(
        'FIND {x} IN ALL FIELDS RETURNING Account(Id, Name WHERE Name = \'a), b \\\' WITH c\' LIMIT 3), Contact WITH DIVISION = \'g\' LIMIT 10'
      )
    );
    Assert.areEqual(new List<String>{ 'Lead' }, MockScheme.returningObjects('FIND {x} RETURNING Lead LIMIT 5'));
    Assert.isTrue(MockScheme.returningObjects('FIND {x}').isEmpty());
  }

  @IsTest
  static void aQueryWithOptionsStillFindsItsObject() {
    List<Account> canned = cannedAccounts();
    MockScheme scheme = new MockScheme().returning(Account.SObjectType, canned);
    Core mocked = new Core(scheme);
    IQuery q = mocked.model(Account.SObjectType).query().usingScope(Enums.FilterScope.MINE).allRows(true).forView(true).setLimit(5);
    q.filters().add(mocked.eq(Account.Name, 'Acme'));
    q.filters().add(mocked.ge(Account.CreatedDate, DateLiteral.lastNDays(7)));
    IAggregateQuery counted = mocked.model(Account.SObjectType).aggregateQuery().usingScope(Enums.FilterScope.TEAM).allRows(true);
    counted.aggregates().add(mocked.count(Account.Id));

    Assert.areEqual(canned, q.run(), 'the rows registered for Account');
    Assert.areEqual(2, q.count());
    Assert.isTrue(counted.run().isEmpty(), 'an aggregate query returns no rows from a mock');

    Assert.areEqual(
      'SELECT Id FROM Account USING SCOPE mine WHERE (Name = :a0 AND CreatedDate >= LAST_N_DAYS:7) LIMIT 5 FOR VIEW ALL ROWS',
      scheme.queries()[0]
    );
    Assert.areEqual(new Map<String, Object>{ 'a0' => 'Acme' }, scheme.bindMaps()[0], 'the date literal is in the text, not among the binds');
    Assert.areEqual('SELECT COUNT() FROM Account USING SCOPE mine WHERE (Name = :a0 AND CreatedDate >= LAST_N_DAYS:7) ALL ROWS', scheme.queries()[1]);
    Assert.areEqual('SELECT COUNT(Id) Id_cnt FROM Account USING SCOPE team ALL ROWS', scheme.queries()[2]);
    Assert.areEqual('Account', MockScheme.outerObject('SELECT Id FROM Account USING SCOPE mine ALL ROWS'));
  }

  @IsTest
  static void aQueryThroughAPolymorphicLookupReturnsTheRowsOfItsObject() {
    Task canned = (Task) JSON.deserialize(
      '{"attributes":{"type":"Task"},"Subject":"Call","What":{"attributes":{"type":"Name"},"Type":"Account","Name":"Acme"}}',
      Task.class
    );
    MockScheme scheme = new MockScheme().returning(Task.SObjectType, new List<Task>{ canned });
    Core mocked = new Core(scheme);
    IQuery q = mocked.model(Task.SObjectType).query();
    q.fields().add(new Set<String>{ 'What.Type', 'What.Name' });
    ICondition aboutAccounts = mocked.eq('What.Type', 'Account');
    q.filters().add(aboutAccounts);

    List<Task> found = (List<Task>) q.run();

    Assert.areEqual('SELECT Id, What.Type, What.Name FROM Task WHERE (What.Type = :a0)', scheme.queries()[0]);
    Assert.areEqual(1, found.size());
    Assert.isTrue(aboutAccounts.evaluate(found[0]), 'a canned row answers the condition in memory');
  }
}
