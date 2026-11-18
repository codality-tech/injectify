/** A model, or a single-target lookup path, that further paths can start from. */
global interface IReference {
  List<SObjectField> fieldSequence();
  /** The related record this reference reaches from the given one. */
  SObject getRecordValue(SObject row);
  IReference getReference(Object via);
  IPath path(Object via);
  IPath path(Object via, Boolean strictType, Boolean strictNull);
  Integer size();
  IModel source();
  IModel target();
  IPath toPath();
  /** A field of the target, written as SOQL through this reference. */
  String toSoql(SObjectField field);
}
