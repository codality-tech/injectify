@IsTest
private class ChainableTest {
  private static List<String> trail = new List<String>();

  /**
   * Queueable that writes its label to the trail, then starts the jobs it was given from inside
   * its own body. As a child, it tells a parent Probe which capture mode it wants.
   */
  private class Probe extends Queueable {
    private String label;
    private List<Chainable> startsInside = new List<Chainable>();
    private Enums.CaptureMode modeAsChild;
    private String readsKey;
    private String writesKey;
    private Boolean fails = false;

    private Probe(String label) {
      this.label = label;
    }

    private Probe starting(Chainable child) {
      startsInside.add(child);
      return this;
    }

    private Probe nestedAs(Enums.CaptureMode mode) {
      modeAsChild = mode;
      return this;
    }

    public override void execute() {
      trail.add(readsKey == null ? label : label + '=' + getShared(readsKey));
      if (writesKey != null) {
        setShared(writesKey, label);
      }
      for (Chainable child : startsInside) {
        child.run();
      }
      if (fails) {
        throw new IllegalArgumentException('probe ' + label + ' failed');
      }
    }

    public override Enums.CaptureMode captureModeFor(Chainable child) {
      return child instanceof Probe ? ((Probe) child).modeAsChild : null;
    }
  }

  /** Starts a fresh copy of itself every time it runs. */
  private class Runaway extends Queueable {
    public override void execute() {
      trail.add('runaway');
      new Runaway().run();
    }
  }

  private class CapturingHandler implements IQueueableHandler, IHandlerCapturing {
    private Enums.CaptureMode mode;
    private List<Chainable> startsInside = new List<Chainable>();

    public void queueableExecute() {
      trail.add('handler');
      for (Chainable child : startsInside) {
        child.run();
      }
    }

    public Enums.CaptureMode getCaptureMode(IJob parentJob, IJob childJob) {
      return mode;
    }
  }

  private class QuietQueueable implements IQueueableHandler {
    public void queueableExecute() {
    }
  }

  private class QuietIterable implements IBatchIterableHandler {
    public Iterable<Object> batchStart() {
      return new List<Object>();
    }
    public void batchExecute(Iterable<Object> scope) {
    }
    public void batchFinish() {
    }
    public Integer batchDefaultSize() {
      return 10;
    }
  }

  private class QuietSchedulable implements ISchedulableHandler {
    public void schedulableExecute() {
    }
    public String name() {
      return 'ChainableTest quiet';
    }
    public String cronExpression() {
      return '0 0 0 1 1 ? 2099';
    }
  }

  /** Reads the chain's note through its job, then leaves its own label as the note. */
  private class NoteTaker implements IQueueableHandler, IJobAware {
    private IJob job;
    private String label;

    private NoteTaker(String label) {
      this.label = label;
    }
    public void setJob(IJob job) {
      this.job = job;
    }
    public void queueableExecute() {
      trail.add(label + '=' + job.getShared('note'));
      job.setShared('note', label);
    }
  }

  /** Records, in each phase, whether it was handed its job. */
  private class PhaseWatcher implements IBatchIterableHandler, IJobAware {
    private IJob job;

    public void setJob(IJob job) {
      this.job = job;
    }
    public Iterable<Object> batchStart() {
      trail.add('start:' + (job != null));
      return new List<Object>{ 1 };
    }
    public void batchExecute(Iterable<Object> scope) {
      trail.add('execute:' + (job != null));
    }
    public void batchFinish() {
      trail.add('finish:' + (job != null));
    }
    public Integer batchDefaultSize() {
      return 10;
    }
  }

  private static void expectTrail(List<String> expected) {
    Assert.areEqual(expected, trail, 'execution order');
  }

  // --- handlers and shared values -----------------------------------------------------------------

  @IsTest
  static void handlersShareValuesThroughTheirJob() {
    Async.synchronousInTests = true;
    NoteTaker first = new NoteTaker('first');
    IJob chain = Async.queueable(first).then(Async.queueable(new NoteTaker('second')));
    chain.setShared('note', 'start');

    chain.run();

    expectTrail(new List<String>{ 'first=start', 'second=first' });
    Assert.areEqual('second', chain.getShared('note'), 'one map for the whole chain');
    Assert.isNull(first.job, 'the job is taken back once the handler is done');
  }

  @IsTest
  static void batchHandlersHaveTheirJobInEveryPhase() {
    Async.synchronousInTests = true;
    PhaseWatcher watcher = new PhaseWatcher();

    Async.iterable(watcher).run();

    expectTrail(new List<String>{ 'start:true', 'execute:true', 'finish:true' });
    Assert.isNull(watcher.job);
  }

  // --- then() and chain() -------------------------------------------------------------------------

