global interface IQueryFactory extends IBaseFactory {
  IQuery make(SObjectType token);
  IQuery make(String name);
  IQuery make(String name, List<Object> additiveArgs);
  IQuery make(SObjectType token, List<Object> additiveArgs);
  IQueryFactory defaultFieldScope(IFieldScope scope);
}
