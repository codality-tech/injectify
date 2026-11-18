/** A job that can be chained and run; see Async for the factories. */
global interface IJob {
  /** Adds a job to the end of this chain; returns this job. */
  IJob then(IJob successor);
  IJob run();
  Id getJobId();
  /** A value shared by every job in the chain, including jobs added later. */
  IJob setShared(String key, Object value);
  Object getShared(String key);
}
