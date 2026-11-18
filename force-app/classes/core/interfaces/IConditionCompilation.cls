/** A condition tree compiled for one object: {n} markup plus the leaves that fill it. */
global interface IConditionCompilation {
  /** The leaves in placeholder order: leaf n fills {n}. */
  List<IFieldCondition> getFieldConditions();
  String getMarkup();
  /** Every field path the leaves compare. */
  Set<IPath> getPaths();
  IModel source();
  /** The markup with every leaf written inline. */
  String toSoql();
}
