@isTest
private class SearchQueryTest {
  @isTest
  static void test_smoke_test() {
    // Simple smoke test to verify basic functionality
    ISearchQuery q = new SearchQuery(
      new Set<SObjectType>{ Account.SObjectType, Contact.SObjectType }
    );
    System.assertNotEquals(null, q, 'SearchQuery should not be null');

    String sosl = q.toSosl('Acme');
    System.assert(sosl.contains('FIND'), 'SOSL should contain FIND');
    System.assert(sosl.contains('Acme'), 'SOSL should contain search term');
  }

  @isTest
  static void test_basic_search() {
    // Test basic search with single object
    ISearchQuery q = new SearchQuery(
      new Set<SObjectType>{ Account.SObjectType }
    );
    q.searchScope().add(Enums.SearchScope.NAME);

    String sosl = q.toSosl('Test');
    System.assert(sosl.contains('FIND {Test}'), 'Should contain FIND');
    System.assert(
      sosl.contains('IN NAME FIELDS'),
      'Should contain search scope'
    );
  }

  @isTest
  static void test_multiple_objects() {
    // Test search across multiple objects
    ISearchQuery q = new SearchQuery(
      new Set<SObjectType>{ Account.SObjectType, Contact.SObjectType }
    );

    IQuery accountQuery = Application.s.qf().make(Account.SObjectType);
    accountQuery.fields()
      .add(new Set<SObjectField>{ Account.Name, Account.Industry });
    q.targetMap().put(Account.SObjectType, accountQuery);

    IQuery contactQuery = Application.s.qf().make(Contact.SObjectType);
    contactQuery.fields()
      .add(new Set<SObjectField>{ Contact.Name, Contact.Email });
    q.targetMap().put(Contact.SObjectType, contactQuery);

    String sosl = q.toSosl('Acme');
    System.assert(sosl.contains('Account'), 'Should contain Account');
    System.assert(sosl.contains('Contact'), 'Should contain Contact');
  }

  @isTest
  static void test_search_scopes() {
    // Test different search scopes
    ISearchQuery qName = new SearchQuery(
      new Set<SObjectType>{ Account.SObjectType }
    );
    qName.searchScope().add(Enums.SearchScope.NAME);
    System.assert(
      qName.toSosl('Test').contains('IN NAME FIELDS'),
      'Should contain NAME FIELDS'
    );

    ISearchQuery qEmail = new SearchQuery(
      new Set<SObjectType>{ Contact.SObjectType }
    );
    qEmail.searchScope().add(Enums.SearchScope.EMAIL);
    System.assert(
      qEmail.toSosl('test@example.com').contains('IN EMAIL FIELDS'),
      'Should contain EMAIL FIELDS'
    );

    ISearchQuery qPhone = new SearchQuery(
      new Set<SObjectType>{ Contact.SObjectType }
    );
    qPhone.searchScope().add(Enums.SearchScope.PHONE);
    System.assert(
      qPhone.toSosl('555-1234').contains('IN PHONE FIELDS'),
      'Should contain PHONE FIELDS'
    );

    ISearchQuery qAll = new SearchQuery(
      new Set<SObjectType>{ Account.SObjectType }
    );
    qAll.searchScope().add(Enums.SearchScope.ALL);
    System.assert(
      qAll.toSosl('Test').contains('IN ALL FIELDS'),
      'Should contain ALL FIELDS'
    );
  }

  @isTest
  static void test_returning_with_where() {
    // Test RETURNING with WHERE clause
    ISearchQuery q = new SearchQuery(
      new Set<SObjectType>{ Account.SObjectType }
    );

    IQuery accountQuery = Application.s.qf().make(Account.SObjectType);
    accountQuery.fields().add(new Set<SObjectField>{ Account.Name });
    accountQuery.filters().add(Application.s.eq(Account.Type, 'Customer'));
    q.targetMap().put(Account.SObjectType, accountQuery);

    String sosl = q.toSosl('Test');
    System.assert(sosl.contains('WHERE'), 'Should contain WHERE');
    System.assert(
      sosl.contains('Type = \'Customer\''),
      'Should contain condition'
    );
  }

