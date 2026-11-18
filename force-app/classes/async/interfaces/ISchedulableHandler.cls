global interface ISchedulableHandler extends IHandler {
  void schedulableExecute();
  String name();
  String cronExpression();
}
