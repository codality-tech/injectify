@isTest
public class QueryTest {
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
      ((Query) q).isSecurityEnforced() && !soql.contains('SECURITY_ENFORCED'),
      'the query remembers withSecurity(true) and no longer writes the retired clause'
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
      ((Query) q).isSecurityEnforced() && !soql.contains('SECURITY_ENFORCED'),
      'the query remembers withSecurity(true) and no longer writes the retired clause'
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
      ((Query) cloned).isSecurityEnforced() && !clonedSoql.contains('SECURITY_ENFORCED'),
      'the query remembers withSecurity(true) and no longer writes the retired clause'
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
      ((Query) q).isSecurityEnforced() && !soql2.contains('SECURITY_ENFORCED'),
      'the query remembers withSecurity(true) and no longer writes the retired clause'
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
      ((Query) q).isSecurityEnforced() && !soql.contains('SECURITY_ENFORCED'),
      'the query remembers withSecurity(true) and no longer writes the retired clause'
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

  // --- semi-joins and anti-joins ----------------------------------------------------------------

  // SELECT AccountId FROM Contact WHERE MailingCity = <city>
  private static IQuery contactsIn(String city) {
    return contactsIn(Application.s, city);
  }

  /** The same from a core of the caller's: the one inner query the semi-join tests of every class use. */
  public static IQuery contactsIn(ICore owner, String city) {
    IQuery innerQuery = owner.model(Contact.SObjectType).query();
    innerQuery.fields().add(new Set<SObjectField>{ Contact.AccountId });
    innerQuery.filters().add(owner.eq(Contact.MailingCity, city));
    return innerQuery;
  }

  // What writing an account query with this inner query is refused with, or null when it is written.
  private static String joinRefusal(IQuery innerQuery) {
    IQuery outerQuery = Application.s.model(Account.SObjectType).query();
    outerQuery.filters().add(Application.s.iin(Account.Id, innerQuery));
    return writeRefusal(outerQuery);
  }

  // What the framework refuses to write the query with, or null when it writes it.
  private static String writeRefusal(IQuery q) {
    try {
      q.toSoql(true);
    } catch (Query.UnifValidationException refused) {
      return refused.getMessage();
    }
    return null;
  }

  // The same for running it: the refusal comes before anything is sent.
  private static String runRefusal(IQuery q) {
    try {
      q.run();
    } catch (Query.UnifValidationException refused) {
      return refused.getMessage();
    }
    return null;
  }

  @IsTest
  static void aQueryAsTheValueOfInMakesASemiJoin() {
    IQuery outerQuery = Application.s.model(Account.SObjectType).query();
    outerQuery.filters().add(Application.s.eq(Account.Industry, 'Energy'));
    outerQuery.filters().add(Application.s.iin(Account.Id, contactsIn('Seattle')));
    outerQuery.filters().add(Application.s.ne(Account.Name, 'Acme'));

    Assert.areEqual(
      'SELECT Id FROM Account WHERE (Industry = \'Energy\' AND Id IN (SELECT AccountId FROM Contact WHERE (MailingCity = \'Seattle\')) AND Name != \'Acme\')',
      outerQuery.toSoql()
    );
    Assert.areEqual(
      'SELECT Id FROM Account WHERE (Industry = :a0 AND Id IN (SELECT AccountId FROM Contact WHERE (MailingCity = :a1)) AND Name != :a2)',
      outerQuery.toSoql(true),
      'the inner value is numbered where it stands, between the outer ones'
    );
  }

  @IsTest
  static void aQueryAsTheValueOfNotInMakesAnAntiJoin() {
    IQuery outerQuery = Application.s.model(Account.SObjectType).query();
    IFieldCondition anti = Application.s.nin(Account.Id, contactsIn('O\'Hare'));
    outerQuery.filters().add(anti);

    Assert.areEqual(
      'SELECT Id FROM Account WHERE (Id NOT IN (SELECT AccountId FROM Contact WHERE (MailingCity = \'O\\\'Hare\')))',
      outerQuery.toSoql(),
      'inline, the inner value is escaped like any other'
    );
    Assert.areEqual('SELECT Id FROM Account WHERE (Id NOT IN (SELECT AccountId FROM Contact WHERE (MailingCity = :a0)))', outerQuery.toSoql(true));
    Assert.isInstanceOfType(anti.value(), IQuery.class, 'the value of the condition is the inner query');
    Assert.areEqual(Enums.Comparator.NIN, anti.operator());
  }

  @IsTest
  static void anInnerQueryWithNoFieldChosenSelectsItsId() {
    IQuery energy = Application.s.model(Account.SObjectType).query();
    energy.filters().add(Application.s.eq(Account.Industry, 'Energy'));

    IQuery contacts = Application.s.model(Contact.SObjectType).query();
    contacts.filters().add(Application.s.iin(Contact.AccountId, energy));
    Assert.areEqual('SELECT Id FROM Contact WHERE (AccountId IN (SELECT Id FROM Account WHERE (Industry = \'Energy\')))', contacts.toSoql());

    // The left side by name, the operator chosen at run time, and Id named beside the lookup field.
    IQuery reports = Application.s.model(Contact.SObjectType).query();
    reports.fields().add(new Set<SObjectField>{ Contact.Id, Contact.AccountId });
    IQuery accounts = Application.s.model(Account.SObjectType).query();
    accounts.filters().add(Application.s.cond(Enums.Comparator.NIN, 'Id', reports));
    Assert.areEqual('SELECT Id FROM Account WHERE (Id NOT IN (SELECT AccountId FROM Contact))', accounts.toSoql());
  }