  @isTest
  static void test_returning_with_order_by() {
    // Test RETURNING with ORDER BY
    ISearchQuery q = new SearchQuery(
      new Set<SObjectType>{ Account.SObjectType }
    );

    IQuery accountQuery = Application.s.qf().make(Account.SObjectType);
    accountQuery.fields().add(new Set<SObjectField>{ Account.Name });
    accountQuery.orderings()
      .add(Application.s.ordering(Account.Name, true, false));
    q.targetMap().put(Account.SObjectType, accountQuery);

    String sosl = q.toSosl('Test');
    System.assert(sosl.contains('ORDER BY'), 'Should contain ORDER BY');
  }

  @isTest
  static void test_returning_with_limit() {
    // Test RETURNING with LIMIT
    ISearchQuery q = new SearchQuery(
      new Set<SObjectType>{ Account.SObjectType }
    );

    IQuery accountQuery = Application.s.qf().make(Account.SObjectType);
    accountQuery.fields().add(new Set<SObjectField>{ Account.Name });
    accountQuery.setLimit(10);
    q.targetMap().put(Account.SObjectType, accountQuery);

    String sosl = q.toSosl('Test');
    System.assert(sosl.contains('LIMIT 10'), 'Should contain LIMIT');
  }

  @isTest
  static void test_overall_limit() {
    // Test overall LIMIT (not per-object)
    ISearchQuery q = new SearchQuery(
        new Set<SObjectType>{ Account.SObjectType, Contact.SObjectType }
      )
      .setLimit(100);

    String sosl = q.toSosl('Test');
    System.assert(sosl.contains('LIMIT 100'), 'Should contain overall LIMIT');
  }

  @isTest
  static void test_with_division() {
    // Test WITH clause - raw SOSL
    ISearchQuery q = new SearchQuery(
        new Set<SObjectType>{ Account.SObjectType }
      )
      .setWith('DIVISION=\'Americas\'');

    String sosl = q.toSosl('Test');
    System.assert(sosl.contains('WITH'), 'Should contain WITH');
    System.assert(
      sosl.contains('DIVISION=\'Americas\''),
      'Should contain DIVISION'
    );
  }

  @isTest
  static void test_with_network() {
    // Test WITH clause - raw SOSL
    ISearchQuery q = new SearchQuery(
        new Set<SObjectType>{ Account.SObjectType }
      )
      .setWith('NETWORK=\'0DB000000000001\'');

    String sosl = q.toSosl('Test');
    System.assert(
      sosl.contains('NETWORK=\'0DB000000000001\''),
      'Should contain NETWORK'
    );
  }

  @isTest
  static void test_with_snippet() {
    // Test WITH clause - raw SOSL
    ISearchQuery q = new SearchQuery(
        new Set<SObjectType>{ Account.SObjectType }
      )
      .setWith('SNIPPET(target_length=100)');

    String sosl = q.toSosl('Test');
    System.assert(
      sosl.contains('SNIPPET(target_length=100)'),
      'Should contain SNIPPET'
    );
  }

  @isTest
  static void test_with_spell_correction() {
    // Test WITH clause - raw SOSL
    ISearchQuery q = new SearchQuery(
        new Set<SObjectType>{ Account.SObjectType }
      )
      .setWith('SPELL_CORRECTION=true');

    String sosl = q.toSosl('Test');
    System.assert(
      sosl.contains('SPELL_CORRECTION=true'),
      'Should contain SPELL_CORRECTION'
    );
  }

