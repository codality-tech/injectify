@isTest
public class AsyncTest {
  // ========================================
  // Test Context (for static counters)
  // ========================================

  private static TestContext ctx = new TestContext();

  private class TestContext {
    public Integer iterableCounter = 0;
    public Boolean queryableDidExecute = false;
    public Integer queryableRecordsSize = null;
    public Integer queueableCounter = 0;
    public Integer schedulableCounter = 0;
  }

  // ========================================
  // Mock Handlers
  // ========================================

  // Batch Iterable Handler
  private class BatchIterableHandler implements IBatchIterableHandler {
    public boolean forceError = false;

    public Iterable<Object> batchStart() {
      ctx.iterableCounter++;
      return (Iterable<Object>) new List<Integer>{ 1, 2, 3 };
    }

    public void batchExecute(Iterable<Object> scope) {
      checkForceError();
    }

    public void batchFinish() {
    }

    public Integer batchDefaultSize() {
      return 200;
    }

    private void checkForceError() {
      if (forceError == true) {
        Decimal res = 1 / 0;
      }
    }
  }

  // Batch Queryable Handler
  private class BatchQueryableHandler implements IBatchQueryableHandler {
    public boolean forceError = false;

    public IQuery batchStart() {
      return new MockQuery();
    }

    public void batchExecute(List<SObject> records) {
      ctx.queryableDidExecute = true;
      ctx.queryableRecordsSize = records?.size();
      checkForceError();
    }

    public void batchFinish() {
    }

    public Integer batchDefaultSize() {
      return 200;
    }

    public ILogicalCondition filters() {
      return Application.s.all(null);
    }

    private void checkForceError() {
      if (forceError == true) {
        Decimal res = 1 / 0;
      }
    }
  }

  // Mock IQuery implementation
  private class MockQuery implements IQuery {
    public IQuery deepClone() {
      return this;
    }
    public IModel source() {
      return null;
    }
    public IQueryFields fields() {
      return null;
    }
    public IQuery addImplicitFields() {
      return this;
    }
    public IQuery addAllFields() {
      return this;
    }
    public IQuery addSubquery(SObjectField crField, IQuery target) {
      return this;
    }
    public IQuery addSubquery(string crName, IQuery target) {
      return this;
    }
    public Map<String, IQuery> getSubqueryMap() {
      return new Map<String, IQuery>();
    }
    public ILogicalCondition filters() {
      return null;
    }
    public IQuery addCondition(ICondition condition) {
      return this;
    }
    public List<IOrdering> orderings() {
      return new List<IOrdering>();
    }
    public IQuery setLimit(integer limitCount) {
      return this;
    }
    public IQuery setOffset(integer offsetCount) {
      return this;
    }
    public IQuery withSecurity(boolean enforceSecurity) {
      return this;
    }
    public IQuery withSharing(boolean enforceSharing) {
      return this;
    }
    public IQuery forUpdate(Boolean lock) {
      return this;
    }
    public IQuery allRows(Boolean include) {
      return this;
    }
    public IQuery usingScope(Enums.FilterScope scope) {
      return this;
    }
    public IQuery forView(Boolean mark) {
      return this;
    }
    public IQuery forReference(Boolean mark) {
      return this;
    }
    public string toSoql() {
      return 'SELECT Id FROM User LIMIT 1';
    }
    public string toSoql(boolean binding) {
      return toSoql();
    }
    public list<sobject> run() {
      ctx.queryableDidExecute = true;
      return new List<User>{ new User(Id = UserInfo.getUserId()) };
    }
    public list<sobject> fetch(integer limitCount) {
      return run();
    }
    public sobject fetch() {
      return run()[0];
    }
    public integer count() {
      return 1;
    }
    public Database.QueryLocator toLocator() {
      return Database.getQueryLocator('SELECT Id FROM User LIMIT 1');
    }
  }

  // Queueable Handler
  private class QueueableHandler implements IQueueableHandler {
    public boolean forceError = false;
    public boolean recursive = false;

    public void queueableExecute() {
      ctx.queueableCounter++;
      checkForceError();
      if (recursive && ctx.queueableCounter < 4) {
        QueueableHandler nextHandler = new QueueableHandler();
        nextHandler.recursive = true;
        Async.queueable(nextHandler).run();
      }
    }

