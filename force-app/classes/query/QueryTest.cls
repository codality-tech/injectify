@isTest
private class QueryTest {
  @isTest
  static void test_smoke_test() {
    // Simple smoke test to verify basic functionality
    IQuery q = new Query(Application.s.model(Account.SObjectType));
    System.assertNotEquals(null, q, 'Query should not be null');
    System.assertEquals(
      'Account',
      q.source().name(),
      'Source should be Account'
    );

    String soql = q.toSoql();
    System.assert(soql.contains('SELECT'), 'SOQL should contain SELECT');
    System.assert(
      soql.contains('FROM Account'),
      'SOQL should contain FROM Account'
    );
  }

  @isTest
  static void test_make_basic() {
    // Test basic make method with IModel
    IQuery query = new Query(Application.s.model(Account.SObjectType));
    System.assertNotEquals(null, query, 'Query should not be null');
    System.assertEquals(
      Application.s.model(Account.SObjectType),
      query.source(),
      'Source should match'
    );
  }

  @isTest
  static void test_deepClone() {
    // Test deep cloning
    IQuery original = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'))
      .setLimit(10)
      .setOffset(5);

    IQuery cloned = original.deepClone();
    System.assertNotEquals(
      original,
      cloned,
      'Clone should be different instance'
    );

    String originalSoql = original.toSoql();
    String clonedSoql = cloned.toSoql();
    System.assertEquals(
      originalSoql,
      clonedSoql,
      'Clone should generate identical SOQL'
    );
  }

  @isTest
  static void test_addCondition() {
    IQuery q = new Query(Application.s.model(Account.SObjectType));

    // Test adding single condition
    IQuery result = q.addCondition(Application.s.eq(Account.Type, 'Customer'));
    System.assertEquals(q, result, 'Should return self for chaining');

    String soql = q.toSoql();
    System.assert(
      soql.contains('Type = \'Customer\''),
      'SOQL should contain condition'
    );
  }

  @isTest
  static void test_filters() {
    IQuery q = new Query(Application.s.model(Account.SObjectType));

    // Test filters access
    ILogicalCondition filters = q.filters();
    System.assertNotEquals(null, filters, 'Filters should not be null');

    // Test adding condition through filters
    filters.add(Application.s.eq(Account.Type, 'Customer'));

    String soql = q.toSoql();
    System.assert(
      soql.contains('Type = \'Customer\''),
      'SOQL should contain condition from filters'
    );
  }

  @isTest
  static void test_orderings() {
    IQuery q = new Query(Application.s.model(Account.SObjectType));

    // Test orderings access
    List<IOrdering> orderings = q.orderings();
    System.assertNotEquals(null, orderings, 'Orderings should not be null');

    // Test adding ordering
    orderings.add(Application.s.ordering(Account.Name, true, false));
  }

  @isTest
  static void test_setLimit() {
    IQuery q = new Query(Application.s.model(Account.SObjectType));

    // Test setting limit
    IQuery result = q.setLimit(100);
    System.assertEquals(q, result, 'Should return self for chaining');

    String soql = q.toSoql();
    System.assert(
      soql.contains('LIMIT 100'),
      'SOQL should contain LIMIT clause'
    );
  }

  @isTest
  static void test_setOffset() {
    IQuery q = new Query(Application.s.model(Account.SObjectType));

    // Test setting offset
    IQuery result = q.setOffset(50);
    System.assertEquals(q, result, 'Should return self for chaining');

    String soql = q.toSoql();
    System.assert(
      soql.contains('OFFSET 50'),
      'SOQL should contain OFFSET clause'
    );
  }

  @isTest
  static void test_withSecurity_basic() {
    // Test basic security enforcement
    IQuery q = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'))
      .withSecurity(true);
    String soql = q.toSoql();
    System.assert(
      soql.contains('WITH SECURITY_ENFORCED'),
      'SOQL should contain WITH SECURITY_ENFORCED clause'
    );
    System.assert(
      soql.contains('Type') && soql.contains('Customer'),
      'SOQL should contain the condition'
    );
  }

  @isTest
  static void test_withSecurity_default() {
    // Test default behavior (no security enforcement)
    IQuery q = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'));

    String soql = q.toSoql();
    System.assert(
      !soql.contains('WITH SECURITY_ENFORCED'),
      'SOQL should not contain WITH SECURITY_ENFORCED clause by default'
    );
  }