  @isTest
  static void test_deep_clone() {
    // Test deep cloning
    ISearchQuery original = new SearchQuery(
        new Set<SObjectType>{ Account.SObjectType }
      )
      .setLimit(10);
    original.searchScope().add(Enums.SearchScope.NAME);

    IQuery accountQuery = Application.s.qf().make(Account.SObjectType);
    accountQuery.fields().add(new Set<SObjectField>{ Account.Name });
    original.targetMap().put(Account.SObjectType, accountQuery);

    ISearchQuery cloned = original.deepClone();
    System.assertNotEquals(
      original,
      cloned,
      'Clone should be different instance'
    );

    String originalSosl = original.toSosl('Test');
    String clonedSosl = cloned.toSosl('Test');
    System.assertEquals(
      originalSosl,
      clonedSosl,
      'Clone should generate identical SOSL'
    );
  }

  @isTest
  static void test_field_selection_methods() {
    // Test various field selection methods
    ISearchQuery q = new SearchQuery(
      new Set<SObjectType>{ Account.SObjectType }
    );

    IQuery accountQuery = Application.s.qf().make(Account.SObjectType);
    accountQuery.fields()
      .add(
        new Set<SObjectField>{ Account.Name, Account.Industry, Account.Phone }
      );
    q.targetMap().put(Account.SObjectType, accountQuery);

    String sosl = q.toSosl('Test');
    System.assert(sosl.contains('Name'), 'Should contain Name');
    System.assert(sosl.contains('Industry'), 'Should contain Industry');
    System.assert(sosl.contains('Phone'), 'Should contain Phone');
  }

  @isTest
  static void test_factory_integration() {
    // Test searchQuery on Core with List<IQuery>
    IQuery accountQuery = Application.s.qf().make(Account.SObjectType);
    IQuery contactQuery = Application.s.qf().make(Contact.SObjectType);
    ISearchQuery q = Application.s.searchQuery(
      new List<IQuery>{ accountQuery, contactQuery }
    );

    System.assertNotEquals(null, q, 'Query should not be null from Core');

    Map<SObjectType, IQuery> targets = q.targetMap();
    System.assertEquals(2, targets.size(), 'Should have 2 targets from init');
  }

  @isTest
  static void test_get_search_scope() {
    // Test search scope getter
    ISearchQuery q = new SearchQuery(
      new Set<SObjectType>{ Account.SObjectType }
    );
    q.searchScope().add(Enums.SearchScope.EMAIL);

    System.assert(
      q.searchScope().contains(Enums.SearchScope.EMAIL),
      'Should contain EMAIL scope'
    );
  }

  @isTest
  static void test_default_returning() {
    // Test default RETURNING when no explicit targets specified
    ISearchQuery q = new SearchQuery(
      new Set<SObjectType>{ Account.SObjectType, Contact.SObjectType }
    );

    String sosl = q.toSosl('Test');
    System.assert(
      sosl.contains('RETURNING Account, Contact'),
      'Should contain default RETURNING clause'
    );
  }

  @isTest
  static void test_error_null_search_term() {
    // Test error handling for null search term
    ISearchQuery q = new SearchQuery(
      new Set<SObjectType>{ Account.SObjectType }
    );

    try {
      q.toSosl(null);
      System.assert(false, 'Should throw exception for null search term');
    } catch (SearchQuery.SearchException e) {
      System.assert(
        e.getMessage().contains('blank'),
        'Exception should mention blank term'
      );
    }
  }

  @isTest
  static void test_error_empty_search_term() {
    // Test error handling for empty search term
    ISearchQuery q = new SearchQuery(
      new Set<SObjectType>{ Account.SObjectType }
    );

    try {
      q.toSosl('');
      System.assert(false, 'Should throw exception for empty search term');
    } catch (SearchQuery.SearchException e) {
      System.assert(
        e.getMessage().contains('blank'),
        'Exception should mention blank term'
      );
    }
  }