    private void checkForceError() {
      if (forceError == true) {
        Decimal res = 1 / 0;
      }
    }
  }

  // Schedulable Handler
  private class SchedulableHandler implements ISchedulableHandler {
    public boolean forceError = false;

    public void schedulableExecute() {
      ctx.schedulableCounter++;
      checkForceError();
    }

    public String name() {
      return 'AsyncTest_Schedule';
    }

    public String cronExpression() {
      Datetime dt = Datetime.now().addMinutes(1);
      List<String> cronFragments = new List<String>{
        '' + dt.second(),
        '' + dt.minute(),
        '' + dt.hour(),
        '' + dt.day(),
        '' + dt.month(),
        '?',
        '' + dt.year()
      };
      return String.join(cronFragments, ' ');
    }

    private void checkForceError() {
      if (forceError == true) {
        Decimal res = 1 / 0;
      }
    }
  }

  // ========================================
  // Batch Iterable Tests
  // ========================================

  @isTest
  static void test_iterable_sync() {
    Async.synchronousInTests = true;
    ctx.iterableCounter = 0;
    BatchIterableHandler handler = new BatchIterableHandler();
    Async.iterable(handler).run();
    System.assertEquals(1, ctx.iterableCounter);
  }

  @isTest
  static void test_iterable_sync_error() {
    Async.synchronousInTests = true;
    ctx.iterableCounter = 0;
    BatchIterableHandler handler = new BatchIterableHandler();
    handler.forceError = true;
    Exception except;
    try {
      Async.iterable(handler).run();
    } catch (Exception e) {
      except = e;
    }
    System.assertNotEquals(null, except);
  }

  @isTest
  static void test_iterable_async() {
    Async.synchronousInTests = false;
    ctx.iterableCounter = 0;
    BatchIterableHandler handler = new BatchIterableHandler();
    Test.startTest();
    Async.iterable(handler).run();
    Test.stopTest();
    System.assertEquals(1, ctx.iterableCounter);
  }

  // ========================================
  // Batch Queryable Tests
  // ========================================

  @isTest
  static void test_queryable_sync() {
    ctx.queryableDidExecute = false;
    ctx.queryableRecordsSize = null;
    Async.synchronousInTests = true;
    BatchQueryableHandler handler = new BatchQueryableHandler();
    IBatchQueryable job = Async.queryable(handler);
    job.run();
    System.assertEquals(null, job.getJobId());
    System.assertEquals(true, ctx.queryableDidExecute);
    System.assertEquals(1, ctx.queryableRecordsSize);
  }

  @isTest
  static void test_queryable_sync_error() {
    ctx.queryableDidExecute = false;
    ctx.queryableRecordsSize = null;
    Async.synchronousInTests = true;
    BatchQueryableHandler handler = new BatchQueryableHandler();
    handler.forceError = true;
    Exception except;
    try {
      Async.queryable(handler).run();
    } catch (Exception e) {
      except = e;
    }
    System.assertNotEquals(null, except);
  }

  @isTest
  static void test_queryable_async() {
    ctx.queryableDidExecute = false;
    ctx.queryableRecordsSize = null;
    Async.synchronousInTests = false;
    BatchQueryableHandler handler = new BatchQueryableHandler();
    IBatchQueryable job = Async.queryable(handler);
    Test.startTest();
    job.run();
    Test.stopTest();
    System.assertNotEquals(null, job.getJobId());
    System.assertEquals(true, ctx.queryableDidExecute);
    System.assertEquals(1, ctx.queryableRecordsSize);
  }

  // ========================================
  // Queueable Tests
  // ========================================

  @isTest
  static void test_queueable_sync() {
    ctx.queueableCounter = 0;
    Async.synchronousInTests = true;
    QueueableHandler handler = new QueueableHandler();
    Async.queueable(handler).run();
    System.assertEquals(1, ctx.queueableCounter);
  }

  @isTest
  static void test_queueable_sync_error() {
    ctx.queueableCounter = 0;
    Async.synchronousInTests = true;
    QueueableHandler handler = new QueueableHandler();
    handler.forceError = true;
    Exception except;
    try {
      Async.queueable(handler).run();
    } catch (Exception e) {
      except = e;
    }
    System.assertNotEquals(null, except);
  }