  @IsTest
  static void thenAppendsAtTheEndAndReturnsTheFirstJob() {
    Async.synchronousInTests = true;
    Probe first = new Probe('a');

    IJob returned = first.then(new Probe('b')).then(new Probe('c'));
    returned.run();

    Assert.isTrue(returned === first, 'then() returns the job it was called on');
    expectTrail(new List<String>{ 'a', 'b', 'c' });
  }

  @IsTest
  static void thenIgnoresNull() {
    Async.synchronousInTests = true;
    Probe only = new Probe('only');

    Assert.isTrue(only.then(null) === only);
    only.run();

    expectTrail(new List<String>{ 'only' });
  }

  @IsTest
  static void thenAppendsAnExistingChainAsAWhole() {
    Async.synchronousInTests = true;
    Probe head = new Probe('a');

    head.then(new Probe('b').then(new Probe('c'))).then(new Probe('d'));
    head.run();

    expectTrail(new List<String>{ 'a', 'b', 'c', 'd' });
  }

  @IsTest
  static void thenRejectsAJobAlreadyInTheChain() {
    Probe a = new Probe('a');
    Probe b = new Probe('b');
    a.then(b);

    for (Probe repeat : new List<Probe>{ a, b }) {
      try {
        a.then(repeat);
        Assert.fail('a job must not be chained twice');
      } catch (Chainable.ChainableException expected) {
        Assert.isTrue(expected.getMessage().contains('only once'));
      }
    }
  }

  @IsTest
  static void chainLinksJobsInListOrder() {
    Async.synchronousInTests = true;

    Chainable head = Chainable.chain(
      new List<Chainable>{ new Probe('x'), new Probe('y'), new Probe('z') }
    );
    head.run();

    expectTrail(new List<String>{ 'x', 'y', 'z' });
    Assert.isNull(Chainable.chain(new List<Chainable>()));
    Assert.isNull(Chainable.chain(null));
  }

  // --- shared variables ---------------------------------------------------------------------------

  @IsTest
  static void sharedValuesReachEveryJobInTheChain() {
    Async.synchronousInTests = true;
    Probe first = new Probe('a');
    Probe second = new Probe('b');
    Probe third = new Probe('c');
    second.readsKey = 'k';
    third.readsKey = 'k';

    first.then(second).then(third);
    first.setShared('k', 42);
    first.run();

    expectTrail(new List<String>{ 'a', 'b=42', 'c=42' });
  }

  @IsTest
  static void chainingMergesValuesAndKeepsTheChainsOwn() {
    Probe first = new Probe('a');
    first.setShared('color', 'red');
    Probe joining = new Probe('b');
    joining.setShared('color', 'blue');
    joining.setShared('size', 'large');

    first.then(joining);

    Assert.areEqual('red', joining.getShared('color'), 'the chain keeps its value');
    Assert.areEqual('large', first.getShared('size'), 'new keys join the chain');
  }

  @IsTest
  static void valuesWrittenByOneJobAreReadByLaterJobs() {
    Async.synchronousInTests = true;
    Probe writer = new Probe('writer');
    writer.writesKey = 'author';
    Probe reader = new Probe('reader');
    reader.readsKey = 'author';

    writer.then(new Probe('between')).then(reader);
    writer.run();

    expectTrail(new List<String>{ 'writer', 'between', 'reader=writer' });
  }

  // --- limits -------------------------------------------------------------------------------------

  @IsTest
  static void tooManyWaitingJobsAreRejected() {
    Async.synchronousInTests = true;
    Chainable.maxWaiting = 2;
    Probe head = new Probe('a');
    head.then(new Probe('b')).then(new Probe('c')).then(new Probe('d'));

    try {
      head.run();
      Assert.fail('three waiting jobs exceed a limit of two');
    } catch (Chainable.ChainableException expected) {
      Assert.isTrue(expected.getMessage().contains('at most 2'));
    }
    expectTrail(new List<String>());
  }

  @IsTest
  static void chainsLongerThanTheLimitAreRejected() {
    Async.synchronousInTests = true;
    Chainable.maxLength = 3;
    Probe head = new Probe('a');
    head.then(new Probe('b')).then(new Probe('c')).then(new Probe('d'));

    try {
      head.run();
      Assert.fail('four jobs exceed a limit of three');
    } catch (Chainable.ChainableException expected) {
      Assert.isTrue(expected.getMessage().contains('limit of 3'));
    }
    expectTrail(new List<String>());
  }

  @IsTest
  static void runawayRecursionStopsAtTheLengthLimit() {
    Async.synchronousInTests = true;
    Chainable.maxLength = 5;

    try {
      new Runaway().run();
      Assert.fail('a job that keeps starting itself must be stopped');
    } catch (Chainable.ChainableException expected) {
      Assert.isTrue(expected.getMessage().contains('limit of 5'));
    }
    Assert.isTrue(trail.size() > 1 && trail.size() <= 5, String.valueOf(trail));
  }

