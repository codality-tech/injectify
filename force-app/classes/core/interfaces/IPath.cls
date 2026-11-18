/** One field reached from a model, directly or across lookups. */
global interface IPath {
  DescribeFieldResult describe();
  /** The fields walked, ending with the terminus. */
  List<SObjectField> fieldSequence();
  /** Follows the path through a record and its loaded parents. */
  Object getFieldValue(SObject row);
  Integer size();
  String label();
  /** The SOQL form, e.g. Account.Owner.Name. */
  String name();
  /** Where the path starts its last step from. */
  IReference reference();
  IModel source();
  SObjectField terminus();
  /** The path as a reference, when it ends in a single-target lookup. */
  IReference toReference();
}
