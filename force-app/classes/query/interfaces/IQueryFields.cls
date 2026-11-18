global interface IQueryFields {
  // Set<SObjectField>
  IQueryFields add(Object route, Set<SObjectField> fields);
  IQueryFields add(Set<SObjectField> fields);
  // IQueryFields
  IQueryFields add(Object route, IQueryFields fields);
  IQueryFields add(IQueryFields fields);
  // fbr
  IQueryFields add(Object route, Map<IReference, Set<SObjectField>> fields);
  IQueryFields add(Map<IReference, Set<SObjectField>> fields);
  // Set<String>
  IQueryFields add(Object route, Set<String> fields);
  IQueryFields add(Set<String> fields);
  // Set<IPath>
  IQueryFields add(Set<IPath> paths);
  // IFieldScope
  IQueryFields add(Object route, IFieldScope scope);
  IQueryFields add(IFieldScope scope);
  // all
  IQueryFields addAll(Object route);
  IQueryFields addAll();
  // clear
  IQueryFields clearFields();
  // get
  IModel source();
  String toSoql();
  Set<IPath> getRoutes();
  Map<IReference, Set<SObjectField>> getFieldsByReference();
}