  @isTest
  static void test_withSecurity_fluent() {
    // Test fluent API chaining
    IQuery q = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'))
      .withSecurity(true)
      .setLimit(10)
      .setOffset(5);

    String soql = q.toSoql();
    System.assert(
      soql.contains('WITH SECURITY_ENFORCED'),
      'SOQL should contain WITH SECURITY_ENFORCED clause'
    );
    System.assert(
      soql.contains('LIMIT 10'),
      'SOQL should contain LIMIT clause'
    );
    System.assert(
      soql.contains('OFFSET 5'),
      'SOQL should contain OFFSET clause'
    );
  }

  @isTest
  static void test_withSecurity_clone() {
    // Test that security setting is preserved in deep clone
    IQuery original = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'))
      .withSecurity(true);

    IQuery cloned = original.deepClone();
    String originalSoql = original.toSoql();
    String clonedSoql = cloned.toSoql();

    System.assertEquals(
      originalSoql,
      clonedSoql,
      'Cloned q should generate identical SOQL'
    );
    System.assert(
      clonedSoql.contains('WITH SECURITY_ENFORCED'),
      'Cloned SOQL should contain WITH SECURITY_ENFORCED clause'
    );
  }

  @isTest
  static void test_withSecurity_toggle() {
    // Test toggling security on and off
    IQuery q = new Query(Application.s.model(Account.SObjectType));

    // Initially no security
    String soql1 = q.toSoql();
    System.assert(
      !soql1.contains('WITH SECURITY_ENFORCED'),
      'Initial SOQL should not contain WITH SECURITY_ENFORCED'
    );

    // Enable security
    q.withSecurity(true);
    String soql2 = q.toSoql();
    System.assert(
      soql2.contains('WITH SECURITY_ENFORCED'),
      'SOQL should contain WITH SECURITY_ENFORCED after enabling'
    );

    // Disable security
    q.withSecurity(false);
    String soql3 = q.toSoql();
    System.assert(
      !soql3.contains('WITH SECURITY_ENFORCED'),
      'SOQL should not contain WITH SECURITY_ENFORCED after disabling'
    );
  }

  @isTest
  static void test_withSharing_toggle() {
    // Test toggling sharing on and off
    IQuery q = new Query(Application.s.model(Account.SObjectType));

    // Initially no sharing (system mode)
    String soql1 = q.toSoql();
    System.assert(
      !soql1.contains('WITH SECURITY_ENFORCED'),
      'Initial SOQL should not contain WITH SECURITY_ENFORCED'
    );

    // Enable sharing (user mode)
    q.withSharing(true);
    String soql2 = q.toSoql();
    System.assert(
      !soql2.contains('WITH SECURITY_ENFORCED'),
      'SOQL should not contain WITH SECURITY_ENFORCED when only sharing is enabled'
    );

    // Disable sharing (back to system mode)
    q.withSharing(false);
    String soql3 = q.toSoql();
    System.assert(
      !soql3.contains('WITH SECURITY_ENFORCED'),
      'SOQL should not contain WITH SECURITY_ENFORCED after disabling sharing'
    );
  }

  @isTest
  static void test_withSharing_and_security_combined() {
    // Test combining sharing and security
    IQuery q = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'))
      .withSharing(true)
      .withSecurity(true);
    String soql = q.toSoql();
    System.assert(
      soql.contains('WITH SECURITY_ENFORCED'),
      'SOQL should contain WITH SECURITY_ENFORCED when both sharing and security are enabled'
    );
    System.assert(
      soql.contains('Type') && soql.contains('Customer'),
      'SOQL should contain the condition'
    );
  }

  @isTest
  static void test_withSharing_clone() {
    // Test that sharing setting is preserved in deep clone
    IQuery original = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'))
      .withSharing(true);

    IQuery cloned = original.deepClone();
    String originalSoql = original.toSoql();
    String clonedSoql = cloned.toSoql();

    System.assertEquals(
      originalSoql,
      clonedSoql,
      'Cloned q should generate identical SOQL'
    );
  }

