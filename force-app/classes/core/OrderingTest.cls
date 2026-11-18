@IsTest
private class OrderingTest {
  @IsTest
  static void testOrderingToSoqlAndApply() {
    Core core = new Core();
    IModel model = core.model(Account.SObjectType);

    // toSoql with string route
    IOrdering ob = core.ordering('Name', true, true);
    ob.realize(Account.SObjectType);
    System.assertEquals('Name ASC NULLS LAST', ob.toSoql());

    // toSoql with path route
    IPath idPath = model.path('Id');
    IOrdering ob2 = core.ordering(idPath, false, false);
    ob2.realize(Account.SObjectType);
    System.assertEquals('Id DESC NULLS FIRST', ob2.toSoql());

    // apply sorts records
    List<Account> recs = new List<Account>{
      new Account(Name = 'B'),
      new Account(Name = 'A'),
      new Account(Name = null)
    };
    ob.apply(recs);
    // NULLS LAST and ASC -> [A, B, null]
    System.assertEquals('A', recs[0].Name);
    System.assertEquals('B', recs[1].Name);
    System.assertEquals(null, recs[2].Name);
  }

  private static void sortBy(
    List<SObject> records,
    Object route,
    Boolean isAscending,
    Boolean nullsLast
  ) {
    Application.s.ordering(route, isAscending, nullsLast).apply(records);
  }

  private static List<Object> labels(List<SObject> records, SObjectField field) {
    List<Object> result = new List<Object>();
    for (SObject record : records) {
      result.add(record.get(field));
    }
    return result;
  }

  @IsTest
  static void sortsTextInBothDirections() {
    List<Account> accounts = new List<Account>{
      new Account(Name = 'beta'),
      new Account(Name = 'alpha'),
      new Account(Name = 'gamma')
    };

    sortBy(accounts, Account.Name, true, false);
    Assert.areEqual(
      new List<Object>{ 'alpha', 'beta', 'gamma' },
      labels(accounts, Account.Name)
    );

    sortBy(accounts, Account.Name, false, false);
    Assert.areEqual(
      new List<Object>{ 'gamma', 'beta', 'alpha' },
      labels(accounts, Account.Name)
    );
  }

  @IsTest
  static void placesNullsIndependentlyOfDirection() {
    for (Boolean isAscending : new List<Boolean>{ true, false }) {
      List<Account> accounts = new List<Account>{
        new Account(Name = 'b'),
        new Account(),
        new Account(Name = 'a')
      };

      sortBy(accounts, Account.Name, isAscending, true);
      Assert.isNull(accounts[2].Name, 'nulls last, ascending=' + isAscending);

      sortBy(accounts, Account.Name, isAscending, false);
      Assert.isNull(accounts[0].Name, 'nulls first, ascending=' + isAscending);
    }
  }

  @IsTest
  static void sortsIntegersAndDecimals() {
    List<Account> accounts = new List<Account>{
      new Account(Name = 'fifty', NumberOfEmployees = 50),
      new Account(Name = 'seven', NumberOfEmployees = 7),
      new Account(Name = 'three hundred', NumberOfEmployees = 300)
    };
    sortBy(accounts, Account.NumberOfEmployees, true, false);
    Assert.areEqual(
      new List<Object>{ 'seven', 'fifty', 'three hundred' },
      labels(accounts, Account.Name)
    );

    List<Opportunity> opportunities = new List<Opportunity>{
      new Opportunity(Name = 'mid', Amount = 10.5),
      new Opportunity(Name = 'low', Amount = 2.25),
      new Opportunity(Name = 'high', Amount = 99)
    };
    sortBy(opportunities, Opportunity.Amount, false, false);
    Assert.areEqual(
      new List<Object>{ 'high', 'mid', 'low' },
      labels(opportunities, Opportunity.Name)
    );
  }

  @IsTest
  static void sortsDatesDatetimesAndTimes() {
    List<Opportunity> opportunities = new List<Opportunity>{
      new Opportunity(Name = 'later', CloseDate = Date.newInstance(2030, 1, 2)),
      new Opportunity(Name = 'earlier', CloseDate = Date.newInstance(2030, 1, 1))
    };
    sortBy(opportunities, Opportunity.CloseDate, true, false);
    Assert.areEqual(
      new List<Object>{ 'earlier', 'later' },
      labels(opportunities, Opportunity.Name)
    );

    List<Event> events = new List<Event>{
      new Event(
        Subject = 'noon',
        ActivityDateTime = Datetime.newInstanceGmt(2030, 1, 1, 12, 0, 0)
      ),
      new Event(
        Subject = 'morning',
        ActivityDateTime = Datetime.newInstanceGmt(2030, 1, 1, 9, 0, 0)
      )
    };
    sortBy(events, Event.ActivityDateTime, true, false);
    Assert.areEqual(
      new List<Object>{ 'morning', 'noon' },
      labels(events, Event.Subject)
    );

    List<BusinessHours> hours = new List<BusinessHours>{
      new BusinessHours(Name = 'nine', MondayStartTime = Time.newInstance(9, 0, 0, 0)),
      new BusinessHours(Name = 'seven', MondayStartTime = Time.newInstance(7, 30, 0, 0))
    };
    sortBy(hours, BusinessHours.MondayStartTime, false, false);
    Assert.areEqual(
      new List<Object>{ 'nine', 'seven' },
      labels(hours, BusinessHours.Name)
    );
  }

  @IsTest
  static void sortsBooleans() {
    List<Contact> contacts = new List<Contact>{
      new Contact(LastName = 'yes', DoNotCall = true),
      new Contact(LastName = 'no', DoNotCall = false)
    };
    sortBy(contacts, Contact.DoNotCall, true, false);
    Assert.areEqual(
      new List<Object>{ 'no', 'yes' },
      labels(contacts, Contact.LastName)
    );
  }

  @IsTest
  static void sortsByParentFieldThroughRelationshipPath() {
    Account zeta = new Account(Name = 'zeta');
    Account alpha = new Account(Name = 'alpha');
    List<Contact> contacts = new List<Contact>{
      new Contact(LastName = 'of zeta', Account = zeta),
      new Contact(LastName = 'orphan'),
      new Contact(LastName = 'of alpha', Account = alpha)
    };

    sortBy(
      contacts,
      new List<SObjectField>{ Contact.AccountId, Account.Name },
      true,
      true
    );

    Assert.areEqual(
      new List<Object>{ 'of alpha', 'of zeta', 'orphan' },
      labels(contacts, Contact.LastName)
    );
  }

  @IsTest
  static void ignoresEmptyAndNullLists() {
    // A string route stays unrealized until there are records to realize against.
    IOrdering ordering = Application.s.ordering('Name', true, false);
    ordering.apply(new List<Account>());
    ordering.apply(null);
    Assert.isNull(ordering.path(), 'empty input must not realize the ordering');
  }
}
