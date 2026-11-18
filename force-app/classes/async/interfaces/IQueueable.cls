global interface IQueueable extends IJob {
  // Queueable configuration
  IQueueable setMinuteDelay(Integer minuteDelay);
  void execute();
}
