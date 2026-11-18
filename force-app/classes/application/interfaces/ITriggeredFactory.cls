global interface ITriggeredFactory extends IBaseFactory {
  ITriggered make(SObjectType token);
  ITriggered make(String name);
  void execute();
  void disable(Map<SObjectType, Set<TriggerOperation>> bypasses);
  void enable(Map<SObjectType, Set<TriggerOperation>> bypasses);
  void disable();
  void enable();
  void disable(Iterable<SObjectType> tokens);
  void enable(Iterable<SObjectType> tokens);
  void disableWhen(ITriggeredBypass rule);
}
