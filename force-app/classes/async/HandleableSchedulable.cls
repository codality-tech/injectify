public class HandleableSchedulable extends SchedulableJob implements IHandleable {
  private ISchedulableHandler handler;

  public HandleableSchedulable(ISchedulableHandler handler) {
    this.handler = handler;
  }

  public override void execute() {
    handler.schedulableExecute();
  }

  /** The handler's name, or its class name when it gives none. */
  public override String name() {
    String named = handler.name();
    return String.isBlank(named) ? String.valueOf(handler).substringBefore(':') : named;
  }

  /** The handler's schedule, or one minute from now when it gives none. */
  public override String cronExpression() {
    String schedule = handler.cronExpression();
    return String.isBlank(schedule) ? super.cronExpression() : schedule;
  }

  public IHandler getHandler() {
    return handler;
  }
}