  @IsTest
  static void aFactoryQueryIsAnInnerQueryOnceItsDefaultFieldsAreCleared() {
    IQuery innerQuery = Application.s.qf().make(Contact.SObjectType);

    String refusal = joinRefusal(innerQuery);
    Assert.isNotNull(refusal, 'the default fields are not one field');
    Assert.isTrue(refusal.startsWith('Cannot use the query on Contact in a semi-join: it selects '), refusal);
    Assert.isTrue(refusal.endsWith(' fields besides Id'), refusal);

    innerQuery.fields().clearFields().add(new Set<SObjectField>{ Contact.AccountId });
    Assert.isNull(joinRefusal(innerQuery));

    innerQuery.fields().clearFields();
    IQuery cases = Application.s.model(Case.SObjectType).query();
    cases.filters().add(Application.s.iin(Case.ContactId, innerQuery));
    Assert.areEqual('SELECT Id FROM Case WHERE (ContactId IN (SELECT Id FROM Contact))', cases.toSoql(), 'cleared, it selects its Id');
  }

  @IsTest
  static void anInnerQuerySelectsOneIdOrLookupField() {
    IQuery twoFields = Application.s.model(Contact.SObjectType).query();
    twoFields.fields().add(new Set<SObjectField>{ Contact.AccountId, Contact.ReportsToId });
    Assert.areEqual('Cannot use the query on Contact in a semi-join: it selects 2 fields besides Id', joinRefusal(twoFields));

    IQuery notALookup = Application.s.model(Contact.SObjectType).query();
    notALookup.fields().add(new Set<SObjectField>{ Contact.LastName });
    Assert.isTrue(joinRefusal(notALookup).endsWith(': it selects LastName, which is not a lookup field'), joinRefusal(notALookup));

    IQuery throughALookup = Application.s.model(Contact.SObjectType).query();
    throughALookup.fields().add('Account', new Set<SObjectField>{ Account.ParentId });
    Assert.isTrue(joinRefusal(throughALookup).endsWith(': it selects fields through a lookup'), joinRefusal(throughALookup));

    IQuery polymorphic = Application.s.model(Task.SObjectType).query();
    polymorphic.fields().add(Task.WhatId, new Set<SObjectField>{ Account.Name });
    Assert.areEqual('Cannot use the query on Task in a semi-join: it selects fields through a lookup', joinRefusal(polymorphic));

    IQuery withChildren = Application.s.model(Contact.SObjectType).query();
    withChildren.fields().add(new Set<SObjectField>{ Contact.AccountId });
    withChildren.addSubquery('Cases', Application.s.model(Case.SObjectType).query());
    Assert.isTrue(joinRefusal(withChildren).endsWith(': it has a child subquery'), joinRefusal(withChildren));
  }

  @IsTest
  static void anInnerQueryTakesNoLimitOrOffsetAndItsOrderingIsLeftOut() {
    IQuery limited = contactsIn('Seattle').setLimit(5);
    Assert.areEqual('Cannot use the query on Contact in a semi-join: it has a LIMIT or OFFSET', joinRefusal(limited));

    IQuery skipping = contactsIn('Seattle').setOffset(2);
    Assert.areEqual('Cannot use the query on Contact in a semi-join: it has a LIMIT or OFFSET', joinRefusal(skipping));

    // What the inner query says about ordering, locking and security is not written: the outer query decides.
    IQuery ordered = contactsIn('Seattle').forUpdate(true).withSharing(true).withSecurity(true);
    ordered.orderings().add(Application.s.ordering(Contact.LastName, true, false));
    IQuery outerQuery = Application.s.model(Account.SObjectType).query().setLimit(3);
    outerQuery.filters().add(Application.s.iin(Account.Id, ordered));
    Assert.areEqual(
      'SELECT Id FROM Account WHERE (Id IN (SELECT AccountId FROM Contact WHERE (MailingCity = \'Seattle\'))) LIMIT 3',
      outerQuery.toSoql()
    );
  }

  @IsTest
  static void aSemiJoinIsNotNestedInAnother() {
    IQuery cases = Application.s.model(Case.SObjectType).query();
    cases.fields().add(new Set<SObjectField>{ Case.ContactId });
    IQuery contacts = contactsIn('Seattle');
    contacts.filters().add(Application.s.iin(Contact.Id, cases));

    String refusal = joinRefusal(contacts);

    Assert.isNotNull(refusal);
    Assert.isTrue(refusal.contains('cannot be nested'), refusal);
  }

  @IsTest
  static void aChildSubqueryTakesASemiJoinAndSharesTheBinds() {
    IQuery cases = Application.s.model(Case.SObjectType).query();
    cases.fields().add(new Set<SObjectField>{ Case.ContactId });
    cases.filters().add(Application.s.eq(Case.Status, 'New'));
    IQuery kids = Application.s.model(Contact.SObjectType).query();
    kids.filters().add(Application.s.iin(Contact.Id, cases));
    IQuery parents = Application.s.model(Account.SObjectType).query().addSubquery('Contacts', kids);
    parents.filters().add(Application.s.eq(Account.Industry, 'Energy'));
    parents.filters().add(Application.s.nin(Account.Id, contactsIn('Seattle')));

    Assert.areEqual(
      'SELECT Id, (SELECT Id FROM Contacts WHERE (Id IN (SELECT ContactId FROM Case WHERE (Status = :a0)))) FROM Account ' +
        'WHERE (Industry = :a1 AND Id NOT IN (SELECT AccountId FROM Contact WHERE (MailingCity = :a2)))',
      parents.toSoql(true)
    );
    Assert.isTrue(parents.run().isEmpty(), 'the platform takes a semi-join at each level');
  }

  @IsTest
  static void aDeepCloneCopiesTheInnerQuery() {
    IQuery innerQuery = contactsIn('Seattle');
    IQuery outerQuery = Application.s.model(Account.SObjectType).query();
    outerQuery.filters().add(Application.s.iin(Account.Id, innerQuery));

    IQuery copy = outerQuery.deepClone();
    innerQuery.filters().add(Application.s.eq(Contact.LastName, 'Smith'));

    Assert.isTrue(outerQuery.toSoql().contains('Smith'), 'the original shares the inner query it was given');
    Assert.areEqual(
      'SELECT Id FROM Account WHERE (Id IN (SELECT AccountId FROM Contact WHERE (MailingCity = \'Seattle\')))',
      copy.toSoql(),
      'the copy has an inner query of its own'
    );
    Object copied = ((IFieldCondition) copy.filters().getAll()[0]).value();
    Assert.isInstanceOfType(copied, IQuery.class);
    Assert.isFalse(copied === (Object) innerQuery);
  }

