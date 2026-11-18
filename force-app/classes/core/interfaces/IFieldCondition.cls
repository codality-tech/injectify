/** A leaf of a condition tree: one field, one operator, one value. */
global interface IFieldCondition extends ICondition {
  /** True when the left side is an aggregate function (a HAVING condition). */
  Boolean isAggregateCondition();
  Enums.Comparator operator();
  IPath path();
  /** The condition with the given text, such as a bind variable, as its value. */
  String toSoql(String valueText);
  String toSoql();
  Object value();
}
