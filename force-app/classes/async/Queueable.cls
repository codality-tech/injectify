/** Queueable flavor. Subclasses put their work in execute(). */
public abstract class Queueable extends Chainable implements IQueueable, System.Queueable, Database.AllowsCallouts {
  @TestVisible
  private Integer delayMinutes;

  public abstract void execute();

  /** Platform entry point. */
  public void execute(QueueableContext context) {
    if (context != null) {
      jobId = context.getJobId();
    }
    step(Chainable.Phase.BODY, null);
    continueChain();
  }

  /** Delays the enqueue by 0 to 10 minutes. Values outside that range are ignored. */
  public IQueueable setMinuteDelay(Integer minuteDelay) {
    if (minuteDelay != null && minuteDelay >= 0 && minuteDelay <= 10) {
      delayMinutes = minuteDelay;
    }
    return this;
  }

  protected override Object perform(Chainable.Phase phase, Object input) {
    execute();
    return null;
  }

  protected override void runInline() {
    step(Chainable.Phase.BODY, null);
  }

  protected override Id submit() {
    if (delayMinutes == null) {
      return System.enqueueJob(this);
    }
    return System.enqueueJob(this, delayMinutes);
  }
}