  @IsTest
  static void aSemiJoinAndAnAntiJoinRunAgainstRecords() {
    Account seattle = new Account(Name = 'Has Seattle');
    Account tacoma = new Account(Name = 'Has Tacoma');
    Account childless = new Account(Name = 'No contacts');
    insert new List<Account>{ seattle, tacoma, childless };
    insert new List<Contact>{
      new Contact(LastName = 'North', AccountId = seattle.Id, MailingCity = 'Seattle'),
      new Contact(LastName = 'South', AccountId = tacoma.Id, MailingCity = 'Tacoma'),
      new Contact(LastName = 'Loose', MailingCity = 'Seattle') // no account: the inner query returns a null
    };

    IQuery semi = Application.s.model(Account.SObjectType).query();
    semi.fields().add(new Set<SObjectField>{ Account.Name });
    semi.filters().add(Application.s.iin(Account.Id, contactsIn('Seattle')));
    List<Account> matched = (List<Account>) semi.run();
    Assert.areEqual(1, matched.size());
    Assert.areEqual('Has Seattle', matched[0].Name);
    Assert.areEqual(1, semi.count());
    Assert.areEqual(seattle.Id, semi.fetch().Id);
    Database.QueryLocatorIterator walked = semi.toLocator().iterator();
    Assert.isTrue(walked.hasNext());
    Assert.areEqual(seattle.Id, walked.next().Id);
    Assert.isFalse(walked.hasNext());

    IQuery anti = Application.s.model(Account.SObjectType).query();
    anti.fields().add(new Set<SObjectField>{ Account.Name });
    anti.filters().add(Application.s.nin(Account.Id, contactsIn('Seattle')));
    anti.orderings().add(Application.s.ordering(Account.Name, true, false));
    List<Account> others = (List<Account>) anti.run();
    Assert.areEqual(2, others.size(), 'a null among the inner Ids rules nothing out');
    Assert.areEqual('Has Tacoma', others[0].Name);
    Assert.areEqual('No contacts', others[1].Name);
    Assert.areEqual(2, anti.count());

    // From the child's side: a lookup on the left, the parent's Id on the right.
    IQuery named = Application.s.model(Account.SObjectType).query();
    named.filters().add(Application.s.lk(Account.Name, 'Has %'));
    IQuery ofNamed = Application.s.model(Contact.SObjectType).query();
    ofNamed.filters().add(Application.s.iin(Contact.AccountId, named));
    Assert.areEqual(2, ofNamed.count(), 'North and South');
    IQuery notOfNamed = Application.s.model(Contact.SObjectType).query();
    notOfNamed.fields().add(new Set<SObjectField>{ Contact.LastName });
    notOfNamed.filters().add(Application.s.nin(Contact.AccountId, named));
    List<Contact> unattached = (List<Contact>) notOfNamed.run();
    Assert.areEqual(1, unattached.size(), 'an anti-join on a lookup returns the rows whose lookup is empty');
    Assert.areEqual('Loose', unattached[0].LastName);
  }

  @IsTest
  static void thePlatformsOwnRulesForSemiJoinsComeThroughAsItsErrors() {
    // Each of these is written without complaint; the platform refuses it when it runs, with its own message.
    Map<String, IQuery> refusedByThePlatform = new Map<String, IQuery>();

    IQuery underOr = Application.s.model(Account.SObjectType).query();
    underOr.filters().add(
      Application.s.any(new List<ICondition>{ Application.s.eq(Account.Name, 'Acme'), Application.s.iin(Account.Id, contactsIn('Seattle')) })
    );
    refusedByThePlatform.put('Semi join sub-selects are not allowed with the \'OR\' operator', underOr);

    IQuery negated = Application.s.model(Account.SObjectType).query();
    negated.filters().add(Application.s.neg(Application.s.iin(Account.Id, contactsIn('Seattle'))));
    refusedByThePlatform.put('\'NOT\' operator cannot be combined with semi/anti join subqueries', negated);

    IQuery three = Application.s.model(Account.SObjectType).query();
    three.filters().add(Application.s.iin(Account.Id, contactsIn('Seattle')));
    three.filters().add(Application.s.iin(Account.Id, contactsIn('Tacoma')));
    three.filters().add(Application.s.nin(Account.Id, contactsIn('Olympia')));
    refusedByThePlatform.put('Maximum 2 semi join sub-selects are allowed', three);

    IQuery parents = Application.s.model(Account.SObjectType).query();
    parents.fields().add(new Set<SObjectField>{ Account.ParentId });
    IQuery sameObject = Application.s.model(Account.SObjectType).query();
    sameObject.filters().add(Application.s.iin(Account.Id, parents));
    refusedByThePlatform.put('The inner and outer selects should not be on the same object type', sameObject);

    IQuery acrossALookup = Application.s.model(Contact.SObjectType).query();
    acrossALookup.filters().add(
      Application.s.iin(Account.OwnerId, Application.s.model(User.SObjectType).query()).prepend(Application.s.reference(Contact.AccountId))
    );
    Assert.areEqual('SELECT Id FROM Contact WHERE (Account.OwnerId IN (SELECT Id FROM User))', acrossALookup.toSoql());
    refusedByThePlatform.put('cannot have more than one level of relationships', acrossALookup);

    IQuery grouped = Application.s.model(Account.SObjectType).query();
    grouped.filters().add(Application.s.eq(Account.Industry, 'Energy'));
    grouped.filters().add(
      Application.s.all(new List<ICondition>{ Application.s.eq(Account.Name, 'Acme'), Application.s.iin(Account.Id, contactsIn('Seattle')) })
    );
    refusedByThePlatform.put('only allowed at the top level WHERE expressions', grouped);

    IQuery wrongObject = Application.s.model(Account.SObjectType).query();
    wrongObject.filters().add(Application.s.iin(Account.Id, Application.s.model(Contact.SObjectType).query()));
    refusedByThePlatform.put('should point to the same object type', wrongObject);

    for (String rule : refusedByThePlatform.keySet()) {
      IQuery refused = refusedByThePlatform.get(rule);
      Assert.isNull(writeRefusal(refused), 'the framework leaves this to the platform: ' + rule);
      try {
        refused.run();
        Assert.fail('The platform ran a semi-join it has a rule against: ' + rule);
      } catch (QueryException platformRule) {
        Assert.isTrue(platformRule.getMessage().contains(rule), rule + ' was expected, not: ' + platformRule.getMessage());
      }
    }

    // Two in one query run, and so does one beside an OR group.
    IQuery two = Application.s.model(Account.SObjectType).query();
    two.filters().add(Application.s.iin(Account.Id, contactsIn('Seattle')));
    two.filters().add(Application.s.nin(Account.Id, contactsIn('Tacoma')));
    two.filters().add(
      Application.s.any(new List<ICondition>{ Application.s.eq(Account.Name, 'Acme'), Application.s.eq(Account.Name, 'Globex') })
    );
    Assert.isTrue(two.run().isEmpty());
  }

