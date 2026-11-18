/**
 * A SOSL search over one or more objects. Each object's fields, conditions, ordering and limit
 * come from an IQuery. The search runs through the scheme of its first query when that scheme
 * implements ISearchScheme (the default scheme and MockScheme do), and in user mode when any of
 * its queries was set to withSharing(true).
 */
public virtual inherited sharing class SearchQuery implements ISearchQuery {
  //* Exceptions
  public virtual class SearchException extends Exception {
  }

  //* Constructor
  public SearchQuery() {
  }

  public SearchQuery(Set<SObjectType> sources) {
    init(sources);
  }

  public SearchQuery(List<IQuery> queries) {
    init(queries);
  }

  public SearchQuery(SearchQuery other) {
    init(other);
  }

  //* Initialization
  public virtual void init(Set<SObjectType> sources) {
    if (this.sources != null && !this.sources.isEmpty()) {
      throw new SearchException('SearchQuery has already been initialized');
    }
    if (sources == null || sources.isEmpty()) {
      throw new SearchException(
        'Source SObjectTypes must not be null or empty'
      );
    }
    this.sources = sources.clone();
  }

  public virtual void init(List<IQuery> queries) {
    if (this.sources != null && !this.sources.isEmpty()) {
      throw new SearchException('SearchQuery has already been initialized');
    }
    if (queries == null || queries.isEmpty()) {
      throw new SearchException('Query list must not be null or empty');
    }

    // Extract sources from queries and populate targetMap
    Set<SObjectType> sourceSet = new Set<SObjectType>();
    for (IQuery query : queries) {
      SObjectType token = query.source().token();
      sourceSet.add(token);
      this.targets.put(token, query.deepClone());
      if (scheme == null) {
        scheme = query.source().scheme();
      }
    }
    this.sources = sourceSet;
  }

  public virtual void init(SearchQuery other) {
    init(other.sources);
    this.scheme = other.scheme;
    this.searchScopeSet = other.searchScope()?.clone();
    this.limitCount = other.limitCount;
    this.withClause = other.withClause;

    // Clone targets
    for (SObjectType objType : other.targets.keySet()) {
      IQuery target = other.targets.get(objType);
      this.targets.put(objType, target.deepClone());
    }
  }

  public virtual ISearchQuery deepClone() {
    return new SearchQuery(this);
  }

  //* State
  private Set<SObjectType> sources;
  private IScheme scheme;
  private Set<Enums.SearchScope> searchScopeSet {
    get {
      if (searchScopeSet == null) {
        searchScopeSet = new Set<Enums.SearchScope>();
      }
      return searchScopeSet;
    }
    private set;
  }
  private Map<SObjectType, IQuery> targets {
    get {
      if (targets == null) {
        targets = new Map<SObjectType, IQuery>();
      }
      return targets;
    }
    private set;
  }
  private Integer limitCount;
  private String withClause;

  //* Search Scope
  public Set<Enums.SearchScope> searchScope() {
    return this.searchScopeSet;
  }

  private String getSearchScope() {
    if (searchScopeSet.isEmpty()) {
      return null;
    }
    // Convert enum set to SOSL clause
    if (searchScopeSet.contains(Enums.SearchScope.NAME)) {
      return 'NAME FIELDS';
    } else if (searchScopeSet.contains(Enums.SearchScope.EMAIL)) {
      return 'EMAIL FIELDS';
    } else if (searchScopeSet.contains(Enums.SearchScope.PHONE)) {
      return 'PHONE FIELDS';
    } else if (searchScopeSet.contains(Enums.SearchScope.ALL)) {
      return 'ALL FIELDS';
    }
    return null;
  }

  //* Returning (multi-object targets)
  public Map<SObjectType, IQuery> targetMap() {
    return targets;
  }

  //* WITH clause
  public ISearchQuery setWith(String val) {
    this.withClause = val;
    return this;
  }

  //* Overall Limit
  public ISearchQuery setLimit(Integer limitCount) {
    this.limitCount = limitCount;
    return this;
  }

  // User mode as soon as one of the queries asks for it: the stricter reading of a mixed search.
  private System.AccessLevel accessLevel() {
    for (IQuery target : targets.values()) {
      if (target instanceof Query && ((Query) target).isUserMode()) {
        return System.AccessLevel.USER_MODE;
      }
    }
    return System.AccessLevel.SYSTEM_MODE;
  }

  //* Output
  private SearchCompiler getCompiler() {
    return new SearchCompiler(this);
  }

  public virtual String toSosl(String searchTerm) {
    return getCompiler().toSosl(searchTerm);
  }

  public virtual List<List<SObject>> run(String searchTerm) {
    return getCompiler().run(searchTerm);
  }

  public virtual Map<SObjectType, List<SObject>> runAsMap(String searchTerm) {
    return getCompiler().runAsMap(searchTerm);
  }

  //* Compiler
  private class SearchCompiler {
    SearchQuery query;

    SearchCompiler(SearchQuery query) {
      this.query = query;
    }

    public String toSosl(String searchTerm) {
      List<String> parts = new List<String>();

      // FIND
      if (String.isBlank(searchTerm)) {
        throw new SearchException('Search term must not be blank');
      }
      parts.add('FIND {' + findTerm(searchTerm) + '}');

      // IN SCOPE
      String scopeClause = query.getSearchScope();
      if (String.isNotBlank(scopeClause)) {
        parts.add('IN ' + scopeClause);
      }

      // RETURNING
      if (!query.targets.isEmpty()) {
        List<String> returningClauses = new List<String>();
        for (SObjectType objType : query.targets.keySet()) {
          IQuery target = query.targets.get(objType);
          returningClauses.add(queryToSosl(target));
        }
        parts.add('RETURNING ' + String.join(returningClauses, ', '));
      } else if (query.sources != null && !query.sources.isEmpty()) {
        // Default: return all specified sources with no field selection
        List<String> returningClauses = new List<String>();
        for (SObjectType objType : query.sources) {
          returningClauses.add(objType.getDescribe().getName());
        }
        parts.add('RETURNING ' + String.join(returningClauses, ', '));
      }

      // WITH clause
      if (String.isNotBlank(query.withClause)) {
        parts.add('WITH ' + query.withClause);
      }

      // LIMIT
      if (query.limitCount != null) {
        parts.add('LIMIT ' + query.limitCount);
      }

      return String.join(parts, ' ');
    }

    // Backslashes, braces and quotes are escaped, so the term cannot close FIND's braces early and
    // run as SOSL. SOSL's own wildcards and operators (* ? & | ! and so on) keep working.
    private String findTerm(String searchTerm) {
      return searchTerm.replace('\\', '\\\\').replace('{', '\\{').replace('}', '\\}').replace('\'', '\\\'');
    }

    private String queryToSosl(IQuery q) {
      // Validate unsupported features
      if (!q.getSubqueryMap().isEmpty()) {
        throw new SearchException('SOSL does not support subqueries');
      }

      List<String> parts = new List<String>();

      // Object name
      parts.add(q.source().token().getDescribe().getName());

      // Build inner clauses
      List<String> clauses = new List<String>();

      // Fields: in a user-mode search the defaults the user cannot read are left out, as in SOQL
      Boolean asUser = query.accessLevel() == System.AccessLevel.USER_MODE;
      String fieldsClause = q instanceof Query ? ((Query) q).selectedFields(asUser) : q.fields().toSoql();
      if (String.isNotBlank(fieldsClause)) {
        clauses.add(fieldsClause);
      }

      // WHERE
      if (!q.filters().getAll().isEmpty()) {
        q.filters().realize(q.source().token());
        clauses.add('WHERE ' + q.filters().toSoql());
      }

      // ORDER BY
      if (!q.orderings().isEmpty()) {
        List<String> orderItems = new List<String>();
        for (IOrdering ord : q.orderings()) {
          ord.realize(q.source().token());
          orderItems.add(ord.toSoql());
        }
        clauses.add('ORDER BY ' + String.join(orderItems, ', '));
      }

      // LIMIT (per-object limit from query)
      String soql = q.toSoql();
      if (soql.contains(' LIMIT ')) {
        // Extract limit from SOQL
        Pattern limitPattern = Pattern.compile('LIMIT\\s+(\\d+)');
        Matcher limitMatcher = limitPattern.matcher(soql);
        if (limitMatcher.find()) {
          clauses.add('LIMIT ' + limitMatcher.group(1));
        }
      }

      // OFFSET
      if (soql.contains(' OFFSET ')) {
        // Extract offset from SOQL
        Pattern offsetPattern = Pattern.compile('OFFSET\\s+(\\d+)');
        Matcher offsetMatcher = offsetPattern.matcher(soql);
        if (offsetMatcher.find()) {
          clauses.add('OFFSET ' + offsetMatcher.group(1));
        }
      }

      // Combine
      if (!clauses.isEmpty()) {
        parts.add('(' + String.join(clauses, ' ') + ')');
      }

      return String.join(parts, '');
    }

    // Through the scheme when it can search; a scheme that cannot leaves it to the platform.
    public List<List<SObject>> run(String searchTerm) {
      String searchString = toSosl(searchTerm);
      IScheme through = query.scheme ?? new SchemeDefault();
      if (through instanceof ISearchScheme) {
        return ((ISearchScheme) through).search(searchString, query.accessLevel());
      }
      return Search.query(searchString, query.accessLevel());
    }

    public Map<SObjectType, List<SObject>> runAsMap(String searchTerm) {
      List<List<SObject>> results = run(searchTerm);
      Map<SObjectType, List<SObject>> resultMap = new Map<SObjectType, List<SObject>>();

      for (List<SObject> resultList : results) {
        if (!resultList.isEmpty()) {
          SObjectType objType = resultList[0].getSObjectType();
          resultMap.put(objType, resultList);
        }
      }

      return resultMap;
    }
  }
}
