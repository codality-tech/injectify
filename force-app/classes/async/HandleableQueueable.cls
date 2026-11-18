public class HandleableQueueable extends QueueableJob implements IHandleable {
  private IQueueableHandler handler;

  public HandleableQueueable(IQueueableHandler handler) {
    this.handler = handler;
  }

  public override void execute() {
    handler.queueableExecute();
  }

  public IHandler getHandler() {
    return handler;
  }
}
