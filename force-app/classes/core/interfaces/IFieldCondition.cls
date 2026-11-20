/** A leaf of a condition tree: one field, one operator, one value. */
global interface IFieldCondition extends ICondition {
  /** True when the left side is an aggregate function (a HAVING condition). */
  Boolean isAggregateCondition();
  Enums.Comparator operator();
  IPath path();
  /** The condition with the given text, such as a bind variable, as its value. */
  String toSoql(String valueText);
  String toSoql();
  /**
   * The right-hand value. For a semi-join or anti-join it is the inner IQuery; for a date literal,
   * the IDateLiteral (or the List<IDateLiteral> that IN and NOT IN take). Whole numbers compared
   * with an integer field are given back as Integers, which is what a query binds.
   */
  Object value();
}
