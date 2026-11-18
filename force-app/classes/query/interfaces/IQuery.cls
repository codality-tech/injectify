/** A SOQL query under construction; see Query. */
global interface IQuery {
  // Running
  List<SObject> run();
  SObject fetch();
  List<SObject> fetch(Integer maxRows);
  Integer count();
  Database.QueryLocator toLocator();
  String toSoql(Boolean binding);
  String toSoql();

  // Clauses
  IModel source();
  IQueryFields fields();
  IQuery addAllFields();
  IQuery addImplicitFields();
  IQuery addSubquery(String relationshipName, IQuery child);
  IQuery addSubquery(SObjectField relationshipField, IQuery child);
  Map<String, IQuery> getSubqueryMap();
  IQuery addCondition(ICondition condition);
  ILogicalCondition filters();
  List<IOrdering> orderings();
  IQuery setOffset(Integer skipRows);
  IQuery setLimit(Integer maxRows);
  IQuery withSharing(Boolean enforce);
  IQuery withSecurity(Boolean enforce);
  IQuery forUpdate(Boolean lock);

  IQuery deepClone();
}
