global interface IBatchIterableHandler extends IHandler {
  Iterable<Object> batchStart();
  void batchExecute(Iterable<Object> scope);
  void batchFinish();
  Integer batchDefaultSize();
}
