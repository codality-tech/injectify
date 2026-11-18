/**
 * A rule that switches triggers off, for the running user or for whatever else it looks at.
 * Hand one to ITriggeredFactory.disableWhen. The rule is a class of the subscriber's own, so its
 * check runs in the subscriber's namespace: that is what lets it read a custom permission the
 * subscriber created, which code inside a namespaced package cannot.
 */
global interface ITriggeredBypass {
  // True to skip this object's trigger for this operation.
  Boolean bypasses(SObjectType token, TriggerOperation operation);
}