  @isTest
  static void test_error_null_sources() {
    // Test error handling for null sources
    try {
      new SearchQuery((Set<SObjectType>) null);
      System.assert(false, 'Should throw exception for null sources');
    } catch (SearchQuery.SearchException e) {
      System.assert(
        e.getMessage().contains('null'),
        'Exception should mention null'
      );
    }
  }

  @isTest
  static void test_error_empty_sources() {
    // Test error handling for empty sources
    try {
      new SearchQuery(new Set<SObjectType>());
      System.assert(false, 'Should throw exception for empty sources');
    } catch (SearchQuery.SearchException e) {
      System.assert(
        e.getMessage().contains('empty'),
        'Exception should mention empty'
      );
    }
  }

  @isTest
  static void test_with_data_category() {
    // Test WITH clause - raw SOSL
    ISearchQuery q = new SearchQuery(
        new Set<SObjectType>{ Account.SObjectType }
      )
      .setWith('DATA CATEGORY Geography AT USA');

    String sosl = q.toSosl('Test');
    System.assert(sosl.contains('WITH'), 'Should contain WITH');
    System.assert(
      sosl.contains('DATA CATEGORY Geography AT USA'),
      'Should contain DATA CATEGORY'
    );
  }

  @isTest
  static void test_multiple_with_clauses() {
    // Test WITH clause - raw SOSL with multiple conditions
    ISearchQuery q = new SearchQuery(
        new Set<SObjectType>{ Account.SObjectType }
      )
      .setWith(
        'DIVISION=\'Americas\' NETWORK=\'0DB000000000001\' SNIPPET(target_length=50) SPELL_CORRECTION=false'
      );

    String sosl = q.toSosl('Test');
    System.assert(
      sosl.contains('DIVISION=\'Americas\''),
      'Should contain DIVISION'
    );
    System.assert(
      sosl.contains('NETWORK=\'0DB000000000001\''),
      'Should contain NETWORK'
    );
    System.assert(
      sosl.contains('SNIPPET(target_length=50)'),
      'Should contain SNIPPET'
    );
    System.assert(
      sosl.contains('SPELL_CORRECTION=false'),
      'Should contain SPELL_CORRECTION'
    );
  }

  @isTest
  static void test_returning_with_offset() {
    // Test RETURNING with OFFSET
    ISearchQuery q = new SearchQuery(
      new Set<SObjectType>{ Account.SObjectType }
    );

    IQuery accountQuery = Application.s.qf().make(Account.SObjectType);
    accountQuery.fields().add(new Set<SObjectField>{ Account.Name });
    accountQuery.setLimit(10);
    accountQuery.setOffset(5);
    q.targetMap().put(Account.SObjectType, accountQuery);

    String sosl = q.toSosl('Test');
    System.assert(sosl.contains('LIMIT 10'), 'Should contain LIMIT');
    System.assert(sosl.contains('OFFSET 5'), 'Should contain OFFSET');
  }

  @isTest
  static void test_list_constructor() {
    // Test constructor with List<IQuery>
    IQuery accountQuery = Application.s.qf().make(Account.SObjectType);
    IQuery contactQuery = Application.s.qf().make(Contact.SObjectType);

    ISearchQuery q = new SearchQuery(
      new List<IQuery>{ accountQuery, contactQuery }
    );

    System.assertNotEquals(null, q, 'Should create query');
    System.assertEquals(2, q.targetMap().size(), 'Should have 2 targets');
    System.assert(
      q.targetMap().containsKey(Account.SObjectType),
      'Should contain Account'
    );
    System.assert(
      q.targetMap().containsKey(Contact.SObjectType),
      'Should contain Contact'
    );
  }

  @isTest
  static void test_error_null_query_list() {
    // Test error handling for null query list
    try {
      new SearchQuery((List<IQuery>) null);
      System.assert(false, 'Should throw exception for null query list');
    } catch (SearchQuery.SearchException e) {
      System.assert(
        e.getMessage().contains('null'),
        'Exception should mention null'
      );
    }
  }

