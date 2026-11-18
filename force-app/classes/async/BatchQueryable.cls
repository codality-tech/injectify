/**
 * Batch over the records an IQuery returns. Subclasses implement start() and execute(records).
 * Conditions added through filters() narrow the query before it runs.
 */
public abstract class BatchQueryable extends Batch implements IBatchQueryable {
  private ILogicalCondition narrowing;

  public abstract IQuery start();
  public abstract void execute(List<SObject> scope);

  /** An AND group applied to the query from start(). Empty means no extra conditions. */
  public ILogicalCondition filters() {
    if (narrowing == null) {
      narrowing = Application.s.all(null);
    }
    return narrowing;
  }

  // Inline runs read the rows directly; the platform gets a query locator.
  protected override Iterable<Object> startScope() {
    IQuery query = start();
    if (narrowing != null && !narrowing.getAll().isEmpty()) {
      query.addCondition(narrowing);
    }
    if (runsInline()) {
      return (Iterable<Object>) query.run();
    }
    return (Iterable<Object>) query.toLocator();
  }

  protected override void processScope(Iterable<Object> scope) {
    execute((List<SObject>) scope);
  }
}
