global class Async {
  /*
   * Test Configuration
   * Control whether async jobs run synchronously in test context
   */

  /** In a running test, true runs every job in the test's own transaction. Ignored outside tests. */
  global static Boolean synchronousInTests = false;

  /*
   * Factory Methods
   * Create chainable async instances using composition pattern
   */

  global static IQueueable queueable(IQueueableHandler handler) {
    return new HandleableQueueable(handler);
  }

  global static IBatchQueryable queryable(IBatchQueryableHandler handler) {
    return new HandleableBatchQueryable(handler);
  }

  global static IBatchIterable iterable(IBatchIterableHandler handler) {
    return new HandleableBatchIterable(handler);
  }

  global static ISchedulable schedulable(ISchedulableHandler handler) {
    return new HandleableSchedulable(handler);
  }

  /*
   * Capture Mode Resolution
   *
   * Determines how a parent async job should capture (enqueue/schedule) its child job.
   * Salesforce has strict limitations on which async job types can enqueue other types:
   *   - Queueable CAN enqueue another Queueable immediately (within execute context)
   *   - Queueable CANNOT schedule or start batch from within execute
   *   - Batch CANNOT schedule or start another batch from within execute
   *   - Schedulable CAN do anything but must be scheduled (not immediate)
   *
   * CAPTURE MODES:
   *   - IMMEDIATE: Enqueue child job immediately within parent's execute context
   *                (Only works for: Queueable→Queueable, Batch→Queueable)
   *   - RELEASE: Store child job info, enqueue after parent completes
   *              (Required for all Schedulable children, and unsupported immediate combos)
   *   - SYNCHRONOUS: Execute child handler synchronously (test mode)
   *   - PREPEND/APPEND: Insert child into chain before/after current job
   *   - IGNORE: Don't capture (used to break infinite loops)
   *
   * DECISION MATRIX (default behavior when no custom logic provided):
   *
   *   Parent ↓ \ Child →  | Queueable      | Schedulable    | Batchable
   *   --------------------|----------------|----------------|----------------
   *   Queueable           | IMMEDIATE      | RELEASE        | RELEASE
   *   Schedulable         | RELEASE        | RELEASE        | RELEASE
   *   Batchable           | IMMEDIATE      | RELEASE        | RELEASE
   *
   * RESOLUTION ORDER:
   *   1. Parent job's captureModeFor() (if overridden)
   *   2. Parent's handler's getCaptureMode() (if it implements IHandlerCapturing)
   *   3. Default matrix above (based on Salesforce platform constraints)
   *
   * @param parentJob The parent async job that is capturing the child
   * @param childJob The child async job being captured
   * @return CaptureMode enum indicating how to capture the child
   */
  public static Enums.CaptureMode getCaptureMode(
    Chainable parentJob,
    Chainable childJob
  ) {
    Enums.CaptureMode ret = null;

    // First: Check if parent job has custom capture logic
    ret = parentJob.captureModeFor(childJob);

    // Second: Check if parent has a handler with custom capture logic
    if (ret == null && parentJob instanceof IHandleable) {
      IHandler handler = ((IHandleable) parentJob).getHandler();
      if (handler instanceof IHandlerCapturing) {
        ret = ((IHandlerCapturing) handler).getCaptureMode(parentJob, childJob);
      }
    }
    if (ret == null) {
      // Default capture mode based on Salesforce job type restrictions
      // Parent determines how to capture child based on platform constraints
      if (parentJob instanceof System.Queueable) {
        if (childJob instanceof System.Queueable) {
          ret = Enums.CaptureMode.IMMEDIATE; // QueueableJob CAN chain another queueable
        } else if (childJob instanceof System.Schedulable) {
          ret = Enums.CaptureMode.RELEASE; // QueueableJob CANNOT schedule from execute()
        } else if (childJob instanceof Database.Batchable<Object>) {
          ret = Enums.CaptureMode.RELEASE; // QueueableJob CANNOT start batch from execute()
        }
      } else if (parentJob instanceof System.Schedulable) {
        if (childJob instanceof System.Queueable) {
          ret = Enums.CaptureMode.RELEASE; // SchedulableJob runs at scheduled time
        } else if (childJob instanceof System.Schedulable) {
          ret = Enums.CaptureMode.RELEASE; // SchedulableJob cannot schedule immediately
        } else if (childJob instanceof Database.Batchable<Object>) {
          ret = Enums.CaptureMode.RELEASE; // SchedulableJob runs at scheduled time
        }
      } else if (parentJob instanceof Database.Batchable<Object>) {
        if (childJob instanceof System.Queueable) {
          ret = Enums.CaptureMode.IMMEDIATE; // Batch CAN enqueue queueable from finish()
        } else if (childJob instanceof System.Schedulable) {
          ret = Enums.CaptureMode.RELEASE; // Batch CANNOT schedule from finish()
        } else if (childJob instanceof Database.Batchable<Object>) {
          ret = Enums.CaptureMode.RELEASE; // Batch CANNOT start another batch from finish()
        }
      }
    }
    return ret;
  }
}