  // The statement's own options: ALL ROWS, USING SCOPE, FOR VIEW, FOR REFERENCE

  @IsTest
  static void theOptionsAreWrittenWhereThePlatformTakesThem() {
    IQuery q = Application.s.model(Account.SObjectType).query().setLimit(5).setOffset(2);
    q.addCondition(Application.s.eq(Account.Name, 'Acme'));
    q.orderings().add(Application.s.ordering(Account.Name, true, false));

    q.usingScope(Enums.FilterScope.MINE).forView(true).allRows(true);
    Assert.areEqual(
      'SELECT Id FROM Account USING SCOPE mine WHERE (Name = \'Acme\') ORDER BY Name ASC NULLS FIRST LIMIT 5 OFFSET 2 FOR VIEW ALL ROWS',
      q.toSoql()
    );
    Assert.areEqual(q.toSoql(), q.deepClone().toSoql(), 'a copy carries the options');
    Assert.areEqual(q.toSoql(), new Query((Query) q).toSoql(), 'and so does the copy constructor');
    Assert.areEqual(
      'SELECT Id FROM Account USING SCOPE mine WHERE (Name = :a0) ORDER BY Name ASC NULLS FIRST LIMIT 5 OFFSET 2 FOR VIEW ALL ROWS',
      q.toSoql(true)
    );

    q.forView(false).forReference(true).allRows(null).usingScope(Enums.FilterScope.SCOPING_RULE);
    Assert.areEqual(
      'SELECT Id FROM Account USING SCOPE scopingRule WHERE (Name = \'Acme\') ORDER BY Name ASC NULLS FIRST LIMIT 5 OFFSET 2 FOR REFERENCE',
      q.toSoql()
    );

    q.usingScope(null).forReference(null);
    Assert.areEqual('SELECT Id FROM Account WHERE (Name = \'Acme\') ORDER BY Name ASC NULLS FIRST LIMIT 5 OFFSET 2', q.toSoql(), 'null is off');

    Assert.areEqual(
      'SELECT Id FROM Account FOR REFERENCE FOR UPDATE',
      Application.s.model(Account.SObjectType).query().forUpdate(true).forReference(true).toSoql(),
      'the lock comes after the mark'
    );
  }

  @IsTest
  static void everyScopeIsWrittenAsTheSoqlReferenceNamesIt() {
    Map<Enums.FilterScope, String> written = new Map<Enums.FilterScope, String>{
      Enums.FilterScope.DELEGATED => 'delegated',
      Enums.FilterScope.EVERYTHING => 'everything',
      Enums.FilterScope.MINE => 'mine',
      Enums.FilterScope.MINE_AND_MY_GROUPS => 'mine_and_my_groups',
      Enums.FilterScope.MY_TERRITORY => 'my_territory',
      Enums.FilterScope.MY_TEAM_TERRITORY => 'my_team_territory',
      Enums.FilterScope.SCOPING_RULE => 'scopingRule',
      Enums.FilterScope.TEAM => 'team'
    };

    Assert.areEqual(Enums.FilterScope.values().size(), written.size());
    for (Enums.FilterScope scope : written.keySet()) {
      Assert.areEqual(
        'SELECT Id FROM Task USING SCOPE ' + written.get(scope),
        Application.s.model(Task.SObjectType).query().usingScope(scope).toSoql()
      );
    }
  }

  @IsTest
  static void allRowsReadsTheRecycleBinInEveryWayOfRunning() {
    Account kept = new Account(Name = 'Kept');
    Account binned = new Account(Name = 'Binned');
    insert new List<Account>{ kept, binned };
    delete binned;
    IQuery q = Application.s.model(Account.SObjectType).query();
    q.fields().add(new Set<SObjectField>{ Account.Name, Account.IsDeleted });

    Assert.areEqual(1, q.run().size());
    Assert.areEqual(1, q.count());

    q.allRows(true);
    Assert.areEqual(2, q.run().size());
    Assert.areEqual(2, q.count(), 'a count takes ALL ROWS too');
    Assert.areEqual(2, q.fetch(5).size());
    Integer located = 0;
    Database.QueryLocatorIterator rows = q.toLocator().iterator();
    while (rows.hasNext()) {
      rows.next();
      located++;
    }
    Assert.areEqual(2, located, 'and so does a locator');

    q.addCondition(Application.s.eq(Account.IsDeleted, true));
    Assert.areEqual('Binned', ((Account) q.fetch()).Name);
  }

