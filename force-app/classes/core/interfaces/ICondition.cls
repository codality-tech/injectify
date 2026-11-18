/** A node of a condition tree: a branch (ILogicalCondition) or a leaf (IFieldCondition). */
global interface ICondition {
  ICondition clone(Boolean deep);
  /** Adds the node to the compilation and returns its markup. */
  String compile(IConditionCompilation compilation);
  /** Tests a record in memory. */
  Boolean evaluate(SObject candidate);
  /** The same condition seen from the reference's source object. */
  ICondition prepend(IReference via);
  /** Binds the node to an object type. */
  void realize(SObjectType target);
  IModel source();
  String toSoql();
}