  @isTest
  static void test_queueable_async() {
    ctx.queueableCounter = 0;
    Async.synchronousInTests = false;
    QueueableHandler handler = new QueueableHandler();
    Test.startTest();
    Async.queueable(handler).run();
    Test.stopTest();
    System.assertEquals(1, ctx.queueableCounter);
  }

  @isTest
  static void test_queueable_sync_recursive() {
    ctx.queueableCounter = 0;
    Async.synchronousInTests = true;
    QueueableHandler handler = new QueueableHandler();
    handler.recursive = true;
    Test.startTest();
    Async.queueable(handler).run();
    Test.stopTest();
    System.assertEquals(4, ctx.queueableCounter);
  }

  @isTest
  static void test_queueable_async_recursive() {
    ctx.queueableCounter = 0;
    Async.synchronousInTests = false;
    QueueableHandler handler = new QueueableHandler();
    handler.recursive = true;
    Test.startTest();
    Async.queueable(handler).run();
    Test.stopTest();
    System.assertEquals(4, ctx.queueableCounter);
  }

  // ========================================
  // Schedulable Tests
  // ========================================

  @isTest
  static void test_schedulable_sync() {
    ctx.schedulableCounter = 0;
    Async.synchronousInTests = true;
    SchedulableHandler handler = new SchedulableHandler();
    Async.schedulable(handler).run();
    System.assertEquals(1, ctx.schedulableCounter);
  }

  @isTest
  static void test_schedulable_sync_error() {
    ctx.schedulableCounter = 0;
    Async.synchronousInTests = true;
    SchedulableHandler handler = new SchedulableHandler();
    handler.forceError = true;
    Exception except;
    try {
      Async.schedulable(handler).run();
    } catch (Exception e) {
      except = e;
    }
    System.assertNotEquals(null, except);
  }

  @isTest
  static void test_schedulable_async() {
    ctx.schedulableCounter = 0;
    Async.synchronousInTests = false;
    SchedulableHandler handler = new SchedulableHandler();
    Test.startTest();
    Async.schedulable(handler).run();
    Test.stopTest();
    System.assertEquals(1, ctx.schedulableCounter);
  }

  // ========================================
  // Chaining Tests
  // ========================================

  @isTest
  static void test_chaining() {
    ctx.iterableCounter = 0;
    ctx.queueableCounter = 0;
    ctx.schedulableCounter = 0;
    Async.synchronousInTests = true;

    Async.iterable(new BatchIterableHandler())
      .then(Async.queueable(new QueueableHandler()))
      .then(Async.schedulable(new SchedulableHandler()))
      .run();

    System.assertEquals(1, ctx.iterableCounter);
    System.assertEquals(1, ctx.queueableCounter);
    System.assertEquals(1, ctx.schedulableCounter);
  }

  @isTest
  static void test_chaining_queueableOnly() {
    ctx.queueableCounter = 0;
    Async.synchronousInTests = true;

    Async.queueable(new QueueableHandler())
      .then(Async.queueable(new QueueableHandler()))
      .then(Async.queueable(new QueueableHandler()))
      .run();

    System.assertEquals(
      3,
      ctx.queueableCounter,
      'All 3 queueables should execute in chain'
    );
  }

  @isTest
  static void test_chaining_longChain() {
    ctx.queueableCounter = 0;
    Async.synchronousInTests = true;

    IJob chain = Async.queueable(new QueueableHandler());
    for (Integer i = 0; i < 9; i++) {
      chain = chain.then(Async.queueable(new QueueableHandler()));
    }
    chain.run();

    System.assertEquals(
      10,
      ctx.queueableCounter,
      'All 10 jobs in chain should execute'
    );
  }

  // ========================================
  // Error Propagation Tests
  // ========================================

  // Note: Shared variables are tested in ChainableTest.cls as they are
  // internal Chainable implementation details, not part of the global IJob API

