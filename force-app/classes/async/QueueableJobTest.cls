@IsTest
private class QueueableJobTest {
  private static List<String> trail = new List<String>();
  private static Id idSeenInside;
  private static Object sharedSeenInside;

  private class Recorder extends QueueableJob {
    private String label;
    private List<Chainable> startsInside = new List<Chainable>();

    private Recorder(String label) {
      this.label = label;
    }

    public override void execute() {
      trail.add(label);
      idSeenInside = getJobId();
      sharedSeenInside = getShared('note');
      for (Chainable child : startsInside) {
        child.run();
      }
    }
  }

  @IsTest
  static void runsInTheCallersTransactionWhenSynchronousInTests() {
    Async.synchronousInTests = true;
    Recorder job = new Recorder('a');
    job.then(new Recorder('b'));

    job.run();

    Assert.areEqual(new List<String>{ 'a', 'b' }, trail);
    Assert.isNull(job.getJobId());
  }

  @IsTest
  static void enqueuesAndKnowsItsOwnIdWhileRunning() {
    Async.synchronousInTests = false;
    Recorder job = new Recorder('queued');

    Test.startTest();
    job.run();
    Test.stopTest();

    Assert.areEqual(new List<String>{ 'queued' }, trail);
    Assert.isNotNull(job.getJobId());
    Assert.areEqual(job.getJobId(), idSeenInside, 'the context id reaches the body');
    AsyncApexJob record = [SELECT JobType FROM AsyncApexJob WHERE Id = :job.getJobId()];
    Assert.areEqual('Queueable', record.JobType);
  }

  @IsTest
  static void sharedValuesTravelWithTheEnqueuedJob() {
    Async.synchronousInTests = false;
    Recorder job = new Recorder('queued');
    job.setShared('note', 'packed before enqueue');

    Test.startTest();
    job.run();
    Test.stopTest();

    Assert.areEqual('packed before enqueue', sharedSeenInside);
  }

  @IsTest
  static void aQueueableStartedInsideAnEnqueuedOneStillRunsInTests() {
    Async.synchronousInTests = false;
    Recorder parent = new Recorder('parent');
    parent.startsInside.add(new Recorder('child'));

    Test.startTest();
    parent.run();
    Test.stopTest();

    Assert.areEqual(new List<String>{ 'parent', 'child' }, trail);
  }

  @IsTest
  static void minuteDelayAcceptsZeroThroughTen() {
    Recorder job = new Recorder('delayed');

    Assert.isTrue(job.setMinuteDelay(0) === job);
    Assert.areEqual(0, job.delayMinutes);
    job.setMinuteDelay(10);
    Assert.areEqual(10, job.delayMinutes);
  }

  @IsTest
  static void minuteDelayIgnoresValuesOutsideTheRange() {
    Recorder job = new Recorder('delayed');
    job.setMinuteDelay(5);

    for (Integer invalid : new List<Integer>{ -1, 11, null }) {
      job.setMinuteDelay(invalid);
    }

    Assert.areEqual(5, job.delayMinutes);
  }

  @IsTest
  static void aDelayedJobIsStillEnqueued() {
    Async.synchronousInTests = false;
    Recorder job = new Recorder('delayed');
    job.setMinuteDelay(1);

    Test.startTest();
    job.run();
    Test.stopTest();

    Assert.isNotNull(job.getJobId());
  }
}