  @isTest
  static void test_withSharing_fluent() {
    // Test fluent API chaining with sharing
    IQuery q = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'))
      .withSharing(true)
      .setLimit(10)
      .setOffset(5);

    String soql = q.toSoql();
    System.assert(
      soql.contains('LIMIT 10'),
      'SOQL should contain LIMIT clause'
    );
    System.assert(
      soql.contains('OFFSET 5'),
      'SOQL should contain OFFSET clause'
    );
  }

  @isTest
  static void test_addAll() {
    IQuery q = new Query(Application.s.model(Account.SObjectType));
    // Add all fields using the correct API
    q.fields().addAll();
    String soql = q.toSoql();
    // Instead of expecting '*', check for multiple known Account fields
    System.assert(soql.contains('Name'), 'SOQL should contain Name field');
    System.assert(soql.contains('Id'), 'SOQL should contain Id field');
    System.assert(soql.contains('Type'), 'SOQL should contain Type field');
  }

  @isTest
  static void test_addAll_with_route() {
    Query q = (Query) new Query(Application.s.model(Account.SObjectType));

    // Test adding all fields with route
    q.fields().add(Account.OwnerId, new Set<SObjectField>{ User.Name });

    String soql = q.toSoql();
    System.assert(soql.contains('Owner.'), 'SOQL should contain Owner fields');
  }

  @isTest
  static void test_addImplicitFields() {
    IQuery q = new Query(Application.s.model(Account.SObjectType));
    Boolean threw = false;
    try {
      // This may throw if implicit fields are not set up correctly
      q.addImplicitFields();
    } catch (Exception e) {
      threw = true;
    }
    System.assert(!threw, 'Should not throw when adding implicit fields');
  }

  @isTest
  static void test_addSubquery() {
    IQuery accountQuery = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'));

    IQuery contactQuery = new Query(Application.s.model(Contact.SObjectType))
      .addCondition(Application.s.eq(Contact.Email, 'test@example.com'));

    // Test adding subquery with string
    IQuery result1 = accountQuery.addSubquery('Contacts', contactQuery);
    System.assertEquals(
      accountQuery,
      result1,
      'Should return self for chaining'
    );

    // Test adding subquery with string (alternative)
    IQuery result2 = accountQuery.addSubquery('Contacts', contactQuery);
    System.assertEquals(
      accountQuery,
      result2,
      'Should return self for chaining'
    );

    Map<String, IQuery> subqueryMap = accountQuery.getSubqueryMap();
    System.assert(
      subqueryMap.containsKey('Contacts'),
      'Should contain Contacts subquery'
    );
  }

  @isTest
  static void test_addSubquery_null_parameters() {
    IQuery q = new Query(Application.s.model(Account.SObjectType));
    IQuery subquery = new Query(Application.s.model(Contact.SObjectType));

    // Test with null parameters (should throw exception)
    Boolean threw1 = false;
    try {
      q.addSubquery((String) null, subquery);
    } catch (Exception e) {
      threw1 = true;
    }
    System.assert(threw1, 'Should throw exception for null field name');

    Boolean threw2 = false;
    try {
      q.addSubquery('Contacts', (IQuery) null);
    } catch (Exception e) {
      threw2 = true;
    }
    System.assert(threw2, 'Should throw exception for null subquery');
  }

  @isTest
  static void test_toSoql() {
    IQuery q = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'))
      .setLimit(10);

    // Test SOQL generation
    String soql = q.toSoql();
    System.assert(soql.contains('SELECT'), 'SOQL should contain SELECT');
    System.assert(
      soql.contains('FROM Account'),
      'SOQL should contain FROM Account'
    );
    System.assert(soql.contains('WHERE'), 'SOQL should contain WHERE');
    System.assert(soql.contains('LIMIT 10'), 'SOQL should contain LIMIT');
  }

  @isTest
  static void test_toSoql_with_binding() {
    IQuery q = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'));

    // Test SOQL generation with binding
    String soql = q.toSoql(true);
    System.assert(soql.contains('SELECT'), 'SOQL should contain SELECT');
    System.assert(
      soql.contains('FROM Account'),
      'SOQL should contain FROM Account'
    );
    System.assert(soql.contains('WHERE'), 'SOQL should contain WHERE');
  }

  @isTest
  static void test_run() {
    IQuery q = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'))
      .setLimit(1);

    // Test running q
    List<SObject> results = q.run();
    System.assertNotEquals(null, results, 'Results should not be null');
  }

