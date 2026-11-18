/**
 * Base class for every job in the async layer.
 *
 * The chaining idea (then(), a link to the job that runs next, and a variable map shared along
 * the chain) follows rsoesemann/apex-chainable, MIT License, Copyright (c) 2019 Robert Sösemann.
 * See NOTICE in the repository root. Capture, bundling and the chain limits are this framework's.
 *
 * Capture: while a job's body is executing, any other job started with run() is first offered to
 * the innermost executing job. Async.getCaptureMode() picks a mode, and the job is held until the
 * body finishes, then started, bundled, re-chained or dropped according to that mode. Business
 * code can call run() anywhere without knowing which async context it is in.
 */
public abstract class Chainable implements IJob {
  public class ChainableException extends Exception {
  }

  /** The unit of work a flavor is asked to perform. Queueable and Schedulable use BODY only. */
  public enum Phase {
    BODY,
    START,
    SCOPE,
    FINISH
  }

  // ---------------------------------------------------------------------------------------------
  // Flavor contract
  // ---------------------------------------------------------------------------------------------

  /** Do the work of one phase. Only called through step(), which handles capture. */
  protected abstract Object perform(Phase phase, Object input);

  /** Run every phase in this transaction (tests, forced-inline jobs). */
  protected abstract void runInline();

  /** Hand the job to the platform and return the id it assigns. */
  protected abstract Id submit();

  // ---------------------------------------------------------------------------------------------
  // Chain
  // ---------------------------------------------------------------------------------------------

  @TestVisible
  private static Integer maxWaiting = 20;
  @TestVisible
  private static Integer maxLength = 40;

  private Chainable next;
  private Integer depth = 0; // jobs that already completed ahead of this one in its lineage
  private Map<String, Object> shared = new Map<String, Object>();
  protected Id jobId;

  public IJob then(IJob successor) {
    Chainable incoming = (Chainable) successor;
    if (incoming == null) {
      return this;
    }
    for (Chainable candidate = incoming; candidate != null; candidate = candidate.next) {
      for (Chainable member = this; member != null; member = member.next) {
        if (candidate === member) {
          throw new ChainableException(
            'A job can appear only once in a chain: ' + member.typeName()
          );
        }
      }
    }
    lastInChain().next = incoming;
    shareWith(incoming);
    return this;
  }

  /** Links the jobs in list order and returns the first one, or null when there is none. */
  public static Chainable chain(List<Chainable> jobs) {
    Chainable first;
    if (jobs != null) {
      for (Chainable job : jobs) {
        if (first == null) {
          first = job;
        } else {
          first.then(job);
        }
      }
    }
    return first;
  }

  public IJob setShared(String key, Object value) {
    shared.put(key, value);
    return this;
  }

  public Object getShared(String key) {
    return shared.get(key);
  }

  public Id getJobId() {
    return jobId;
  }

  private Chainable lastInChain() {
    Chainable last = this;
    while (last.next != null) {
      last = last.next;
    }
    return last;
  }

  private Integer waitingCount() {
    Integer count = 0;
    for (Chainable member = next; member != null; member = member.next) {
      count++;
    }
    return count;
  }

  // Points every job from `first` onward at this chain's map. Keys already on the chain win.
  private void shareWith(Chainable first) {
    for (Chainable member = first; member != null; member = member.next) {
      if (member.shared === shared) {
        continue;
      }
      for (String key : member.shared.keySet()) {
        if (!shared.containsKey(key)) {
          shared.put(key, member.shared.get(key));
        }
      }
      member.shared = shared;
    }
  }

  // Makes `follower` (and anything chained behind it) part of this job's lineage.
  private void adopt(Chainable follower) {
    shareWith(follower);
    follower.depth = depth + 1;
  }

  // Guards against runaway chains, such as a job that keeps starting itself.
  private void checkLimits() {
    Integer waiting = waitingCount();
    if (waiting > maxWaiting) {
      throw new ChainableException(
        waiting +
          ' jobs are waiting behind ' +
          typeName() +
          '; at most ' +
          maxWaiting +
          ' may wait'
      );
    }
    Integer total = depth + 1 + waiting;
    if (total > maxLength) {
      throw new ChainableException(
        'A chain of ' + total + ' jobs exceeds the limit of ' + maxLength
      );
    }
  }

  // ---------------------------------------------------------------------------------------------
  // Running
  // ---------------------------------------------------------------------------------------------

  private Boolean forceInline = false;

  public IJob run() {
    checkLimits();
    if (!offerForCapture()) {
      launch();
    }
    return this;
  }

  /** True when this job runs in the current transaction instead of going to the platform. */
  protected Boolean runsInline() {
    return forceInline ||
      (Test.isRunningTest() && Async.synchronousInTests == true);
  }

  // Starts the job without offering it for capture.
  private void launch() {
    if (runsInline()) {
      runInline();
      continueChain();
    } else {
      jobId = submit();
    }
  }

  /** Called when this job is done: passes control to the next job, if any. */
  protected void continueChain() {
    Chainable successor = next;
    if (successor == null) {
      return;
    }
    next = null;
    adopt(successor);
    successor.run();
  }

  /** Runs one phase with capture on. Every platform entry point and inline run goes through here. */
  protected Object step(Phase phase, Object input) {
    executing.add(this);
    Boolean completed = false;
    Object result;
    try {
      result = performLending(phase, input);
      completed = true;
    } finally {
      stepOff(phase, completed);
    }
    return result;
  }

