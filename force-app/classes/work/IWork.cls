global interface IWork {
  //* DML registration methods
  IWork track(SObject record);
  IWork track(List<SObject> records);
  IWork track(SObject record, SObjectField relatedToField, SObject relatedTo);
  IWork track(
    SObject record,
    SObjectField relatedToField,
    SObjectField externalIdField,
    String externalId
  );
  IWork track(List<SObject> records, SObjectField externalIdField);

  IWork purge(SObject record);
  IWork purge(List<SObject> records);

  //* Non-DML work
  IWork track(Messaging.Email email);
  IWork track(List<Messaging.Email> emails);

  //* Configuration
  Database.DmlOptions options();
  IWork setOrder(List<SObjectType> purgeOrder);
  IWork withSharing(Boolean enforce);

  //* Execution
  void apply();

  //* State checking
  Boolean hasWork();

  //* Partial success: what apply() could not save when options().optAllOrNone is false
  /** One entry for each record that was not saved, in the order they were met. Empty when all were. */
  List<IWorkFailure> failures();
  /** The failure of this very record (the instance that was tracked or purged), or null when it was saved. */
  IWorkFailure failureOf(SObject record);
}