  @isTest
  static void test_fetch() {
    IQuery q = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'))
      .setLimit(1);

    // Test fetching single record
    SObject result = q.fetch();
    // Result may be null if no records exist, which is expected
  }

  @isTest
  static void test_fetch_with_limit() {
    IQuery q = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'));

    // Test fetching with limit
    List<SObject> results = q.fetch(5);
    System.assertNotEquals(null, results, 'Results should not be null');
    System.assert(results.size() <= 5, 'Results should not exceed limit');
  }

  @isTest
  static void test_count() {
    IQuery q = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'));

    // Test count q
    Integer count = q.count();
    System.assertNotEquals(null, count, 'Count should not be null');
    System.assert(count >= 0, 'Count should be non-negative');
  }

  @isTest
  static void test_toLocator() {
    IQuery q = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'));

    // Test q locator
    Database.QueryLocator locator = q.toLocator();
    System.assertNotEquals(null, locator, 'Query locator should not be null');
  }

  @isTest
  static void test_fluent_chaining() {
    // Test comprehensive fluent chaining
    IQuery q = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'))
      .addCondition(Application.s.gt(Account.AnnualRevenue, 1000000))
      .setLimit(100)
      .setOffset(50)
      .withSecurity(true)
      .withSharing(true);

    // Add ordering separately to avoid chaining issues
    q.orderings().add(Application.s.ordering(Account.Name, true, false));

    // Add all fields using concrete class method
    Query concreteQuery = (Query) q;
    concreteQuery.fields().addAll();
  }

  @isTest
  static void test_initialization_errors() {
    // Test initialization error handling through public methods
    Boolean threw1 = false;
    try {
      new Query((IModel) null);
    } catch (Exception e) {
      threw1 = true;
    }
    System.assert(threw1, 'Should throw exception for null model');

    // Test that normal initialization works
    IQuery q = new Query(Application.s.model(Account.SObjectType));
    System.assertNotEquals(null, q, 'Query should initialize successfully');
  }

  @isTest
  static void test_deepClone_independence() {
    // Test that modifying a cloned query doesn't affect the original
    IQuery original = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'));

    String originalSoql1 = original.toSoql();
    System.assert(
      originalSoql1.contains('Type'),
      'Original should contain Type condition'
    );
    System.assert(
      !originalSoql1.contains('Industry'),
      'Original should not contain Industry initially'
    );

    // Deep clone the query
    IQuery cloned = original.deepClone();

    // Modify the CLONED query by adding a new condition
    cloned.addCondition(Application.s.eq(Account.Industry, 'Technology'));

    // Get SOQL from both queries after modification
    String originalSoql2 = original.toSoql();
    String clonedSoql = cloned.toSoql();

    // Verify clone has the new condition
    System.assert(
      clonedSoql.contains('Industry'),
      'Cloned query should contain Industry condition'
    );

    // Verify original is unchanged
    System.assert(
      !originalSoql2.contains('Industry'),
      'Original query should NOT contain Industry condition after modifying clone'
    );

    // Verify original SOQL hasn't changed at all
    System.assertEquals(
      originalSoql1,
      originalSoql2,
      'Original query SOQL should remain unchanged after modifying clone'
    );
  }

  @isTest
  static void test_deepClone_with_subqueries() {
    // Test that subqueries are also deep cloned
    IQuery contactSubquery = new Query(Application.s.model(Contact.SObjectType))
      .addCondition(Application.s.eq(Contact.Email, 'test@example.com'));

    IQuery original = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'))
      .addSubquery('Contacts', contactSubquery);

    // Clone the query
    IQuery cloned = original.deepClone();

    // Modify the cloned query's subquery
    Map<String, IQuery> clonedSubqueries = cloned.getSubqueryMap();
    IQuery clonedContactQuery = clonedSubqueries.get('Contacts');
    clonedContactQuery.addCondition(
      Application.s.eq(Contact.FirstName, 'John')
    );

    // Get SOQL from both
    String originalSoql = original.toSoql();
    String clonedSoql = cloned.toSoql();

    // Verify clone has the new subquery condition
    System.assert(
      clonedSoql.contains('FirstName'),
      'Cloned subquery should contain FirstName condition'
    );

    // Verify original subquery is unchanged
    System.assert(
      !originalSoql.contains('FirstName'),
      'Original subquery should NOT contain FirstName condition'
    );
  }