  @isTest
  static void test_chainErrorPropagation_firstJobFails() {
    ctx.queueableCounter = 0;
    ctx.schedulableCounter = 0;
    Async.synchronousInTests = true;

    QueueableHandler failingHandler = new QueueableHandler();
    failingHandler.forceError = true;

    Boolean exceptionCaught = false;
    try {
      Async.queueable(failingHandler)
        .then(Async.schedulable(new SchedulableHandler()))
        .run();
    } catch (Exception e) {
      exceptionCaught = true;
    }

    System.assert(
      exceptionCaught,
      'Exception should propagate when first job fails'
    );
    System.assertEquals(
      1,
      ctx.queueableCounter,
      'First queueable should have attempted execution'
    );
    System.assertEquals(
      0,
      ctx.schedulableCounter,
      'Second job should not execute after first fails'
    );
  }

  @isTest
  static void test_chainErrorPropagation_middleJobFails() {
    ctx.queueableCounter = 0;
    ctx.schedulableCounter = 0;
    Async.synchronousInTests = true;

    QueueableHandler failingHandler = new QueueableHandler();
    failingHandler.forceError = true;

    Boolean exceptionCaught = false;
    try {
      Async.queueable(new QueueableHandler())
        .then(Async.queueable(failingHandler))
        .then(Async.schedulable(new SchedulableHandler()))
        .run();
    } catch (Exception e) {
      exceptionCaught = true;
    }

    System.assert(
      exceptionCaught,
      'Exception should propagate when middle job fails'
    );
    System.assertEquals(
      2,
      ctx.queueableCounter,
      'First two queueables should have attempted execution'
    );
    System.assertEquals(
      0,
      ctx.schedulableCounter,
      'Third job should not execute after second fails'
    );
  }

  @isTest
  static void test_chainErrorPropagation_lastJobFails() {
    ctx.queueableCounter = 0;
    ctx.schedulableCounter = 0;
    Async.synchronousInTests = true;

    SchedulableHandler failingHandler = new SchedulableHandler();
    failingHandler.forceError = true;

    Boolean exceptionCaught = false;
    try {
      Async.queueable(new QueueableHandler())
        .then(Async.schedulable(failingHandler))
        .run();
    } catch (Exception e) {
      exceptionCaught = true;
    }

    System.assert(
      exceptionCaught,
      'Exception should propagate when last job fails'
    );
    System.assertEquals(
      1,
      ctx.queueableCounter,
      'First queueable should complete'
    );
    System.assertEquals(
      1,
      ctx.schedulableCounter,
      'Last schedulable should have attempted execution'
    );
  }

  @isTest
  static void test_batchIterableError_propagation() {
    ctx.iterableCounter = 0;
    Async.synchronousInTests = true;

    BatchIterableHandler failingHandler = new BatchIterableHandler();
    failingHandler.forceError = true;

    Boolean exceptionCaught = false;
    try {
      Async.iterable(failingHandler).run();
    } catch (Exception e) {
      exceptionCaught = true;
    }

    System.assert(
      exceptionCaught,
      'Exception should be caught for batch iterable error'
    );
  }

  @isTest
  static void test_batchQueryableError_propagation() {
    ctx.queryableDidExecute = false;
    Async.synchronousInTests = true;

    BatchQueryableHandler failingHandler = new BatchQueryableHandler();
    failingHandler.forceError = true;

    Boolean exceptionCaught = false;
    try {
      Async.queryable(failingHandler).run();
    } catch (Exception e) {
      exceptionCaught = true;
    }

    System.assert(
      exceptionCaught,
      'Exception should be caught for batch queryable error'
    );
  }

  // ========================================
  // Job ID Tests
  // ========================================

  @isTest
  static void test_jobId_queueable_sync() {
    Async.synchronousInTests = true;
    IJob job = Async.queueable(new QueueableHandler());
    job.run();

    Id jobId = job.getJobId();
    System.assertEquals(
      null,
      jobId,
      'Synchronous queueable should have null job ID'
    );
  }

  @isTest
  static void test_jobId_queueable_async() {
    Async.synchronousInTests = false;
    IJob job = Async.queueable(new QueueableHandler());

    Test.startTest();
    job.run();
    Test.stopTest();

    Id jobId = job.getJobId();
    System.assertNotEquals(
      null,
      jobId,
      'Asynchronous queueable should have a job ID'
    );
  }

