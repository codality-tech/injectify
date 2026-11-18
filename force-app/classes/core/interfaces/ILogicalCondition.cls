/** A branch of a condition tree that joins its members with AND or OR. */
global interface ILogicalCondition extends ICondition {
  ILogicalCondition add(ICondition member);
  ILogicalCondition addAll(List<ICondition> members);
  ILogicalCondition clear();
  /** A copy of the member list. */
  List<ICondition> getAll();
}
