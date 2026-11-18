/** A path that ends in a lookup field. */
global interface ILookupPath extends IPath {
  SObject getRecordValue(SObject row);
  /** Every object the lookup can point at. */
  IModel[] targets();
  /** Dotted from the source, e.g. Account.Owner. */
  String relationshipName();
}
