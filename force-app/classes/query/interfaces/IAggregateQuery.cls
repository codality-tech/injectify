global interface IAggregateQuery {
  IAggregateQuery deepClone();

  //* From
  IModel source();

  //* Select (Aggregate Functions)
  Set<IAggregateFunction> aggregates();

  //* Group By
  List<IPath> groupBys();

  //* Group By Modifiers
  IAggregateQuery rollup();
  IAggregateQuery cube();

  //* Having (post-aggregation filter)
  ILogicalCondition havingFilters();

  //* Where (before aggregation)
  ILogicalCondition filters();

  //* Order By (on aggregate results or grouped fields)
  List<IOrdering> orderings();

  //* Limit
  IAggregateQuery setLimit(Integer limitCount);

  //* Offset
  IAggregateQuery setOffset(Integer offsetCount);

  //* Security
  IAggregateQuery withSecurity(Boolean enforceSecurity);

  //* Sharing
  IAggregateQuery withSharing(Boolean enforceSharing);

  //* Output
  String toSoql();
  String toSoql(Boolean binding);
  List<AggregateResult> run();
}
