global interface ITriggeredConfigured {
  //* Whether the trigger handler instance should be recycled between before/after operations
  Boolean shouldRecycleInstance();

  //* Whether CRUD security should be enforced for trigger operations
  Boolean shouldEnforceSecurity();
}
