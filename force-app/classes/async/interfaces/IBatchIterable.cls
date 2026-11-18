global interface IBatchIterable extends IBatch {
  Iterable<Object> start();
  void execute(Iterable<Object> scope);
}