  @isTest
  static void test_deepClone_reverse_modification() {
    // Test modifying original after cloning doesn't affect clone
    IQuery original = new Query(Application.s.model(Account.SObjectType))
      .addCondition(Application.s.eq(Account.Type, 'Customer'));

    // Clone first
    IQuery cloned = original.deepClone();
    String clonedSoql1 = cloned.toSoql();

    // Then modify the ORIGINAL
    original.addCondition(Application.s.eq(Account.Industry, 'Technology'));

    // Get SOQL after modification
    String originalSoql = original.toSoql();
    String clonedSoql2 = cloned.toSoql();

    // Verify original has the new condition
    System.assert(
      originalSoql.contains('Industry'),
      'Original should contain Industry condition'
    );

    // Verify clone is unchanged
    System.assert(
      !clonedSoql2.contains('Industry'),
      'Clone should NOT contain Industry condition added to original after cloning'
    );

    // Verify clone SOQL hasn't changed
    System.assertEquals(
      clonedSoql1,
      clonedSoql2,
      'Clone SOQL should remain unchanged after modifying original'
    );
  }

  @isTest
  static void test_aggregate_in_where_throws() {
    // Verify that aggregate functions cannot be used in WHERE clause
    IQuery q = new Query(Application.s.model(Account.SObjectType));
    q.filters().add(Application.s.gt(Application.s.count(Account.Id), 5));

    Boolean exceptionThrown = false;
    String exceptionMessage = '';
    try {
      q.toSoql();
    } catch (Query.UnifValidationException e) {
      exceptionThrown = true;
      exceptionMessage = e.getMessage();
    }

    System.assert(
      exceptionThrown,
      'Should throw exception when aggregate function used in WHERE clause'
    );
    System.assert(
      exceptionMessage.contains(
        'Aggregate functions cannot be used in WHERE clause'
      ),
      'Exception message should mention aggregate functions and WHERE clause. Got: ' +
      exceptionMessage
    );
  }

  @IsTest
  static void forUpdateLocksTheRowsAQueryReturns() {
    IQuery locking = Application.s.model(Account.SObjectType).query().setLimit(5).setOffset(2).forUpdate(true);
    locking.addCondition(Application.s.eq(Account.Name, 'Acme'));

    Assert.areEqual('SELECT Id FROM Account WHERE (Name = \'Acme\') LIMIT 5 OFFSET 2 FOR UPDATE', locking.toSoql());
    Assert.areEqual(locking.toSoql(), locking.deepClone().toSoql(), 'a copy locks too');
    Assert.isFalse(locking.forUpdate(null).toSoql().contains('FOR UPDATE'), 'null is off');
    Assert.isFalse(Application.s.model(Account.SObjectType).query().toSoql().contains('FOR UPDATE'), 'off unless asked for');
  }

  @IsTest
  static void aLockingQueryRunsAndCountsAndMakesALocator() {
    insert new Account(Name = 'Acme');
    IQuery locking = Application.s.model(Account.SObjectType).query().forUpdate(true);
    locking.addCondition(Application.s.eq(Account.Name, 'Acme'));

    Assert.areEqual(1, locking.run().size());
    Assert.isNotNull(locking.fetch());
    Assert.areEqual(1, locking.count(), 'a count has no rows to lock, so the lock is left out');
    Assert.isFalse(locking.toLocator().getQuery().containsIgnoreCase('FOR UPDATE'), 'a locator cannot lock');
  }

  @IsTest
  static void thePlatformRefusesALockWithAnOrdering() {
    IQuery ordered = Application.s.model(Account.SObjectType).query().forUpdate(true);
    ordered.orderings().add(Application.s.ordering(Account.Name, true, false));

    String refusal;
    try {
      ordered.run();
    } catch (QueryException refused) {
      refusal = refused.getMessage();
    }
    Assert.isNotNull(refusal, 'FOR UPDATE and ORDER BY ran together');
  }

  @IsTest
  static void filtersBelongToTheQuerysOwnCore() {
    Core own = new Core(new SchemeDefault());
    IQuery q = own.model(Account.SObjectType).query();
    q.filters().add(own.eq(Account.Name, 'Acme'));

    q.toSoql();

    Assert.isTrue(q.filters().source() === own.model(Account.SObjectType), 'resolved by the core that built the query, not the global one');
  }
}
