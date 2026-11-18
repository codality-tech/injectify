/**
 * Carries every job captured in IMMEDIATE mode during one phase, and runs them one after another
 * in a single queueable transaction. N captured jobs cost one enqueue, which keeps the caller
 * under the platform's limit on how many queueables an async transaction may start.
 */
public class QueueableBundle extends Queueable {
  @TestVisible
  private static Integer executions = 0;

  private List<Chainable> jobs;

  public QueueableBundle(List<Chainable> jobs) {
    this.jobs = jobs;
  }

  public override void execute() {
    executions++;
    for (Chainable job : jobs) {
      job.runBundled(this);
    }
  }
}
