/** Runs an IBatchIterableHandler as a chainable batch. */
public class HandleableBatchIterable extends BatchIterable implements IHandleable {
  private IBatchIterableHandler handler;

  public override Iterable<Object> start() {
    return handler.batchStart();
  }

  public HandleableBatchIterable(IBatchIterableHandler handler) {
    this.handler = handler;
  }

  public override Integer getDefaultBatchSize() {
    return handler.batchDefaultSize();
  }

  public IHandler getHandler() {
    return handler;
  }

  public override void execute(Iterable<Object> chunk) {
    handler.batchExecute(chunk);
  }

  public override void finish() {
    handler.batchFinish();
  }
}