  // --- capture modes ------------------------------------------------------------------------------

  @IsTest
  static void ignoredJobsNeverRun() {
    Async.synchronousInTests = true;
    Probe parent = new Probe('parent')
      .starting(new Probe('ignored').nestedAs(Enums.CaptureMode.IGNORE));
    parent.then(new Probe('next'));

    parent.run();

    expectTrail(new List<String>{ 'parent', 'next' });
  }

  @IsTest
  static void synchronousJobsFinishBeforeTheChainMovesOn() {
    Async.synchronousInTests = true;
    Probe inline = new Probe('inline').nestedAs(Enums.CaptureMode.SYNCHRONOUS);
    Probe parent = new Probe('parent').starting(inline);
    parent.then(new Probe('next'));

    parent.run();

    expectTrail(new List<String>{ 'parent', 'inline', 'next' });
    Assert.isNull(inline.getJobId(), 'it ran in the same transaction');
  }

  @IsTest
  static void releasedJobsRunAheadOfTheWaitingJobsInTests() {
    Async.synchronousInTests = true;
    Probe parent = new Probe('parent')
      .starting(new Probe('released').nestedAs(Enums.CaptureMode.RELEASE));
    parent.then(new Probe('next'));

    parent.run();

    expectTrail(new List<String>{ 'parent', 'released', 'next' });
  }

  @IsTest
  static void immediateJobsShareOneBundle() {
    Async.synchronousInTests = true;
    QueueableBundle.executions = 0;
    Probe parent = new Probe('parent')
      .starting(new Probe('first').nestedAs(Enums.CaptureMode.IMMEDIATE))
      .starting(new Probe('second').nestedAs(Enums.CaptureMode.IMMEDIATE));
    parent.then(new Probe('next'));

    parent.run();

    expectTrail(new List<String>{ 'parent', 'first', 'second', 'next' });
    Assert.areEqual(1, QueueableBundle.executions, 'both rode in one bundle');
  }

  @IsTest
  static void prependAndAppendWrapTheWaitingJobs() {
    Async.synchronousInTests = true;
    Probe parent = new Probe('parent')
      .starting(new Probe('appended').nestedAs(Enums.CaptureMode.APPEND))
      .starting(new Probe('prepended').nestedAs(Enums.CaptureMode.PREPEND));
    parent.then(new Probe('next'));

    parent.run();

    expectTrail(new List<String>{ 'parent', 'prepended', 'next', 'appended' });
  }

  @IsTest
  static void everyModeLandsInItsPlace() {
    Async.synchronousInTests = true;
    Probe parent = new Probe('parent')
      .starting(new Probe('append').nestedAs(Enums.CaptureMode.APPEND))
      .starting(new Probe('ignore').nestedAs(Enums.CaptureMode.IGNORE))
      .starting(new Probe('prepend').nestedAs(Enums.CaptureMode.PREPEND))
      .starting(new Probe('immediate').nestedAs(Enums.CaptureMode.IMMEDIATE))
      .starting(new Probe('release').nestedAs(Enums.CaptureMode.RELEASE))
      .starting(new Probe('synchronous').nestedAs(Enums.CaptureMode.SYNCHRONOUS));
    parent.then(new Probe('next'));

    parent.run();

    expectTrail(
      new List<String>{
        'parent',
        'synchronous',
        'release',
        'immediate',
        'prepend',
        'next',
        'append'
      }
    );
  }

  @IsTest
  static void capturedJobsShareTheParentsValues() {
    Async.synchronousInTests = true;
    Probe child = new Probe('child');
    child.readsKey = 'origin';
    Probe parent = new Probe('parent').starting(child);
    parent.setShared('origin', 'parent');

    parent.run();

    expectTrail(new List<String>{ 'parent', 'child=parent' });
  }

  @IsTest
  static void aCapturedJobKeepsItsOwnSuccessors() {
    Async.synchronousInTests = true;
    Probe child = new Probe('child');
    child.then(new Probe('grandchild'));
    Probe parent = new Probe('parent').starting(child);
    parent.then(new Probe('next'));

    parent.run();

    // The grandchild is started from inside the bundle, so it finishes before the parent's chain moves on.
    expectTrail(new List<String>{ 'parent', 'child', 'grandchild', 'next' });
  }

  @IsTest
  static void jobsStartedByCapturedJobsAreCapturedToo() {
    Async.synchronousInTests = true;
    Probe parent = new Probe('parent')
      .starting(new Probe('child').starting(new Probe('grandchild')));

    parent.run();

    expectTrail(new List<String>{ 'parent', 'child', 'grandchild' });
  }