  @isTest
  static void test_error_empty_query_list() {
    // Test error handling for empty query list
    try {
      new SearchQuery(new List<IQuery>());
      System.assert(false, 'Should throw exception for empty query list');
    } catch (SearchQuery.SearchException e) {
      System.assert(
        e.getMessage().contains('empty'),
        'Exception should mention empty'
      );
    }
  }

  // --- Escaping and running ------------------------------------------------------------------------

  @IsTest
  static void theSearchTermCannotCloseTheFindBraces() {
    SearchQuery q = new SearchQuery(new Set<SObjectType>{ Account.SObjectType });

    String sosl = q.toSosl('x} RETURNING User(Name');
    String quoted = q.toSosl('it\'s \\ fine');

    Assert.isTrue(sosl.startsWith('FIND {x\\} RETURNING User(Name}'), sosl);
    Assert.isTrue(sosl.endsWith('RETURNING Account'), 'only the intended object is returned: ' + sosl);
    Assert.isTrue(quoted.startsWith('FIND {it\\\'s \\\\ fine}'), quoted);
    Assert.isTrue(q.toSosl('acme* AND "big co"').startsWith('FIND {acme* AND "big co"}'), 'wildcards and phrases still work');
  }

  @IsTest
  static void filterValuesAreEscapedInsideReturning() {
    IQuery accounts = Application.s.qf().make(Account.SObjectType);
    accounts.filters().add(Application.s.eq(Account.Name, 'O\'Brien'));
    SearchQuery q = new SearchQuery(new List<IQuery>{ accounts });

    String sosl = q.toSosl('Brien');

    Assert.isTrue(sosl.contains('WHERE (Name = \'O\\\'Brien\')'), sosl);
    Assert.isTrue(q.run('Brien')[0].isEmpty(), 'valid SOSL; no fixed results were set');
  }

  @IsTest
  static void runReturnsWhatTheSearchFinds() {
    Account acme = new Account(Name = 'Acme Search');
    insert acme;
    Test.setFixedSearchResults(new List<Id>{ acme.Id });
    SearchQuery q = new SearchQuery(new Set<SObjectType>{ Account.SObjectType, Contact.SObjectType });

    List<List<SObject>> found = q.run('Acme');
    Map<SObjectType, List<SObject>> byType = q.runAsMap('Acme');

    Assert.areEqual(acme.Id, found[0][0].Id);
    Assert.isTrue(found[1].isEmpty(), 'no contacts');
    Assert.areEqual(new Set<SObjectType>{ Account.SObjectType }, byType.keySet(), 'types without hits are left out');
  }

  // Notes what it is asked to search, then lets the platform run it.
  private class WatchingScheme implements IScheme, ISearchScheme {
    private IScheme real = new SchemeDefault();
    private List<String> searched = new List<String>();
    private List<System.AccessLevel> modes = new List<System.AccessLevel>();

    public List<List<SObject>> search(String sosl, System.AccessLevel mode) {
      searched.add(sosl);
      modes.add(mode);
      return Search.query(sosl, mode);
    }
    public SObjectType getSObjectType(String sobjectName) {
      return real.getSObjectType(sobjectName);
    }
    public DescribeSObjectResult getDescribe(SObjectType token) {
      return real.getDescribe(token);
    }
    public Map<String, SObjectField> getFieldMap(SObjectType token) {
      return real.getFieldMap(token);
    }
    public Map<String, Schema.FieldSet> getFieldsetMap(SObjectType token) {
      return real.getFieldsetMap(token);
    }
    public DescribeFieldResult getFieldDescribe(SObjectField field) {
      return real.getFieldDescribe(field);
    }
    public List<SObject> queryWithBinds(String soql, Map<String, Object> binds, System.AccessLevel mode) {
      return real.queryWithBinds(soql, binds, mode);
    }
    public Database.QueryLocator getQueryLocatorWithBinds(String soql, Map<String, Object> binds, System.AccessLevel mode) {
      return real.getQueryLocatorWithBinds(soql, binds, mode);
    }
    public Integer countQueryWithBinds(String soql, Map<String, Object> binds, System.AccessLevel mode) {
      return real.countQueryWithBinds(soql, binds, mode);
    }
    public Type getTypeForName(String className) {
      return real.getTypeForName(className);
    }
  }

