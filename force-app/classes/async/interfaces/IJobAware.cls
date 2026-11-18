/**
 * A handler that wants its job while it runs, to read and write the values shared along the
 * chain. The job is set just before each handler call and cleared right after.
 */
global interface IJobAware extends IHandler {
  void setJob(IJob job);
}
