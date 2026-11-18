global interface IFieldScope {
  Set<SObjectField> apply(IModel model);
  IFieldScope exclude(IFieldScope scope);
}
