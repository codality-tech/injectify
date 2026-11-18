/** Runs an IBatchQueryableHandler as a chainable batch. */
public class HandleableBatchQueryable extends BatchQueryable implements IHandleable {
  private IBatchQueryableHandler handler;

  public override IQuery start() {
    return handler.batchStart();
  }

  public HandleableBatchQueryable(IBatchQueryableHandler handler) {
    this.handler = handler;
  }

  public override Integer getDefaultBatchSize() {
    return handler.batchDefaultSize();
  }

  public IHandler getHandler() {
    return handler;
  }

  public override void execute(List<SObject> slice) {
    handler.batchExecute(slice);
  }

  public override void finish() {
    handler.batchFinish();
  }
}
