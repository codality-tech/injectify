@IsTest
private class BatchQueryableTest {
  private static Set<Id> seen = new Set<Id>();
  private static Boolean finished = false;

  @TestSetup
  static void accounts() {
    insert new List<Account>{
      new Account(Name = 'alpha'),
      new Account(Name = 'beta'),
      new Account(Name = 'gamma')
    };
  }

  /** Batches over every Account and remembers which ones it was handed. */
  private class AccountSweep extends BatchQueryable {
    public override IQuery start() {
      return new Query(Application.s.model(Account.SObjectType));
    }

    public override void execute(List<SObject> scope) {
      seen.addAll(new Map<Id, SObject>(scope).keySet());
    }

    public override void finish() {
      finished = true;
    }
  }

  private static Set<Id> idsOf(List<Account> accounts) {
    return new Map<Id, Account>(accounts).keySet();
  }

  @IsTest
  static void inlineRunReadsTheRowsDirectly() {
    Async.synchronousInTests = true;

    new AccountSweep().run();

    Assert.areEqual(idsOf([SELECT Id FROM Account]), seen);
    Assert.isTrue(finished);
  }

  // The platform won't execute a batch class declared inside a test, so enqueued runs use a handler.
  private class SweepHandler implements IBatchQueryableHandler {
    public IQuery batchStart() {
      return new Query(Application.s.model(Account.SObjectType));
    }
    public void batchExecute(List<SObject> scope) {
      seen.addAll(new Map<Id, SObject>(scope).keySet());
    }
    public void batchFinish() {
      finished = true;
    }
    public Integer batchDefaultSize() {
      return 200;
    }
  }

  @IsTest
  static void enqueuedRunReadsThroughAQueryLocator() {
    Async.synchronousInTests = false;
    IBatchQueryable job = Async.queryable(new SweepHandler());

    Test.startTest();
    job.run();
    Test.stopTest();

    Assert.areEqual(idsOf([SELECT Id FROM Account]), seen);
    Assert.isTrue(finished);
    Assert.isNotNull(job.getJobId());
  }

  @IsTest
  static void startHandsThePlatformALocator() {
    Async.synchronousInTests = false;

    Object scope = new AccountSweep().start(null);

    Assert.isTrue(scope instanceof Database.QueryLocator);
  }

  @IsTest
  static void filtersNarrowTheQueryInline() {
    Async.synchronousInTests = true;
    AccountSweep job = new AccountSweep();
    job.filters().add(Application.s.eq(Account.Name, 'beta'));

    job.run();

    Assert.areEqual(idsOf([SELECT Id FROM Account WHERE Name = 'beta']), seen);
  }

  @IsTest
  static void filtersNarrowTheQueryWhenEnqueued() {
    Async.synchronousInTests = false;
    BatchQueryable job = (BatchQueryable) Async.queryable(new SweepHandler());
    job.filters().add(Application.s.eq(Account.Name, 'gamma'));

    Test.startTest();
    job.run();
    Test.stopTest();

    Assert.areEqual(idsOf([SELECT Id FROM Account WHERE Name = 'gamma']), seen);
  }

  @IsTest
  static void filtersIsOneReusableGroup() {
    AccountSweep job = new AccountSweep();

    Assert.isTrue(job.filters() === job.filters());
    Assert.isTrue(job.filters().getAll().isEmpty());
  }
}
