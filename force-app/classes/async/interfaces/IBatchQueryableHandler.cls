global interface IBatchQueryableHandler extends IHandler {
  IQuery batchStart();
  void batchExecute(List<SObject> scope);
  void batchFinish();
  Integer batchDefaultSize();
}
