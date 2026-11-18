/** Schedulable flavor. Subclasses put their work in execute() and may override name() and cronExpression(). */
public abstract inherited sharing class Schedulable extends Chainable implements System.Schedulable, Database.AllowsCallouts, ISchedulable {
  /** The scheduled job's name. Defaults to the class name. */
  public virtual String name() {
    return typeName();
  }

  /** When to run. Defaults to one minute from now. */
  public virtual String cronExpression() {
    Datetime inAMinute = Datetime.now().addMinutes(1);
    return toCronExpression(inAMinute);
  }

  /** Platform entry point. */
  public void execute(SchedulableContext context) {
    if (context != null) {
      jobId = context.getTriggerId();
    }
    step(Chainable.Phase.BODY, null);
    continueChain();
  }

  /** The work to do when the schedule fires. */
  public abstract void execute();

  /** A one-time cron expression for the given moment: seconds minutes hours day month ? year. */
  public String toCronExpression(Datetime moment) {
    return String.join(
      new List<Object>{
        moment.second(),
        moment.minute(),
        moment.hour(),
        moment.day(),
        moment.month(),
        '?',
        moment.year()
      },
      ' '
    );
  }

  /** Aborts every scheduled job with this job's name. */
  public void unschedule() {
    String jobName = name();
    for (CronTrigger scheduled : [
      SELECT Id
      FROM CronTrigger
      WHERE CronJobDetail.Name = :jobName
      WITH SYSTEM_MODE
    ]) {
      System.abortJob(scheduled.Id);
    }
  }

  protected override Object perform(Chainable.Phase phase, Object input) {
    execute();
    return null;
  }

  protected override void runInline() {
    step(Chainable.Phase.BODY, null);
  }

  protected override Id submit() {
    String jobName = name();
    return System.schedule(jobName, cronExpression(), this);
  }
}
