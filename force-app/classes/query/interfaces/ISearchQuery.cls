global interface ISearchQuery {
  ISearchQuery deepClone();

  //* Search Scope
  Set<Enums.SearchScope> searchScope();

  //* Returning (multi-object targets)
  Map<SObjectType, IQuery> targetMap();

  //* WITH clause (e.g., 'DIVISION=Global', 'NETWORK=0DBxxx', 'SNIPPET')
  ISearchQuery setWith(String val);

  //* Overall Limit (across all objects)
  ISearchQuery setLimit(Integer limitCount);

  //* Output
  String toSosl(String searchTerm);
  List<List<SObject>> run(String searchTerm);
  Map<SObjectType, List<SObject>> runAsMap(String searchTerm);
}
