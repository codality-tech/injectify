/**
 * Batch flavor. BatchIterable and BatchQueryable supply the scope; subclasses of those supply the
 * work. Stateful, so the chain and shared variables survive between scope transactions.
 */
public abstract class Batch extends Chainable implements IBatch, Database.Batchable<Object>, Database.Stateful, Database.AllowsCallouts {
  private static final Integer FALLBACK_SIZE = 200;

  private Integer chosenSize;

  protected abstract Iterable<Object> startScope();
  protected abstract void processScope(Iterable<Object> scope);

  /** Runs once after every scope has been processed. */
  public virtual void finish() {
  }

  /** Scope size used when setBatchSize() was not called. */
  public virtual Integer getDefaultBatchSize() {
    return FALLBACK_SIZE;
  }

  public IBatch setBatchSize(Integer batchSize) {
    if (batchSize == null || batchSize < 1) {
      throw new ChainableException(
        'Batch size must be a positive number, got ' + batchSize
      );
    }
    chosenSize = batchSize;
    return this;
  }

  @TestVisible
  private Integer effectiveBatchSize() {
    if (chosenSize != null) {
      return chosenSize;
    }
    Integer preferred = getDefaultBatchSize();
    return preferred == null || preferred < 1 ? FALLBACK_SIZE : preferred;
  }

  // Platform entry points ------------------------------------------------------------------------

  public Iterable<Object> start(Database.BatchableContext context) {
    track(context);
    return (Iterable<Object>) step(Chainable.Phase.START, null);
  }

  public void execute(Database.BatchableContext context, Iterable<Object> scope) {
    track(context);
    step(Chainable.Phase.SCOPE, scope);
  }

  public void finish(Database.BatchableContext context) {
    track(context);
    step(Chainable.Phase.FINISH, null);
    continueChain();
  }

  // Chainable ------------------------------------------------------------------------------------

  protected override Object perform(Chainable.Phase phase, Object input) {
    if (phase == Chainable.Phase.START) {
      return startScope();
    }
    if (phase == Chainable.Phase.SCOPE) {
      processScope((Iterable<Object>) input);
    } else {
      finish();
    }
    return null;
  }

  // Inline runs hand the whole scope to a single execute, as one transaction would see it.
  protected override void runInline() {
    Iterable<Object> scope = (Iterable<Object>) step(Chainable.Phase.START, null);
    if (scope != null && scope.iterator().hasNext()) {
      step(Chainable.Phase.SCOPE, scope);
    }
    step(Chainable.Phase.FINISH, null);
  }

  protected override Id submit() {
    return Database.executeBatch(this, effectiveBatchSize());
  }

  private void track(Database.BatchableContext context) {
    if (context?.getJobId() != null) {
      jobId = context.getJobId();
    }
  }
}