  /**
   * Runs this job inside a bundle's transaction. A queueable's body runs right here, so the jobs it
   * starts are captured by the bundle, and its own successors are offered to the bundle as well.
   * Other flavors cannot run inside a queueable, so they go through run() and the capture rules.
   */
  protected void runBundled(Chainable bundle) {
    bundle.adopt(this);
    depth = bundle.depth;
    if (this instanceof Queueable) {
      jobId = bundle.jobId;
      performLending(Phase.BODY, null);
      continueChain();
    } else {
      run();
    }
  }

  // Runs a phase with the job lent to a handler that implements IJobAware. The job is taken back
  // afterwards, so it is never serialized through its own handler.
  private Object performLending(Phase phase, Object input) {
    IJobAware aware = jobAwareHandler();
    if (aware == null) {
      return perform(phase, input);
    }
    aware.setJob(this);
    try {
      return perform(phase, input);
    } finally {
      aware.setJob(null);
    }
  }

  private IJobAware jobAwareHandler() {
    IHandler handler = this instanceof IHandleable ? ((IHandleable) this).getHandler() : null;
    return handler instanceof IJobAware ? (IJobAware) handler : null;
  }

  protected String typeName() {
    return String.valueOf(this).substringBefore(':');
  }

  // ---------------------------------------------------------------------------------------------
  // Capture
  // ---------------------------------------------------------------------------------------------

  // Jobs whose phase is executing right now, innermost last.
  private static List<Chainable> executing = new List<Chainable>();

  // Jobs captured during the current phase, by mode.
  private Map<Enums.CaptureMode, List<Chainable>> held;

  /**
   * First say in how a job started inside this one is captured. Return null to defer to the
   * handler (IHandlerCapturing) and then to the platform defaults in Async.getCaptureMode().
   */
  public virtual Enums.CaptureMode captureModeFor(Chainable child) {
    return null;
  }

  private Boolean offerForCapture() {
    if (executing.isEmpty()) {
      return false;
    }
    Chainable capturer = executing[executing.size() - 1];
    if (capturer === this) {
      return false;
    }
    Enums.CaptureMode mode = Async.getCaptureMode(capturer, this);
    if (mode == null) {
      return false;
    }
    capturer.hold(mode, this);
    return true;
  }

  private void hold(Enums.CaptureMode mode, Chainable job) {
    if (held == null) {
      held = new Map<Enums.CaptureMode, List<Chainable>>();
    }
    if (!held.containsKey(mode)) {
      held.put(mode, new List<Chainable>());
    }
    held.get(mode).add(job);
  }

  private void stepOff(Phase phase, Boolean completed) {
    Integer position = executing.size() - 1;
    while (position >= 0 && executing[position] !== this) {
      position--;
    }
    while (position >= 0 && executing.size() > position) {
      executing.remove(executing.size() - 1);
    }
    if (completed) {
      releaseHeld(phase);
    } else {
      held = null; // the phase failed, so nothing it started should run
    }
  }

  /**
   * Whether the platform would refuse to start `job` in the transaction that runs `phase` of
   * `capturer`: a batch cannot be started from another batch's start or execute, only from its
   * finish. Such a job is carried out by a queueable, which may start it.
   */
  @TestVisible
  private static Boolean mustBeCarried(Chainable capturer, Phase phase, Chainable job) {
    return capturer instanceof Batch && job instanceof Batch && phase != Chainable.Phase.FINISH;
  }

  // Order of the rebuilt chain: RELEASE (tests only), the IMMEDIATE bundle, PREPEND, the jobs that
  // were already waiting, APPEND. SYNCHRONOUS jobs finish before any of that. IGNORE is dropped.
  private void releaseHeld(Phase phase) {
    if (held == null) {
      return;
    }
    Map<Enums.CaptureMode, List<Chainable>> captured = held;
    held = null;

    for (Chainable job : heldAs(captured, Enums.CaptureMode.SYNCHRONOUS)) {
      adopt(job);
      job.forceInline = true;
      job.launch();
    }

    List<Chainable> rebuilt = new List<Chainable>();
    List<Chainable> carried = new List<Chainable>();
    for (Chainable job : heldAs(captured, Enums.CaptureMode.RELEASE)) {
      if (Test.isRunningTest()) {
        rebuilt.add(job); // tests cannot start async work from async work, so it waits its turn
      } else if (mustBeCarried(this, phase, job)) {
        carried.add(job);
      } else {
        adopt(job);
        job.run();
      }
    }

    // Carried jobs share the one queueable with the IMMEDIATE jobs: a batch transaction may
    // enqueue a single job. Inside the bundle each is released again, and so starts on its own.
    List<Chainable> bundled = new List<Chainable>(heldAs(captured, Enums.CaptureMode.IMMEDIATE));
    bundled.addAll(carried);
    if (!bundled.isEmpty()) {
      Chainable bundle = new QueueableBundle(bundled);
      adopt(bundle);
      bundle.forceInline = Test.isRunningTest();
      if (this instanceof Batch) {
        bundle.launch(); // a batch only moves its chain after finish, so the bundle goes now
      } else {
        rebuilt.add(bundle);
      }
    }

    rebuilt.addAll(heldAs(captured, Enums.CaptureMode.PREPEND));
    if (next != null) {
      rebuilt.add(next);
      next = null;
    }
    rebuilt.addAll(heldAs(captured, Enums.CaptureMode.APPEND));
    then(chain(rebuilt));
  }

  private static List<Chainable> heldAs(
    Map<Enums.CaptureMode, List<Chainable>> captured,
    Enums.CaptureMode mode
  ) {
    List<Chainable> jobs = captured.get(mode);
    return jobs == null ? new List<Chainable>() : jobs;
  }
}