  @isTest
  static void test_jobId_schedulable_sync() {
    Async.synchronousInTests = true;
    IJob job = Async.schedulable(new SchedulableHandler());
    job.run();

    Id jobId = job.getJobId();
    System.assertEquals(
      null,
      jobId,
      'Synchronous schedulable should have null job ID'
    );
  }

  @isTest
  static void test_jobId_schedulable_async() {
    Async.synchronousInTests = false;
    IJob job = Async.schedulable(new SchedulableHandler());

    Test.startTest();
    job.run();
    Test.stopTest();

    Id jobId = job.getJobId();
    System.assertNotEquals(
      null,
      jobId,
      'Asynchronous schedulable should have a job ID'
    );
  }

  // ========================================
  // Edge Cases and Null Handling
  // ========================================

  @isTest
  static void test_then_withNullSuccessor() {
    Async.synchronousInTests = true;
    ctx.queueableCounter = 0;

    IJob job = Async.queueable(new QueueableHandler());
    IJob chainedJob = job.then(null);

    // then(null) should return the original job
    System.assertEquals(
      job,
      chainedJob,
      'then(null) should return the same job instance'
    );

    chainedJob.run();
    System.assertEquals(
      1,
      ctx.queueableCounter,
      'Original job should still execute'
    );
  }

  @isTest
  static void test_multipleChains_independent() {
    Async.synchronousInTests = true;
    ctx.queueableCounter = 0;

    // Create two independent chains
    IJob chain1 = Async.queueable(new QueueableHandler())
      .then(Async.queueable(new QueueableHandler()));

    IJob chain2 = Async.queueable(new QueueableHandler())
      .then(Async.queueable(new QueueableHandler()));

    // Run first chain
    chain1.run();
    System.assertEquals(
      2,
      ctx.queueableCounter,
      'First chain should execute 2 jobs'
    );

    // Run second chain
    ctx.queueableCounter = 0;
    chain2.run();
    System.assertEquals(
      2,
      ctx.queueableCounter,
      'Second chain should execute 2 jobs independently'
    );
  }

  @isTest
  static void test_chainedJobs_executionOrder() {
    Async.synchronousInTests = true;
    List<Integer> executionOrder = new List<Integer>();

    // Custom handlers that track execution order
    IJob job = Async.queueable(new OrderTrackingHandler(executionOrder, 1))
      .then(Async.queueable(new OrderTrackingHandler(executionOrder, 2)))
      .then(Async.queueable(new OrderTrackingHandler(executionOrder, 3)));

    job.run();

    System.assertEquals(3, executionOrder.size(), 'All 3 jobs should execute');
    System.assertEquals(1, executionOrder[0], 'First job should execute first');
    System.assertEquals(
      2,
      executionOrder[1],
      'Second job should execute second'
    );
    System.assertEquals(3, executionOrder[2], 'Third job should execute third');
  }

  private class OrderTrackingHandler implements IQueueableHandler {
    private List<Integer> tracker;
    private Integer ordinal;

    public OrderTrackingHandler(List<Integer> tracker, Integer ordinal) {
      this.tracker = tracker;
      this.ordinal = ordinal;
    }

    public void queueableExecute() {
      tracker.add(ordinal);
    }
  }

  // ========================================
  // Async/Sync Mode Toggle Tests
  // ========================================

  @isTest
  static void test_syncMode_toggle() {
    // Start in sync mode
    Async.synchronousInTests = true;
    ctx.queueableCounter = 0;

    Async.queueable(new QueueableHandler()).run();
    System.assertEquals(
      1,
      ctx.queueableCounter,
      'Sync mode should execute immediately'
    );

    // Toggle to async mode (note: can't actually test async in same transaction)
    Async.synchronousInTests = false;
    System.assertEquals(
      false,
      Async.synchronousInTests,
      'Should be able to toggle sync mode'
    );
  }

  // ========================================
  // Mixed Job Type Chains
  // ========================================

  @isTest
  static void test_chain_batchToQueueable() {
    ctx.iterableCounter = 0;
    ctx.queueableCounter = 0;
    Async.synchronousInTests = true;

    Async.iterable(new BatchIterableHandler())
      .then(Async.queueable(new QueueableHandler()))
      .run();

    System.assertEquals(1, ctx.iterableCounter, 'Batch should execute');
    System.assertEquals(1, ctx.queueableCounter, 'Queueable should execute');
  }