  // A scheme written before schemes could search: the eight original methods and nothing else.
  private class OlderScheme implements IScheme {
    private IScheme real = new SchemeDefault();

    public SObjectType getSObjectType(String sobjectName) {
      return real.getSObjectType(sobjectName);
    }
    public DescribeSObjectResult getDescribe(SObjectType token) {
      return real.getDescribe(token);
    }
    public Map<String, SObjectField> getFieldMap(SObjectType token) {
      return real.getFieldMap(token);
    }
    public Map<String, Schema.FieldSet> getFieldsetMap(SObjectType token) {
      return real.getFieldsetMap(token);
    }
    public DescribeFieldResult getFieldDescribe(SObjectField field) {
      return real.getFieldDescribe(field);
    }
    public List<SObject> queryWithBinds(String soql, Map<String, Object> binds, System.AccessLevel mode) {
      return real.queryWithBinds(soql, binds, mode);
    }
    public Database.QueryLocator getQueryLocatorWithBinds(String soql, Map<String, Object> binds, System.AccessLevel mode) {
      return real.getQueryLocatorWithBinds(soql, binds, mode);
    }
    public Integer countQueryWithBinds(String soql, Map<String, Object> binds, System.AccessLevel mode) {
      return real.countQueryWithBinds(soql, binds, mode);
    }
    public Type getTypeForName(String className) {
      return real.getTypeForName(className);
    }
  }

  @isTest
  static void aSearchRunsThroughTheSchemeOfItsQueries() {
    Account acme = new Account(Name = 'Acme');
    insert acme;
    Test.setFixedSearchResults(new List<Id>{ acme.Id });
    WatchingScheme scheme = new WatchingScheme();
    Core watched = new Core(scheme);
    IQuery accounts = watched.model(Account.SObjectType).query();
    accounts.fields().add(new Set<SObjectField>{ Account.Name });
    ISearchQuery search = watched.searchQuery(new List<IQuery>{ accounts });

    List<List<SObject>> found = search.run('Acme');
    search.deepClone().run('Acme');

    Assert.areEqual(acme.Id, found[0][0].Id);
    Assert.areEqual(new List<String>{ search.toSosl('Acme'), search.toSosl('Acme') }, scheme.searched, 'a copy keeps the scheme');
    Assert.areEqual(System.AccessLevel.SYSTEM_MODE, scheme.modes[0], 'system mode unless a query asks otherwise');
  }

  @isTest
  static void aSearchRunsInUserModeWhenOneOfItsQueriesDoes() {
    WatchingScheme scheme = new WatchingScheme();
    Core watched = new Core(scheme);
    IQuery accounts = watched.model(Account.SObjectType).query();
    IQuery contacts = watched.model(Contact.SObjectType).query().withSharing(true);

    watched.searchQuery(new List<IQuery>{ accounts, contacts }).run('Acme');

    Assert.areEqual(System.AccessLevel.USER_MODE, scheme.modes[0]);
  }

  @isTest
  static void aSchemeThatCannotSearchLeavesItToThePlatform() {
    Account acme = new Account(Name = 'Acme');
    insert acme;
    Test.setFixedSearchResults(new List<Id>{ acme.Id });
    Core older = new Core(new OlderScheme());
    IQuery accounts = older.model(Account.SObjectType).query();

    List<List<SObject>> found = older.searchQuery(new List<IQuery>{ accounts }).run('Acme');

    Assert.areEqual(acme.Id, found[0][0].Id);
  }
}
