global interface IOrdering {
  IModel source();
  IPath path();
  Boolean isAscending();
  Boolean nullsLast();
  String toSoql();
  void realize(SObjectType sobjectToken);
  void apply(List<SObject> records);
}
