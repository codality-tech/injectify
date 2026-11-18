global interface IDomainFactory extends IBaseFactory {
  IDomain make(SObjectType token);
  IDomain make(SObjectType token, List<SObject> records);
  IDomain make(String name);
  IDomain make(List<SObject> records);
}
