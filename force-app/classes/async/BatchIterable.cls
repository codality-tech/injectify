/** Batch over any Iterable. Subclasses supply the items in start() and the work in execute(chunk). */
public abstract class BatchIterable extends Batch implements IBatchIterable {
  /** Called once per scope transaction with the next chunk of items. */
  public abstract void execute(Iterable<Object> chunk);

  /** Supplies every item the batch will process. */
  public abstract Iterable<Object> start();

  protected override void processScope(Iterable<Object> chunk) {
    execute(chunk);
  }

  protected override Iterable<Object> startScope() {
    return start();
  }
}