  // --- choosing a capture mode --------------------------------------------------------------------

  @IsTest
  static void platformDefaultsApplyWhenNobodyChooses() {
    Chainable queueable = (Chainable) Async.queueable(new QuietQueueable());
    Chainable batch = (Chainable) Async.iterable(new QuietIterable());
    Chainable schedulable = (Chainable) Async.schedulable(new QuietSchedulable());
    Enums.CaptureMode immediate = Enums.CaptureMode.IMMEDIATE;
    Enums.CaptureMode release = Enums.CaptureMode.RELEASE;

    Assert.areEqual(immediate, Async.getCaptureMode(queueable, queueable));
    Assert.areEqual(release, Async.getCaptureMode(queueable, batch));
    Assert.areEqual(release, Async.getCaptureMode(queueable, schedulable));
    Assert.areEqual(immediate, Async.getCaptureMode(batch, queueable));
    Assert.areEqual(release, Async.getCaptureMode(batch, batch));
    Assert.areEqual(release, Async.getCaptureMode(batch, schedulable));
    Assert.areEqual(release, Async.getCaptureMode(schedulable, queueable));
    Assert.areEqual(release, Async.getCaptureMode(schedulable, batch));
    Assert.areEqual(release, Async.getCaptureMode(schedulable, schedulable));
  }

  @IsTest
  static void theParentJobChoosesFirst() {
    Probe parent = new Probe('parent');
    Probe child = new Probe('child').nestedAs(Enums.CaptureMode.APPEND);

    Assert.areEqual(Enums.CaptureMode.APPEND, Async.getCaptureMode(parent, child));

    child.nestedAs(null);
    Assert.areEqual(
      Enums.CaptureMode.IMMEDIATE,
      Async.getCaptureMode(parent, child),
      'no choice falls through to the platform default'
    );
  }

  @IsTest
  static void aCapturingHandlerChoosesNext() {
    Async.synchronousInTests = true;
    CapturingHandler handler = new CapturingHandler();
    handler.mode = Enums.CaptureMode.IGNORE;
    handler.startsInside.add(new Probe('dropped'));
    Chainable parent = (Chainable) Async.queueable(handler);

    Assert.areEqual(
      Enums.CaptureMode.IGNORE,
      Async.getCaptureMode(parent, new Probe('any'))
    );
    parent.run();
    expectTrail(new List<String>{ 'handler' });

    handler.mode = null;
    Assert.areEqual(
      Enums.CaptureMode.IMMEDIATE,
      Async.getCaptureMode(parent, new Probe('any'))
    );
  }

  // --- failures -----------------------------------------------------------------------------------

  @IsTest
  static void aFailedJobStopsItsChainAndCapturesNothingMore() {
    Async.synchronousInTests = true;
    Probe failing = new Probe('failing').starting(new Probe('started before failing'));
    failing.fails = true;
    failing.then(new Probe('next'));

    try {
      failing.run();
      Assert.fail('the failure must reach the caller');
    } catch (IllegalArgumentException expected) {
      Assert.isTrue(expected.getMessage().contains('failing'));
    }
    expectTrail(new List<String>{ 'failing' });

    new Probe('later').run();
    expectTrail(new List<String>{ 'failing', 'later' });
  }

  @IsTest
  static void aBatchReleasedInsideABatchIsCarriedOutByAQueueable() {
    Chainable queueable = (Chainable) Async.queueable(new QuietQueueable());
    Chainable batch = (Chainable) Async.iterable(new QuietIterable());
    Chainable another = (Chainable) Async.iterable(new QuietIterable());
    Chainable schedulable = (Chainable) Async.schedulable(new QuietSchedulable());

    // The platform refuses to start a batch from another batch's start or execute.
    Assert.isTrue(Chainable.mustBeCarried(batch, Chainable.Phase.START, another));
    Assert.isTrue(Chainable.mustBeCarried(batch, Chainable.Phase.SCOPE, another));
    // From finish it may, and other kinds of job may be started from anywhere in a batch.
    Assert.isFalse(Chainable.mustBeCarried(batch, Chainable.Phase.FINISH, another));
    Assert.isFalse(Chainable.mustBeCarried(batch, Chainable.Phase.SCOPE, queueable));
    Assert.isFalse(Chainable.mustBeCarried(batch, Chainable.Phase.SCOPE, schedulable));
    // A queueable or a scheduled job may start a batch.
    Assert.isFalse(Chainable.mustBeCarried(queueable, Chainable.Phase.BODY, batch));
    Assert.isFalse(Chainable.mustBeCarried(schedulable, Chainable.Phase.BODY, batch));
  }
}
