@IsTest
private class BatchIterableTest {
  private static List<String> trail = new List<String>();

  /** Batches over a list of strings and writes each phase to the trail. */
  private class Letters extends BatchIterable {
    private List<Object> items;
    private Integer preferredSize;
    private List<Chainable> startsDuringScope = new List<Chainable>();

    private Letters(List<Object> items) {
      this.items = items;
    }

    public override Iterable<Object> start() {
      trail.add('start');
      return items;
    }

    public override void execute(Iterable<Object> scope) {
      List<String> seen = new List<String>();
      Iterator<Object> cursor = scope.iterator();
      while (cursor.hasNext()) {
        seen.add(String.valueOf(cursor.next()));
      }
      trail.add('execute:' + String.join(seen, ','));
      Integer rows = (Integer) getShared('rows');
      setShared('rows', (rows == null ? 0 : rows) + seen.size());
      for (Chainable job : startsDuringScope) {
        job.run();
      }
    }

    public override void finish() {
      trail.add('finish rows=' + getShared('rows'));
    }

    public override Integer getDefaultBatchSize() {
      return preferredSize == null ? super.getDefaultBatchSize() : preferredSize;
    }
  }

  private class Marker extends QueueableJob {
    private String label;

    private Marker(String label) {
      this.label = label;
    }

    public override void execute() {
      trail.add(label);
    }
  }

  private class SizedHandler implements IBatchIterableHandler {
    public Iterable<Object> batchStart() {
      return new List<Object>();
    }
    public void batchExecute(Iterable<Object> scope) {
    }
    public void batchFinish() {
    }
    public Integer batchDefaultSize() {
      return 25;
    }
  }

  @IsTest
  static void inlineRunGoesThroughEveryPhaseThenTheChain() {
    Async.synchronousInTests = true;
    Letters job = new Letters(new List<Object>{ 'a', 'b' });
    job.then(new Marker('next'));

    job.run();

    Assert.areEqual(
      new List<String>{ 'start', 'execute:a,b', 'finish rows=2', 'next' },
      trail
    );
    Assert.isNull(job.getJobId());
  }

  @IsTest
  static void anEmptyScopeSkipsExecuteButStillFinishesAndMovesOn() {
    Async.synchronousInTests = true;
    Letters job = new Letters(new List<Object>());
    job.then(new Marker('second')).then(new Marker('third'));

    job.run();

    Assert.areEqual(
      new List<String>{ 'start', 'finish rows=null', 'second', 'third' },
      trail
    );
  }

  @IsTest
  static void aQueueableStartedDuringTheScopeRunsBeforeFinish() {
    Async.synchronousInTests = true;
    Letters job = new Letters(new List<Object>{ 'a' });
    job.startsDuringScope.add(new Marker('nested'));

    job.run();

    Assert.areEqual(
      new List<String>{ 'start', 'execute:a', 'nested', 'finish rows=1' },
      trail
    );
  }

  @IsTest
  static void platformEntryPointsRecordTheJobAndContinueTheChain() {
    Async.synchronousInTests = true; // only decides how the follow-up job starts
    Id batchId = IdUtil.generateId(AsyncApexJob.SObjectType);
    Letters job = new Letters(new List<Object>{ 'a', 'b' });
    job.then(new Marker('next'));
    FakeContext context = new FakeContext(batchId);

    Iterable<Object> scope = job.start(context);
    job.execute(context, scope);
    job.finish(context);

    Assert.areEqual(
      new List<String>{ 'start', 'execute:a,b', 'finish rows=2', 'next' },
      trail
    );
    Assert.areEqual(batchId, job.getJobId());
  }

  @IsTest
  static void anEnqueuedBatchKeepsItsStateBetweenTransactions() {
    // The platform won't execute a batch class declared inside a test, so this goes through a
    // handler. Apex tests also allow a single execute() per batch, so one scope holds every item.
    Async.synchronousInTests = false;
    IBatchIterable job = Async.iterable(new CountingHandler(new List<Object>{ 'a', 'b', 'c' }));

    Test.startTest();
    job.run();
    Test.stopTest();

    Assert.areEqual(new List<String>{ 'execute:3', 'finish rows=3' }, trail);
    AsyncApexJob record = [SELECT JobType FROM AsyncApexJob WHERE Id = :job.getJobId()];
    Assert.areEqual('BatchApex', record.JobType);
  }

  private class FakeContext implements Database.BatchableContext {
    private Id jobId;

    private FakeContext(Id jobId) {
      this.jobId = jobId;
    }
    public Id getJobId() {
      return jobId;
    }
    public Id getChildJobId() {
      return null;
    }
  }

  private class CountingHandler implements IBatchIterableHandler {
    private List<Object> items;
    private Integer rows = 0;

    private CountingHandler(List<Object> items) {
      this.items = items;
    }
    public Iterable<Object> batchStart() {
      return items;
    }
    public void batchExecute(Iterable<Object> scope) {
      Integer count = 0;
      Iterator<Object> cursor = scope.iterator();
      while (cursor.hasNext()) {
        cursor.next();
        count++;
      }
      rows += count;
      trail.add('execute:' + count);
    }
    public void batchFinish() {
      trail.add('finish rows=' + rows);
    }
    public Integer batchDefaultSize() {
      return 200;
    }
  }

  @IsTest
  static void batchSizeComesFromTheSubclassUntilSetExplicitly() {
    Letters job = new Letters(new List<Object>());
    Assert.areEqual(200, job.effectiveBatchSize(), 'framework default');

    job.preferredSize = 50;
    Assert.areEqual(50, job.effectiveBatchSize(), 'subclass default');

    job.preferredSize = 0;
    Assert.areEqual(200, job.effectiveBatchSize(), 'unusable default falls back');

    Assert.isTrue(job.setBatchSize(7) === job);
    Assert.areEqual(7, job.effectiveBatchSize(), 'explicit size wins');
  }

  @IsTest
  static void setBatchSizeRejectsSizesBelowOne() {
    Letters job = new Letters(new List<Object>());

    for (Integer invalid : new List<Integer>{ 0, -3, null }) {
      try {
        job.setBatchSize(invalid);
        Assert.fail('accepted batch size ' + invalid);
      } catch (Chainable.ChainableException expected) {
        Assert.isTrue(expected.getMessage().contains('positive'));
      }
    }
  }

  @IsTest
  static void handlerJobsUseTheHandlersDefaultSize() {
    Batch job = (Batch) Async.iterable(new SizedHandler());

    Assert.areEqual(25, job.effectiveBatchSize());
  }
}
