global interface IBatchQueryable extends IBatch {
  IQuery start();
  void execute(List<SObject> scope);
}
