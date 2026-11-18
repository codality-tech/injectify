global interface ITriggered {
  //* Single method to handle all trigger operations (explicit, testable)
  void handleTrigger(
    TriggerOperation op,
    List<SObject> triggerNew,
    List<SObject> triggerOld,
    Map<Id, SObject> triggerOldMap,
    IModel model
  );
}