  @isTest
  static void test_chain_queueableToBatch() {
    ctx.queueableCounter = 0;
    ctx.queryableDidExecute = false;
    Async.synchronousInTests = true;

    Async.queueable(new QueueableHandler())
      .then(Async.queryable(new BatchQueryableHandler()))
      .run();

    System.assertEquals(1, ctx.queueableCounter, 'Queueable should execute');
    System.assertEquals(
      true,
      ctx.queryableDidExecute,
      'Batch queryable should execute'
    );
  }

  @isTest
  static void test_chain_schedulableToQueueable() {
    ctx.schedulableCounter = 0;
    ctx.queueableCounter = 0;
    Async.synchronousInTests = true;

    Async.schedulable(new SchedulableHandler())
      .then(Async.queueable(new QueueableHandler()))
      .run();

    System.assertEquals(
      1,
      ctx.schedulableCounter,
      'Schedulable should execute'
    );
    System.assertEquals(1, ctx.queueableCounter, 'Queueable should execute');
  }

  @isTest
  static void test_chain_allTypes() {
    ctx.iterableCounter = 0;
    ctx.queryableDidExecute = false;
    ctx.queueableCounter = 0;
    ctx.schedulableCounter = 0;
    Async.synchronousInTests = true;

    Async.iterable(new BatchIterableHandler())
      .then(Async.queryable(new BatchQueryableHandler()))
      .then(Async.queueable(new QueueableHandler()))
      .then(Async.schedulable(new SchedulableHandler()))
      .run();

    System.assertEquals(
      1,
      ctx.iterableCounter,
      'Batch iterable should execute'
    );
    System.assertEquals(
      true,
      ctx.queryableDidExecute,
      'Batch queryable should execute'
    );
    System.assertEquals(1, ctx.queueableCounter, 'Queueable should execute');
    System.assertEquals(
      1,
      ctx.schedulableCounter,
      'Schedulable should execute'
    );
  }

  // ========================================
  // Batch Size Configuration Tests
  // ========================================

  @isTest
  static void test_batchDefaultSize_iterable() {
    BatchIterableHandler handler = new BatchIterableHandler();
    System.assertEquals(
      200,
      handler.batchDefaultSize(),
      'Default batch size should be 200'
    );
  }

  @isTest
  static void test_batchDefaultSize_queryable() {
    BatchQueryableHandler handler = new BatchQueryableHandler();
    System.assertEquals(
      200,
      handler.batchDefaultSize(),
      'Default batch size should be 200'
    );
  }

  // ========================================
  // Handleable* Direct Tests (getHandler)
  // ========================================

  @isTest
  static void test_HandleableBatchIterable_getHandler() {
    BatchIterableHandler handler = new BatchIterableHandler();
    HandleableBatchIterable job = new HandleableBatchIterable(handler);
    IHandler retrievedHandler = job.getHandler();
    System.assertEquals(
      handler,
      retrievedHandler,
      'Should return the same handler'
    );
  }

  @isTest
  static void test_HandleableBatchQueryable_getHandler() {
    BatchQueryableHandler handler = new BatchQueryableHandler();
    HandleableBatchQueryable job = new HandleableBatchQueryable(handler);
    IHandler retrievedHandler = job.getHandler();
    System.assertEquals(
      handler,
      retrievedHandler,
      'Should return the same handler'
    );
  }

  @isTest
  static void test_HandleableSchedulable_getHandler() {
    SchedulableHandler handler = new SchedulableHandler();
    HandleableSchedulable job = new HandleableSchedulable(handler);
    IHandler retrievedHandler = job.getHandler();
    System.assertEquals(
      handler,
      retrievedHandler,
      'Should return the same handler'
    );
  }

  @isTest
  static void test_HandleableQueueable_getHandler() {
    QueueableHandler handler = new QueueableHandler();
    HandleableQueueable job = new HandleableQueueable(handler);
    IHandler retrievedHandler = job.getHandler();
    System.assertEquals(
      handler,
      retrievedHandler,
      'Should return the same handler'
    );
  }
}
