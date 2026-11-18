global interface ISchedulable extends IJob {
  // Schedulable configuration and control
  void execute();
  String name();
  String cronExpression();
  String toCronExpression(Datetime dt);
  void unschedule();
}