  @IsTest
  static void aScopeNarrowsTheRecordsToTheRunningUsers() {
    insert new Account(Name = 'Mine');
    IQuery mine = Application.s.model(Account.SObjectType).query().usingScope(Enums.FilterScope.MINE);
    IQuery everything = Application.s.model(Account.SObjectType).query().usingScope(Enums.FilterScope.EVERYTHING);

    Assert.areEqual(1, mine.run().size(), 'the running user owns it');
    Assert.areEqual(1, mine.count(), 'a count takes the scope too');
    Assert.isTrue(mine.toLocator().getQuery().containsIgnoreCase('USING SCOPE mine'));

    User colleague = new User(
      ProfileId = UserInfo.getProfileId(),
      LastName = 'Colleague',
      Alias = 'collg',
      Email = 'colleague@scope.example.com',
      Username = 'colleague.' + UserInfo.getOrganizationId() + '.' + System.now().getTime() + '@scope.example.com',
      TimeZoneSidKey = 'GMT',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    System.runAs(colleague) {
      Assert.areEqual(0, mine.run().size(), 'someone else owns it');
      Assert.areEqual(0, mine.count());
      Assert.areEqual(1, everything.run().size());
    }
  }

  @IsTest
  static void aViewedOrReferencedQueryRunsInEveryWay() {
    insert new Account(Name = 'Seen');
    IQuery forView = Application.s.model(Account.SObjectType).query().forView(true);
    forView.addCondition(Application.s.eq(Account.Name, 'Seen'));
    IQuery forReference = Application.s.model(Account.SObjectType).query().forReference(true).setLimit(5);
    forReference.addCondition(Application.s.eq(Account.Name, 'Seen'));

    Assert.areEqual('SELECT Id FROM Account WHERE (Name = :a0) FOR VIEW', forView.toSoql(true));
    Assert.areEqual('SELECT Id FROM Account WHERE (Name = :a0) LIMIT 5 FOR REFERENCE', forReference.toSoql(true));
    Assert.areEqual(1, forView.run().size());
    Assert.isNotNull(forView.fetch());
    Assert.areEqual(1, forReference.run().size());
    Assert.areEqual(1, forReference.fetch(1).size());
    Assert.areEqual(1, forView.count(), 'a count returns no rows to mark, so the mark is left out');
    Assert.isTrue(forView.toLocator().getQuery().containsIgnoreCase('FOR VIEW'), 'a locator takes it');
    Assert.isTrue(forReference.toLocator().getQuery().containsIgnoreCase('FOR REFERENCE'));

    // With a lock as well: the platform takes the mark, then the lock
    Assert.areEqual(1, forView.forUpdate(true).run().size());
    Assert.areEqual(1, forReference.forUpdate(true).fetch(1).size());
  }

  @IsTest
  static void theMarksAreSentWithTheQueryThatRuns() {
    // A record inserted in a test has LastViewedDate and LastReferencedDate from the start, so
    // what a mark does cannot be seen here. What can be seen is what is sent.
    MockScheme scheme = new MockScheme();
    Core mocked = new Core(scheme);
    IQuery viewed = mocked.model(Account.SObjectType).query().forView(true).forUpdate(true);
    viewed.addCondition(mocked.eq(Account.Name, 'Seen'));
    IQuery referenced = viewed.deepClone().forView(false).forReference(true).forUpdate(false);

    viewed.run();
    viewed.fetch(2);
    viewed.count();
    referenced.run();

    Assert.areEqual(
      new List<String>{
        'SELECT Id FROM Account WHERE (Name = :a0) FOR VIEW FOR UPDATE',
        'SELECT Id FROM Account WHERE (Name = :a0) LIMIT 2 FOR VIEW FOR UPDATE',
        'SELECT COUNT() FROM Account WHERE (Name = :a0)',
        'SELECT Id FROM Account WHERE (Name = :a0) FOR REFERENCE'
      },
      scheme.queries()
    );
  }

  @IsTest
  static void optionsThePlatformRefusesTogetherAreRefusedWithAReason() {
    IQuery both = Application.s.model(Account.SObjectType).query().forView(true).forReference(true);
    IQuery lockedBin = Application.s.model(Account.SObjectType).query().forUpdate(true).allRows(true);
    String bothMarks = 'Cannot write FOR VIEW with FOR REFERENCE on Account: a query takes one or the other';
    String lockAndBin = 'Cannot write FOR UPDATE with ALL ROWS on Account: a query takes one or the other';

    Assert.areEqual(bothMarks, writeRefusal(both));
    Assert.areEqual(bothMarks, runRefusal(both));
    Assert.areEqual(0, both.count(), 'a count writes neither');

    Assert.areEqual(lockAndBin, writeRefusal(lockedBin));
    Assert.areEqual(lockAndBin, runRefusal(lockedBin));
    Assert.areEqual(0, lockedBin.count(), 'a count does not lock, so it keeps ALL ROWS');
    Assert.isTrue(lockedBin.toLocator().getQuery().containsIgnoreCase('ALL ROWS'), 'nor does a locator');
  }

  // Child subqueries

  @IsTest
  static void aChildSubqueryKeepsItsLimitAndOffset() {
    Account acme = new Account(Name = 'Acme');
    insert acme;
    insert new List<Contact>{
      new Contact(LastName = 'Adams', AccountId = acme.Id),
      new Contact(LastName = 'Baker', AccountId = acme.Id),
      new Contact(LastName = 'Clark', AccountId = acme.Id)
    };
    IQuery kids = Application.s.model(Contact.SObjectType).query().setLimit(2);
    kids.fields().add(new Set<SObjectField>{ Contact.LastName });
    kids.orderings().add(Application.s.ordering(Contact.LastName, true, false));
    IQuery parents = Application.s.model(Account.SObjectType).query().addSubquery('Contacts', kids);

    Assert.areEqual(
      'SELECT Id, (SELECT Id, LastName FROM Contacts ORDER BY LastName ASC NULLS FIRST LIMIT 2) FROM Account',
      parents.toSoql()
    );
    List<Contact> firstTwo = ((Account) parents.run()[0]).Contacts;
    Assert.areEqual(2, firstTwo.size(), 'the limit reaches the database');
    Assert.areEqual('Adams', firstTwo[0].LastName);

    kids.setOffset(1);
    Assert.areEqual(
      'SELECT Id, (SELECT Id, LastName FROM Contacts ORDER BY LastName ASC NULLS FIRST LIMIT 2 OFFSET 1) FROM Account',
      parents.toSoql()
    );
    Assert.areEqual(parents.toSoql(), parents.deepClone().toSoql());
    // The platform takes an offset in a subquery only when the parent query returns one row
    try {
      parents.run();
      Assert.fail('the platform took an offset in the subquery of a query without LIMIT 1');
    } catch (QueryException refused) {
      Assert.isTrue(refused.getMessage().contains('OFFSET'), refused.getMessage());
    }
    List<Contact> afterTheFirst = ((Account) parents.fetch()).Contacts;
    Assert.areEqual(2, afterTheFirst.size());
    Assert.areEqual('Baker', afterTheFirst[0].LastName, 'the offset reaches the database');
    Assert.areEqual('Clark', ((Account) parents.setLimit(1).run()[0]).Contacts[1].LastName);
  }

  @IsTest
  static void aChildSubqueryTakesNoAllRowsAndNoScope() {
    Map<String, IQuery> childByOption = new Map<String, IQuery>{
      'ALL ROWS' => Application.s.model(Contact.SObjectType).query().allRows(true),
      'USING SCOPE' => Application.s.model(Contact.SObjectType).query().usingScope(Enums.FilterScope.MINE)
    };

    for (String option : childByOption.keySet()) {
      IQuery parents = Application.s.model(Account.SObjectType).query().addSubquery('Contacts', childByOption.get(option));
      String refusal = 'Cannot write ' + option + ' in the subquery on Contacts: it belongs to the parent query';
      Assert.areEqual(refusal, writeRefusal(parents));
      Assert.areEqual(refusal, runRefusal(parents));
    }

    // On the parent they cover the query; a mark or a lock asked of a child is the parent's to ask
    IQuery marked = Application.s.model(Contact.SObjectType).query().forView(true).forUpdate(true);
    Assert.areEqual(
      'SELECT Id, (SELECT Id FROM Contacts) FROM Account USING SCOPE mine ALL ROWS',
      Application.s.model(Account.SObjectType).query().addSubquery('Contacts', marked).allRows(true).usingScope(Enums.FilterScope.MINE).toSoql()
    );
  }

  @IsTest
  static void theInnerQueryOfASemiJoinKeepsItsScopeAndTakesNoAllRows() {
    IQuery scoped = contactsIn('Seattle').usingScope(Enums.FilterScope.MINE).forView(true);
    IQuery outerQuery = Application.s.model(Account.SObjectType).query();
    outerQuery.filters().add(Application.s.iin(Account.Id, scoped));

    Assert.areEqual(
      'SELECT Id FROM Account WHERE (Id IN (SELECT AccountId FROM Contact USING SCOPE mine WHERE (MailingCity = :a0))) ALL ROWS',
      outerQuery.allRows(true).toSoql(true),
      'the scope is the inner query\'s own; ALL ROWS is the outer query\'s'
    );
    Assert.isTrue(outerQuery.run().isEmpty(), 'and the platform takes it');

    scoped.allRows(true);
    Assert.areEqual('Cannot use the query on Contact in a semi-join: it asks for ALL ROWS', writeRefusal(outerQuery));
  }

  // Date literals

  @IsTest
  static void aDateLiteralIsWrittenIntoTheQueryAndNeverBound() {
    Account acme = new Account(Name = 'Acme');
    insert acme;
    insert new List<Opportunity>{
      new Opportunity(Name = 'Closing', StageName = 'Prospecting', CloseDate = Date.today(), AccountId = acme.Id),
      new Opportunity(Name = 'Far off', StageName = 'Prospecting', CloseDate = Date.today().addDays(200), AccountId = acme.Id)
    };
    IQuery q = Application.s.model(Opportunity.SObjectType).query();
    q.fields().add(new Set<SObjectField>{ Opportunity.Name });
    q.filters().add(Application.s.eq(Opportunity.StageName, 'Prospecting'));
    q.filters().add(Application.s.le(Opportunity.CloseDate, DateLiteral.nextNDays(30)));
    q.filters().add(Application.s.iin(Opportunity.CreatedDate, new List<IDateLiteral>{ DateLiteral.today(), DateLiteral.yesterday() }));
    q.filters().add(Application.s.ne(Opportunity.Name, 'Other'));

    Assert.areEqual(
      'SELECT Id, Name FROM Opportunity WHERE (StageName = :a0 AND CloseDate <= NEXT_N_DAYS:30 AND CreatedDate IN (TODAY, YESTERDAY) AND Name != :a1)',
      q.toSoql(true),
      'the values around it are bound and numbered as if it were not there'
    );
    Assert.areEqual(
      'SELECT Id, Name FROM Opportunity WHERE (StageName = \'Prospecting\' AND CloseDate <= NEXT_N_DAYS:30 AND CreatedDate IN (TODAY, YESTERDAY) AND Name != \'Other\')',
      q.toSoql()
    );
    List<Opportunity> soon = (List<Opportunity>) q.run();
    Assert.areEqual(1, soon.size());
    Assert.areEqual('Closing', soon[0].Name);
    Assert.areEqual(1, q.count());

    // In a child subquery and in the inner query of a semi-join as well
    IQuery closing = Application.s.model(Opportunity.SObjectType).query();
    closing.fields().add(new Set<SObjectField>{ Opportunity.AccountId });
    closing.filters().add(Application.s.eq(Opportunity.CloseDate, DateLiteral.thisFiscalYear()));
    IQuery kids = Application.s.model(Opportunity.SObjectType).query();
    kids.filters().add(Application.s.gt(Opportunity.CloseDate, DateLiteral.nextNMonths(3)));
    IQuery accounts = Application.s.model(Account.SObjectType).query().addSubquery('Opportunities', kids);
    accounts.filters().add(Application.s.iin(Account.Id, closing));
    Assert.areEqual(
      'SELECT Id, (SELECT Id FROM Opportunities WHERE (CloseDate > NEXT_N_MONTHS:3)) FROM Account WHERE (Id IN (SELECT AccountId FROM Opportunity WHERE (CloseDate = THIS_FISCAL_YEAR)))',
      accounts.toSoql(true)
    );
    List<Account> found = (List<Account>) accounts.run();
    Assert.areEqual(1, found.size());
    Assert.areEqual(1, found[0].Opportunities.size(), 'the one that closes in 200 days');
  }

  // Paths through a polymorphic lookup

  @IsTest
  static void aPathThroughAPolymorphicLookupFiltersSelectsAndOrders() {
    Account acme = new Account(Name = 'Acme');
    insert acme;
    Opportunity deal = new Opportunity(Name = 'Deal', StageName = 'Prospecting', CloseDate = Date.today(), AccountId = acme.Id);
    Contact kim = new Contact(LastName = 'Kim', Email = 'kim@example.com', AccountId = acme.Id);
    insert new List<SObject>{ deal, kim };
    insert new List<Task>{
      new Task(Subject = 'about the account', WhatId = acme.Id, WhoId = kim.Id),
      new Task(Subject = 'about the deal', WhatId = deal.Id),
      new Task(Subject = 'about nothing')
    };
    IQuery q = Application.s.model(Task.SObjectType).query();
    q.fields().add(new Set<String>{ 'Subject', 'What.Type', 'What.Name', 'Who.Name', 'Owner.Name', 'Owner.Profile.Name' });
    q.filters().add(Application.s.iin('What.Type', new Set<String>{ 'Account', 'Opportunity' }));
    q.orderings().add(Application.s.ordering('What.Type', false, false));
    q.orderings().add(Application.s.ordering(new List<SObjectField>{ Task.WhatId, Schema.Name.Name }, true, true));

    Assert.areEqual(
      'SELECT Id, Subject, What.Type, What.Name, Who.Name, Owner.Name, Owner.Profile.Name FROM Task WHERE (What.Type IN :a0) ' +
      'ORDER BY What.Type DESC NULLS FIRST, What.Name ASC NULLS LAST',
      q.toSoql(true)
    );
    List<Task> found = (List<Task>) q.run();
    Assert.areEqual(2, found.size());
    Assert.areEqual('Opportunity', found[0].What.Type, 'ordered by the type, descending');
    Assert.areEqual('Deal', found[0].What.Name);
    Assert.areEqual('Account', found[1].What.Type);
    Assert.areEqual('Kim', found[1].Who.Name);
    // (The owner is a user of the org, and a test does not see the Name row of one: see the test below.)
    Assert.areEqual(2, q.count());

    // The same filter with field tokens: the far side of the lookup is the Name object
    IQuery typed = Application.s.model(Task.SObjectType).query().withSecurity(true);
    typed.fields().add(Task.WhatId, new Set<SObjectField>{ Schema.Name.Type });
    typed.filters().add(Application.s.eq(new List<SObjectField>{ Task.WhatId, Schema.Name.Type }, 'Opportunity'));
    typed.filters().add(Application.s.ne(new List<SObjectField>{ Task.WhoId, Schema.Name.Type }, 'Lead'));
    Assert.areEqual('SELECT Id, What.Type FROM Task WHERE (What.Type = \'Opportunity\' AND Who.Type != \'Lead\')', typed.toSoql());
    Assert.areEqual('Opportunity', ((Task) typed.fetch()).What.Type, 'runs with the read check on');
    Assert.areEqual(1, typed.run().size());

    // In memory, on the rows the database returned, the conditions and the ordering agree with it
    List<Task> everyTask = [SELECT Subject, WhatId, What.Type, What.Name, Who.Name, Owner.Type FROM Task];
    Map<ICondition, Integer> expected = new Map<ICondition, Integer>{
      Application.s.eq('What.Type', 'account') => 1,
      Application.s.ne('What.Type', 'Account') => 2,
      Application.s.eq('What.Type', null) => 1,
      Application.s.lk('What.Name', 'de%') => 1,
      Application.s.eq('Who.Name', 'KIM') => 1,
      Application.s.neg(Application.s.eq('What.Name', 'Acme')) => 2
    };
    for (ICondition condition : expected.keySet()) {
      IQuery counting = Application.s.model(Task.SObjectType).query().addCondition(condition);
      Integer inMemory = 0;
      for (Task row : everyTask) {
        inMemory += condition.evaluate(row) ? 1 : 0;
      }
      Assert.areEqual(expected.get(condition), counting.count(), counting.toSoql());
      Assert.areEqual(expected.get(condition), inMemory, counting.toSoql() + ' in memory');
    }
    IOrdering byType = Application.s.ordering('What.Type', true, true);
    byType.apply(everyTask);
    Assert.areEqual('Account', everyTask[0].What.Type);
    Assert.isNull(everyTask[2].WhatId, 'nulls last');
  }

  @IsTest
  static void aTargetsOwnFieldsStillNeedTypeofAndGoWithAFilterOnTheType() {
    Account acme = new Account(Name = 'Acme', Industry = 'Energy');
    insert acme;
    insert new Task(Subject = 'about the account', WhatId = acme.Id);
    IQuery q = Application.s.model(Task.SObjectType).query();
    q.fields().add(Task.WhatId, new Set<SObjectField>{ Account.Industry, Opportunity.Amount });
    q.filters().add(Application.s.eq('What.Type', 'Account'));

    Assert.areEqual(
      'SELECT Id, TYPEOF What WHEN Account THEN Id, Industry WHEN Opportunity THEN Id, Amount END FROM Task WHERE (What.Type = \'Account\')',
      q.toSoql()
    );
    Task found = (Task) q.fetch();
    Assert.areEqual('Energy', found.getSObject('What').get('Industry'));
    Assert.isTrue(Application.s.eq('What.Type', 'Account').evaluate(found), 'a row from TYPEOF is the account itself, and its type is read from that');
    Assert.isTrue(Application.s.eq('What.Name', null).evaluate(new Task(WhatId = acme.Id)), 'nothing but the Id: only the type can be told');

    // The platform refuses What.Name beside TYPEOF What, so the framework does, before the query is sent
    q.fields().add(new Set<String>{ 'What.Name' });
    try {
      q.run();
      Assert.fail('a path and TYPEOF through the same lookup were sent to the platform');
    } catch (Exception refused) {
      Assert.isFalse(refused instanceof QueryException, 'the platform was asked: ' + refused.getMessage());
      Assert.isTrue(refused.getMessage().startsWith('Cannot select What.Name beside TYPEOF What'), refused.getMessage());
    }
  }

  @IsTest
  static void aQueriedRowIsReadForWhatItsQuerySelected() {
    Account acme = new Account(Name = 'Acme');
    insert acme;
    insert new List<Task>{ new Task(Subject = 'about', WhatId = acme.Id), new Task(Subject = 'loose') };
    ICondition aboutAnAccount = Application.s.eq('What.Type', 'Account');
    ICondition aboutAcme = Application.s.eq('What.Name', 'Acme');
    aboutAnAccount.realize(Task.SObjectType);
    aboutAcme.realize(Task.SObjectType);

    // The lookup field alone: the type is read from the Id
    Map<String, Task> withId = bySubject([SELECT Subject, WhatId FROM Task]);
    Assert.isTrue(aboutAnAccount.evaluate(withId.get('about')));
    Assert.isFalse(aboutAnAccount.evaluate(withId.get('loose')));

    // The relationship alone: read from the row, and an empty relationship is an empty lookup
    Map<String, Task> withType = bySubject([SELECT Subject, What.Type FROM Task]);
    Assert.isTrue(aboutAnAccount.evaluate(withType.get('about')));
    Assert.isFalse(aboutAnAccount.evaluate(withType.get('loose')));
    Assert.isTrue(Application.s.eq('What.Type', null).evaluate(withType.get('loose')));

    // Neither: the platform's own complaint about a field that was not queried
    Map<String, Task> withNeither = bySubject([SELECT Subject FROM Task]);
    for (ICondition unreadable : new List<ICondition>{ aboutAnAccount, aboutAcme }) {
      try {
        unreadable.evaluate(withNeither.get('about'));
        Assert.fail('a field that was not queried was read as empty');
      } catch (SObjectException notQueried) {
        Assert.isTrue(notQueried.getMessage().contains('without querying the requested field'), notQueried.getMessage());
      }
    }
    // The Id does not tell the name
    try {
      aboutAcme.evaluate(withId.get('about'));
      Assert.fail('a name was read from an Id');
    } catch (SObjectException notQueried) {
      Assert.isTrue(notQueried.getMessage().contains('Task.What'), notQueried.getMessage());
    }
  }

  private static Map<String, Task> bySubject(List<Task> rows) {
    Map<String, Task> found = new Map<String, Task>();
    for (Task row : rows) {
      found.put(row.Subject, row);
    }
    return found;
  }

  @IsTest
  static void anOwnerIsReadThroughItsLookupWhenTheTestMadeIt() {
    User colleague = new User(
      ProfileId = UserInfo.getProfileId(),
      FirstName = 'Casey',
      LastName = 'Colleague',
      Alias = 'ccoll',
      Email = 'casey.colleague@owner.example.com',
      Username = 'casey.' + UserInfo.getOrganizationId() + '.' + System.now().getTime() + '@owner.example.com',
      TimeZoneSidKey = 'GMT',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert colleague;
    }
    insert new List<Task>{ new Task(Subject = 'theirs', OwnerId = colleague.Id), new Task(Subject = 'mine') };
    IQuery q = Application.s.model(Task.SObjectType).query();
    q.fields().add(new Set<String>{ 'Subject', 'OwnerId', 'Owner.Type', 'Owner.Name', 'Owner.Alias', 'Owner.IsActive', 'Owner.Profile.Name' });
    q.filters().add(Application.s.eq('Owner.Name', 'casey colleague'));

    List<Task> found = (List<Task>) q.run();

    Assert.areEqual(1, found.size(), q.toSoql());
    Assert.areEqual('theirs', found[0].Subject);
    Assert.areEqual('User', found[0].Owner.Type);
    Assert.areEqual('Casey Colleague', found[0].Owner.Name);
    Assert.areEqual('ccoll', found[0].Owner.Alias);
    Assert.areEqual(true, found[0].Owner.IsActive);
    Assert.isNotNull(found[0].getSObject('Owner').getSObject('Profile').get('Name'), 'through the Name object\'s own lookup');
    Assert.isTrue(Application.s.eq('Owner.Alias', 'CCOLL').evaluate(found[0]), 'and the row answers in memory');
    Assert.isTrue(Application.s.ne('Owner.Profile.Name', null).evaluate(found[0]));

    // A user of the org that the test did not make has no Name row in a test, although the user
    // itself is there: the path reads empty in the query. From the Id alone, in memory, it is a user.
    Task mine = [SELECT OwnerId, Owner.Type FROM Task WHERE Subject = 'mine'];
    Assert.isNull(mine.Owner, 'a test does not see the Name row of a user it did not make');
    Assert.isTrue(Application.s.eq('Owner.Type', 'User').evaluate(new Task(OwnerId = mine.OwnerId)));
  }

  @IsTest
  static void anOwnerThatIsAQueueIsCalledQueue() {
    Group queue = new Group(Name = 'Injectify Test Queue', Type = 'Queue');
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert queue;
      insert new QueueSobject(QueueId = queue.Id, SobjectType = 'Case');
    }
    insert new List<Case>{ new Case(Subject = 'queued', OwnerId = queue.Id), new Case(Subject = 'mine') };
    ICondition queued = Application.s.eq('Owner.Type', 'Queue');
    IQuery q = Application.s.model(Case.SObjectType).query().addCondition(queued);
    q.fields().add(new Set<String>{ 'Subject', 'Owner.Type', 'Owner.Name' });

    List<Case> found = (List<Case>) q.run();
    Assert.areEqual(1, found.size());
    Assert.areEqual('queued', found[0].Subject);
    Assert.areEqual('Queue', found[0].Owner.Type, 'the platform calls a queue Queue, not Group');
    Assert.areEqual('Injectify Test Queue', found[0].Owner.Name);

    // In memory: a row that carries Owner.Type is read from it, and the Id alone tells a user from a group
    Assert.isTrue(queued.evaluate(found[0]));
    Assert.isFalse(queued.evaluate(new Case(OwnerId = UserInfo.getUserId())));
    Assert.isTrue(Application.s.eq('Owner.Type', 'User').evaluate(new Case(OwnerId = UserInfo.getUserId())));
    Assert.isTrue(queued.evaluate(new Case(OwnerId = queue.Id)));
  }
}
