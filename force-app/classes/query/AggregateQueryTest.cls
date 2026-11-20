@isTest
private class AggregateQueryTest {
  @isTest
  static void test_smoke_test() {
    // Simple smoke test to verify basic functionality
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.aggregates().add(Application.s.count(Opportunity.Id));

    System.assertNotEquals(null, q, 'AggregateQuery should not be null');
    System.assertEquals(
      'Opportunity',
      q.source().name(),
      'Source should be Opportunity'
    );

    String soql = q.toSoql();
    System.assert(soql.contains('SELECT'), 'SOQL should contain SELECT');
    System.assert(
      soql.contains('FROM Opportunity'),
      'SOQL should contain FROM Opportunity'
    );
    System.assert(
      soql.contains('COUNT(Id) Id_cnt'),
      'Should contain auto-generated alias'
    );
  }

  @isTest
  static void test_basic_aggregate() {
    // Test basic aggregate functions with auto-generated aliases
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.aggregates().add(Application.s.count(Opportunity.Id));
    q.aggregates().add(Application.s.sum(Opportunity.Amount));

    String soql = q.toSoql();
    System.assert(
      soql.contains('COUNT(Id) Id_cnt'),
      'Should contain COUNT with auto-alias'
    );
    System.assert(
      soql.contains('SUM(Amount) Amount_sum'),
      'Should contain SUM with auto-alias'
    );
  }

  @isTest
  static void test_group_by() {
    // Test GROUP BY clause
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.aggregates().add(Application.s.count(Opportunity.Id));
    q.groupBys().add(Application.s.path(Opportunity.StageName));

    String soql = q.toSoql();
    System.assert(
      soql.contains('GROUP BY StageName'),
      'Should contain GROUP BY'
    );
    System.assert(
      soql.contains('StageName'),
      'Should contain StageName in SELECT'
    );
  }

  @isTest
  static void test_rollup() {
    // Test ROLLUP modifier with automatic GROUPING() indicators
    IAggregateQuery q = new AggregateQuery(
        Application.s.model(Opportunity.SObjectType)
      )
      .rollup();
    q.aggregates().add(Application.s.sum(Opportunity.Amount));
    q.groupBys().add(Application.s.path(Opportunity.StageName));

    String soql = q.toSoql();
    System.assert(
      soql.contains('GROUP BY ROLLUP(StageName)'),
      'Should contain ROLLUP with wrapped fields'
    );
    System.assert(
      soql.contains('GROUPING(StageName) StageName_grp'),
      'Should auto-add GROUPING() indicator'
    );
  }

  @isTest
  static void test_cube() {
    // Test CUBE modifier with automatic GROUPING() indicators
    IAggregateQuery q = new AggregateQuery(
        Application.s.model(Opportunity.SObjectType)
      )
      .cube();
    q.aggregates().add(Application.s.sum(Opportunity.Amount));
    q.groupBys().add(Application.s.path(Opportunity.StageName));

    String soql = q.toSoql();
    System.assert(
      soql.contains('GROUP BY CUBE(StageName)'),
      'Should contain CUBE with wrapped fields'
    );
    System.assert(
      soql.contains('GROUPING(StageName) StageName_grp'),
      'Should auto-add GROUPING() indicator'
    );
  }

  @isTest
  static void test_having() {
    // Test HAVING clause
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.aggregates().add(Application.s.sum(Opportunity.Amount));
    q.groupBys().add(Application.s.path(Opportunity.StageName));
    q.havingFilters()
      .add(Application.s.gt(Application.s.sum(Opportunity.Amount), 100000));

    String soql = q.toSoql();
    System.assert(soql.contains('HAVING'), 'Should contain HAVING');
    System.assert(
      soql.contains('SUM(Amount) > 100000'),
      'Should contain aggregate condition'
    );
  }

  @isTest
  static void test_where_clause() {
    // Test WHERE clause (pre-aggregation filter)
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.aggregates().add(Application.s.count(Opportunity.Id));
    q.groupBys().add(Application.s.path(Opportunity.StageName));
    q.filters().add(Application.s.eq(Opportunity.Type, 'New Customer'));

    String soql = q.toSoql();
    System.assert(soql.contains('WHERE'), 'Should contain WHERE');
    System.assert(
      soql.contains('Type = \'New Customer\''),
      'Should contain condition'
    );
  }

  @isTest
  static void test_deep_clone() {
    // Test deep cloning
    IAggregateQuery original = new AggregateQuery(
        Application.s.model(Opportunity.SObjectType)
      )
      .setLimit(10);
    original.aggregates().add(Application.s.sum(Opportunity.Amount));
    original.groupBys().add(Application.s.path(Opportunity.StageName));

    IAggregateQuery cloned = original.deepClone();
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
  static void test_count_distinct() {
    // Test COUNT_DISTINCT function with auto-generated _dis suffix
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.aggregates().add(Application.s.countDistinct(Opportunity.AccountId));

    String soql = q.toSoql();
    System.assert(
      soql.contains('COUNT_DISTINCT(AccountId) AccountId_dis'),
      'Should contain COUNT_DISTINCT with auto-generated _dis suffix'
    );
  }

  @isTest
  static void test_multiple_aggregates() {
    // Test multiple aggregate functions with auto-generated aliases
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.aggregates().add(Application.s.count(Opportunity.Id));
    q.aggregates().add(Application.s.sum(Opportunity.Amount));
    q.aggregates().add(Application.s.avg(Opportunity.Amount));
    q.aggregates().add(Application.s.min(Opportunity.Amount));
    q.aggregates().add(Application.s.max(Opportunity.Amount));
    q.groupBys().add(Application.s.path(Opportunity.StageName));

    String soql = q.toSoql();
    System.assert(soql.contains('COUNT(Id) Id_cnt'), 'Should contain COUNT');
    System.assert(
      soql.contains('SUM(Amount) Amount_sum'),
      'Should contain SUM'
    );
    System.assert(
      soql.contains('AVG(Amount) Amount_avg'),
      'Should contain AVG'
    );
    System.assert(
      soql.contains('MIN(Amount) Amount_min'),
      'Should contain MIN'
    );
    System.assert(
      soql.contains('MAX(Amount) Amount_max'),
      'Should contain MAX'
    );
  }

  @isTest
  static void test_with_security() {
    // Test security enforcement
    IAggregateQuery q = new AggregateQuery(
        Application.s.model(Opportunity.SObjectType)
      )
      .withSecurity(true);
    q.aggregates().add(Application.s.count(Opportunity.Id));

    String soql = q.toSoql();
    System.assert(
      ((AggregateQuery) q).isSecurityEnforced() && !soql.contains('SECURITY_ENFORCED'),
      'the query remembers withSecurity(true) and no longer writes the retired clause'
    );
  }

  @isTest
  static void test_limit_offset() {
    // Test LIMIT and OFFSET
    IAggregateQuery q = new AggregateQuery(
        Application.s.model(Opportunity.SObjectType)
      )
      .setLimit(10)
      .setOffset(5);
    q.aggregates().add(Application.s.count(Opportunity.Id));
    q.groupBys().add(Application.s.path(Opportunity.StageName));

    String soql = q.toSoql();
    System.assert(soql.contains('LIMIT 10'), 'Should contain LIMIT');
    System.assert(soql.contains('OFFSET 5'), 'Should contain OFFSET');
  }

  @isTest
  static void test_grouped_field() {
    // Test adding grouped fields to SELECT
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.aggregates().add(Application.s.sum(Opportunity.Amount));
    q.groupBys().add(Application.s.path(Opportunity.StageName));

    String soql = q.toSoql();
    System.assert(
      soql.contains('SUM(Amount) Amount_sum'),
      'Should contain aggregate in SELECT with auto-alias'
    );
  }

  @isTest
  static void test_factory_integration() {
    // Test aggregateQuery on Model
    IModel model = Application.s.model(Opportunity.SObjectType);
    IAggregateQuery q = model.aggregateQuery();

    System.assertNotEquals(null, q, 'Query should not be null from Model');
    System.assertEquals(
      'Opportunity',
      q.source().name(),
      'Source should be Opportunity'
    );
  }

  @isTest
  static void test_order_by() {
    // Test ORDER BY clause
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.aggregates().add(Application.s.sum(Opportunity.Amount));
    q.groupBys().add(Application.s.path(Opportunity.StageName));
    q.orderings()
      .add(
        Application.s.ordering(
          Application.s.path(Opportunity.StageName),
          false,
          false
        )
      );

    String soql = q.toSoql();
    System.assert(soql.contains('ORDER BY'), 'Should contain ORDER BY');
    System.assert(soql.contains('StageName'), 'Should order by grouped field');
  }

  @isTest
  static void test_multiple_group_by_fields() {
    // Test multiple GROUP BY fields
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.aggregates().add(Application.s.count(Opportunity.Id));
    q.groupBys().add(Application.s.path(Opportunity.StageName));
    q.groupBys().add(Application.s.path(Opportunity.Type));

    String soql = q.toSoql();
    System.assert(
      soql.contains('GROUP BY StageName, Type'),
      'Should contain multiple GROUP BY fields'
    );
  }

  @isTest
  static void test_aggregates_getter() {
    // Test aggregates() getter
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.aggregates().add(Application.s.sum(Opportunity.Amount));
    q.aggregates().add(Application.s.count(Opportunity.Id));

    Set<IAggregateFunction> aggregates = q.aggregates();
    System.assertEquals(2, aggregates.size(), 'Should have 2 aggregates');
  }

  @isTest
  static void test_grouped_field_in_select() {
    // Test grouped fields appear in SELECT
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.aggregates().add(Application.s.sum(Opportunity.Amount));
    q.groupBys().add(Application.s.path(Opportunity.StageName));
    q.groupBys().add(Application.s.path(Opportunity.Type));

    String soql = q.toSoql();
    System.assert(
      soql.contains('SELECT StageName, Type, SUM(Amount) Amount_sum'),
      'Grouped fields should be in SELECT with auto-alias'
    );
  }

  @isTest
  static void test_toSoql_with_binding() {
    // Test toSoql with binding parameter
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.aggregates().add(Application.s.count(Opportunity.Id));

    String soqlWithBinding = q.toSoql(true);
    String soqlWithoutBinding = q.toSoql(false);

    System.assertNotEquals(
      null,
      soqlWithBinding,
      'Should generate SOQL with binding'
    );
    System.assertNotEquals(
      null,
      soqlWithoutBinding,
      'Should generate SOQL without binding'
    );
  }

  @isTest
  static void test_combined_filters_and_having() {
    // Test both WHERE and HAVING clauses
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.aggregates().add(Application.s.sum(Opportunity.Amount));
    q.groupBys().add(Application.s.path(Opportunity.StageName));
    q.filters().add(Application.s.eq(Opportunity.Type, 'New Customer'));
    q.havingFilters()
      .add(Application.s.gt(Application.s.sum(Opportunity.Amount), 50000));

    String soql = q.toSoql();
    System.assert(soql.contains('WHERE'), 'Should contain WHERE');
    System.assert(soql.contains('HAVING'), 'Should contain HAVING');
    System.assert(
      soql.indexOf('WHERE') < soql.indexOf('GROUP BY'),
      'WHERE should come before GROUP BY'
    );
    System.assert(
      soql.indexOf('GROUP BY') < soql.indexOf('HAVING'),
      'GROUP BY should come before HAVING'
    );
  }

  @isTest
  static void test_no_group_by() {
    // Test aggregate without GROUP BY
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.aggregates().add(Application.s.sum(Opportunity.Amount));
    q.aggregates().add(Application.s.count(Opportunity.Id));

    String soql = q.toSoql();
    System.assert(
      soql.contains('SUM(Amount) Amount_sum'),
      'Should contain SUM with auto-alias'
    );
    System.assert(
      soql.contains('COUNT(Id) Id_cnt'),
      'Should contain COUNT with auto-alias'
    );
    System.assert(!soql.contains('GROUP BY'), 'Should not contain GROUP BY');
  }

  @isTest
  static void test_filters_getter() {
    // Test filters() getter
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.filters().add(Application.s.eq(Opportunity.StageName, 'Closed Won'));

    System.assertEquals(1, q.filters().getAll().size(), 'Should have 1 filter');
  }

  @isTest
  static void test_havingFilters_getter() {
    // Test havingFilters() getter
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.havingFilters()
      .add(Application.s.gt(Application.s.count(Opportunity.Id), 5));

    System.assertEquals(
      1,
      q.havingFilters().getAll().size(),
      'Should have 1 having filter'
    );
  }

  @isTest
  static void test_orderings_getter() {
    // Test orderings() getter
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.orderings()
      .add(
        Application.s.ordering(
          Application.s.sum(Opportunity.Amount),
          true,
          false
        )
      );

    System.assertEquals(1, q.orderings().size(), 'Should have 1 ordering');
  }

  @isTest
  static void test_rollup_multiple_grouping_indicators() {
    // Test automatic GROUPING() for multiple grouped fields with ROLLUP
    IAggregateQuery q = new AggregateQuery(
        Application.s.model(Opportunity.SObjectType)
      )
      .rollup();
    q.aggregates().add(Application.s.sum(Opportunity.Amount));
    q.groupBys().add(Application.s.path(Opportunity.Type));
    q.groupBys().add(Application.s.path(Opportunity.StageName));

    String soql = q.toSoql();
    System.assert(
      soql.contains('GROUPING(Type) Type_grp'),
      'Should auto-add GROUPING() for Type'
    );
    System.assert(
      soql.contains('GROUPING(StageName) StageName_grp'),
      'Should auto-add GROUPING() for StageName'
    );
    System.assert(
      soql.contains('GROUP BY ROLLUP(Type, StageName)'),
      'Should contain ROLLUP with wrapped fields'
    );
  }

  @isTest
  static void test_cube_multiple_grouping_indicators() {
    // Test automatic GROUPING() for multiple grouped fields with CUBE
    IAggregateQuery q = new AggregateQuery(
        Application.s.model(Opportunity.SObjectType)
      )
      .cube();
    q.aggregates().add(Application.s.sum(Opportunity.Amount));
    q.groupBys().add(Application.s.path(Opportunity.Type));
    q.groupBys().add(Application.s.path(Opportunity.StageName));

    String soql = q.toSoql();
    System.assert(
      soql.contains('GROUPING(Type) Type_grp'),
      'Should auto-add GROUPING() for Type'
    );
    System.assert(
      soql.contains('GROUPING(StageName) StageName_grp'),
      'Should auto-add GROUPING() for StageName'
    );
    System.assert(
      soql.contains('GROUP BY CUBE(Type, StageName)'),
      'Should contain CUBE with wrapped fields'
    );
  }

  @IsTest
  static void test_manual_alias_override() {
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );
    q.aggregates()
      .add(Application.s.sum(Opportunity.Amount).setAlias('total_revenue'));
    q.aggregates()
      .add(Application.s.count(Opportunity.Id).setAlias('deal_count'));

    String soql = q.toSoql();
    System.assert(
      soql.contains('SUM(Amount) total_revenue'),
      'Should use manual alias total_revenue'
    );
    System.assert(
      soql.contains('COUNT(Id) deal_count'),
      'Should use manual alias deal_count'
    );
  }

  @IsTest
  static void test_same_aggregate_different_aliases() {
    IAggregateQuery q = new AggregateQuery(
      Application.s.model(Opportunity.SObjectType)
    );

    // Add same aggregate function with different aliases
    q.aggregates().add(Application.s.sum(Opportunity.Amount).setAlias('total'));
    q.aggregates()
      .add(Application.s.sum(Opportunity.Amount).setAlias('revenue'));

    // Should be treated as different functions due to different aliases
    System.assertEquals(
      2,
      q.aggregates().size(),
      'Should have 2 distinct aggregates'
    );

    String soql = q.toSoql();
    System.assert(
      soql.contains('SUM(Amount) total'),
      'Should contain first alias'
    );
    System.assert(
      soql.contains('SUM(Amount) revenue'),
      'Should contain second alias'
    );
  }

  @IsTest
  static void test_aggregate_function_toString() {
    IAggregateFunction sumFunc = Application.s.sum(Opportunity.Amount);
    IAggregateFunction countFunc = Application.s.count(Opportunity.Id);
    IAggregateFunction countDistinctFunc = Application.s.countDistinct(
      Opportunity.AccountId
    );

    System.assertEquals(
      'SUM(Amount)',
      sumFunc.toString(),
      'toString should return SOQL'
    );
    System.assertEquals(
      'COUNT(Id)',
      countFunc.toString(),
      'toString should return SOQL'
    );
    System.assertEquals(
      'COUNT_DISTINCT(AccountId)',
      countDistinctFunc.toString(),
      'toString should return SOQL'
    );
  }

  @IsTest
  static void test_aggregate_function_getAlias() {
    IAggregateFunction autoAlias = Application.s.sum(Opportunity.Amount);
    IAggregateFunction manualAlias = Application.s.sum(Opportunity.Amount)
      .setAlias('custom');

    System.assertEquals(
      'Amount_sum',
      autoAlias.getAlias(),
      'Should auto-generate alias'
    );
    System.assertEquals(
      'custom',
      manualAlias.getAlias(),
      'Should return manual alias'
    );
  }

  @IsTest
  static void test_rollup_max_3_fields_validation() {
    IAggregateQuery q = new AggregateQuery(
        Application.s.model(Opportunity.SObjectType)
      )
      .rollup();
    q.aggregates().add(Application.s.sum(Opportunity.Amount));
    q.groupBys().add(Application.s.path(Opportunity.Type));
    q.groupBys().add(Application.s.path(Opportunity.StageName));
    q.groupBys().add(Application.s.path(Opportunity.ForecastCategory));
    q.groupBys().add(Application.s.path(Opportunity.LeadSource)); // 4th field

    try {
      String soql = q.toSoql();
      System.assert(
        false,
        'Should have thrown exception for 4 fields in ROLLUP'
      );
    } catch (AggregateQuery.AggregateException e) {
      System.assert(
        e.getMessage().contains('ROLLUP supports a maximum of 3 fields'),
        'Should have validation message'
      );
      System.assert(
        e.getMessage().contains('4 were provided'),
        'Should indicate 4 fields were provided'
      );
    }
  }

  @IsTest
  static void test_cube_max_3_fields_validation() {
    IAggregateQuery q = new AggregateQuery(
        Application.s.model(Opportunity.SObjectType)
      )
      .cube();
    q.aggregates().add(Application.s.sum(Opportunity.Amount));
    q.groupBys().add(Application.s.path(Opportunity.Type));
    q.groupBys().add(Application.s.path(Opportunity.StageName));
    q.groupBys().add(Application.s.path(Opportunity.ForecastCategory));
    q.groupBys().add(Application.s.path(Opportunity.LeadSource)); // 4th field

    try {
      String soql = q.toSoql();
      System.assert(false, 'Should have thrown exception for 4 fields in CUBE');
    } catch (AggregateQuery.AggregateException e) {
      System.assert(
        e.getMessage().contains('CUBE supports a maximum of 3 fields'),
        'Should have validation message'
      );
      System.assert(
        e.getMessage().contains('4 were provided'),
        'Should indicate 4 fields were provided'
      );
    }
  }

  @IsTest
  static void test_rollup_3_fields_allowed() {
    // Verify that exactly 3 fields is allowed
    IAggregateQuery q = new AggregateQuery(
        Application.s.model(Opportunity.SObjectType)
      )
      .rollup();
    q.aggregates().add(Application.s.sum(Opportunity.Amount));
    q.groupBys().add(Application.s.path(Opportunity.Type));
    q.groupBys().add(Application.s.path(Opportunity.StageName));
    q.groupBys().add(Application.s.path(Opportunity.ForecastCategory));

    String soql = q.toSoql();
    System.assert(
      soql.contains('GROUP BY ROLLUP(Type, StageName, ForecastCategory)'),
      'Should allow exactly 3 fields in ROLLUP'
    );
  }

  @IsTest
  static void conditionsBelongToTheQuerysOwnCore() {
    Core own = new Core(new SchemeDefault());
    IAggregateQuery q = own.model(Account.SObjectType).aggregateQuery();
    q.aggregates().add(own.count(Account.Id));
    q.filters().add(own.eq(Account.Name, 'Acme'));
    q.havingFilters().add(own.gt(own.count(Account.Id), 1));

    q.toSoql();

    Assert.isTrue(q.filters().source() === own.model(Account.SObjectType));
    Assert.isTrue(q.havingFilters().source() === own.model(Account.SObjectType));
  }

  @IsTest
  static void aRowCountWithoutAFieldRunsAlongsideGroups() {
    insert new List<Account>{
      new Account(Name = 'A1', Industry = 'Energy'),
      new Account(Name = 'A2', Industry = 'Energy'),
      new Account(Name = 'B1', Industry = 'Banking')
    };
    IAggregateQuery q = Application.s.model(Account.SObjectType).aggregateQuery();
    q.aggregates().add(Application.s.count(null));
    q.groupBys().add(Application.s.path(Account.Industry));
    q.havingFilters().add(Application.s.gt(Application.s.count(null), 1));

    List<AggregateResult> rows = q.run();

    Assert.areEqual('SELECT Industry, COUNT(Id) cnt FROM Account GROUP BY Industry HAVING (COUNT(Id) > 1)', q.toSoql());
    Assert.areEqual(1, rows.size(), 'only Energy has more than one account');
    Assert.areEqual('Energy', rows[0].get('Industry'));
    Assert.areEqual(2, rows[0].get('cnt'));
  }

  // --- semi-joins and anti-joins ----------------------------------------------------------------

  @IsTest
  static void aSemiJoinInWhereSharesTheBindsOfTheAggregateQuery() {
    MockScheme scheme = new MockScheme();
    Core mocked = new Core(scheme);
    IQuery innerQuery = QueryTest.contactsIn(mocked, 'Seattle');
    IAggregateQuery q = mocked.model(Account.SObjectType).aggregateQuery();
    q.aggregates().add(mocked.count(Account.Id));
    q.groupBys().add(mocked.path(Account.Industry));
    q.filters().add(mocked.eq(Account.Type, 'Customer'));
    q.filters().add(mocked.iin(Account.Id, innerQuery));
    q.havingFilters().add(mocked.gt(mocked.count(Account.Id), 0));

    Assert.areEqual(
      'SELECT Industry, COUNT(Id) Id_cnt FROM Account ' +
        'WHERE (Type = \'Customer\' AND Id IN (SELECT AccountId FROM Contact WHERE (MailingCity = \'Seattle\'))) ' +
        'GROUP BY Industry HAVING (COUNT(Id) > 0)',
      q.toSoql()
    );
    String bound =
      'SELECT Industry, COUNT(Id) Id_cnt FROM Account ' +
      'WHERE (Type = :a0 AND Id IN (SELECT AccountId FROM Contact WHERE (MailingCity = :a1))) ' +
      'GROUP BY Industry HAVING (COUNT(Id) > :a2)';
    Assert.areEqual(bound, q.toSoql(true));

    q.run();
    IAggregateQuery copy = q.deepClone();
    innerQuery.filters().add(mocked.eq(Contact.LastName, 'Smith'));

    Assert.areEqual(bound, scheme.queries()[0]);
    Assert.areEqual(new Map<String, Object>{ 'a0' => 'Customer', 'a1' => 'Seattle', 'a2' => 0 }, scheme.bindMaps()[0]);
    Assert.areEqual(bound, copy.toSoql(true), 'a copy has an inner query of its own');
    Assert.isTrue(q.toSoql().contains('Smith'), q.toSoql());
  }

  @IsTest
  static void aSemiJoinAndAnAntiJoinFilterTheRowsAnAggregateCounts() {
    Account energyWith = new Account(Name = 'E1', Industry = 'Energy');
    Account bankingWith = new Account(Name = 'B1', Industry = 'Banking');
    insert new List<Account>{
      energyWith,
      bankingWith,
      new Account(Name = 'E2', Industry = 'Energy'),
      new Account(Name = 'E3', Industry = 'Energy')
    };
    insert new List<Contact>{
      new Contact(LastName = 'North', AccountId = energyWith.Id, MailingCity = 'Seattle'),
      new Contact(LastName = 'South', AccountId = bankingWith.Id, MailingCity = 'Tacoma')
    };

    IAggregateQuery semi = Application.s.model(Account.SObjectType).aggregateQuery();
    semi.aggregates().add(Application.s.count(Account.Id));
    semi.groupBys().add(Application.s.path(Account.Industry));
    semi.filters().add(Application.s.iin(Account.Id, QueryTest.contactsIn(Application.s, 'Seattle')));
    List<AggregateResult> matched = semi.run();
    Assert.areEqual(1, matched.size());
    Assert.areEqual('Energy', matched[0].get('Industry'));
    Assert.areEqual(1, matched[0].get('Id_cnt'));

    IAggregateQuery anti = Application.s.model(Account.SObjectType).aggregateQuery();
    anti.aggregates().add(Application.s.count(Account.Id));
    anti.groupBys().add(Application.s.path(Account.Industry));
    anti.filters().add(Application.s.nin(Account.Id, QueryTest.contactsIn(Application.s, 'Seattle')));
    anti.orderings().add(Application.s.ordering(Account.Industry, true, false));
    List<AggregateResult> others = anti.run();
    Assert.areEqual(2, others.size());
    Assert.areEqual('Banking', others[0].get('Industry'));
    Assert.areEqual(1, others[0].get('Id_cnt'));
    Assert.areEqual('Energy', others[1].get('Industry'));
    Assert.areEqual(2, others[1].get('Id_cnt'));
  }

  @IsTest
  static void havingTakesNoSemiJoin() {
    IQuery owners = Application.s.model(User.SObjectType).query();
    IAggregateQuery q = Application.s.model(Account.SObjectType).aggregateQuery();
    q.aggregates().add(Application.s.count(Account.Id));
    q.groupBys().add(Application.s.path(Account.OwnerId));
    q.havingFilters().add(Application.s.iin(Account.OwnerId, owners));

    for (Boolean binding : new List<Boolean>{ false, true }) {
      try {
        q.toSoql(binding);
        Assert.fail('a semi-join was written into HAVING');
      } catch (Filtering.ConditionException refused) {
        Assert.areEqual('Cannot write a semi-join in HAVING: it belongs in filters()', refused.getMessage());
      }
    }
    try {
      q.run();
      Assert.fail('a semi-join in HAVING was run');
    } catch (Filtering.ConditionException refused) {
      Assert.areEqual('Cannot write a semi-join in HAVING: it belongs in filters()', refused.getMessage());
    }
    try {
      Application.s.iin(Application.s.count(Account.Id), owners);
      Assert.fail('an aggregate function was matched against a query');
    } catch (Filtering.ConditionException refused) {
      Assert.areEqual('Cannot match COUNT(Id) against a query: HAVING takes no semi-join', refused.getMessage());
    }
  }

  @IsTest
  static void allRowsAndAScopeAreWrittenAndCarriedByACopy() {
    IAggregateQuery q = Application.s.model(Account.SObjectType).aggregateQuery().setLimit(5).setOffset(1);
    q.aggregates().add(Application.s.count(Account.Id));
    q.groupBys().add(Application.s.path(Account.Industry));
    q.filters().add(Application.s.eq(Account.Type, 'Customer'));
    q.havingFilters().add(Application.s.gt(Application.s.count(Account.Id), 0));
    q.orderings().add(Application.s.ordering(Account.Industry, true, false));

    q.allRows(true).usingScope(Enums.FilterScope.MINE);
    String expected =
      'SELECT Industry, COUNT(Id) Id_cnt FROM Account USING SCOPE mine WHERE (Type = \'Customer\') GROUP BY Industry ' +
      'HAVING (COUNT(Id) > 0) ORDER BY Industry ASC NULLS FIRST LIMIT 5 OFFSET 1 ALL ROWS';
    Assert.areEqual(expected, q.toSoql());
    Assert.areEqual(expected, q.deepClone().toSoql(), 'a copy carries them');

    q.usingScope(Enums.FilterScope.SCOPING_RULE).allRows(null);
    Assert.isTrue(q.toSoql().contains('FROM Account USING SCOPE scopingRule WHERE'), q.toSoql());
    Assert.isFalse(q.toSoql().contains('ALL ROWS'), 'null is off');
    Assert.isFalse(q.usingScope(null).toSoql().contains('USING SCOPE'), 'null is none');
  }

  @IsTest
  static void allRowsCountsTheRecycleBinAndAScopeNarrowsTheCount() {
    Account kept = new Account(Name = 'Kept', Industry = 'Energy');
    Account binned = new Account(Name = 'Binned', Industry = 'Energy');
    insert new List<Account>{ kept, binned };
    delete binned;
    IAggregateQuery q = Application.s.model(Account.SObjectType).aggregateQuery();
    q.aggregates().add(Application.s.count(Account.Id));
    q.groupBys().add(Application.s.path(Account.Industry));

    Assert.areEqual(1, q.run()[0].get('Id_cnt'));
    Assert.areEqual(2, q.allRows(true).run()[0].get('Id_cnt'), 'the deleted account is counted');
    Assert.areEqual(2, q.usingScope(Enums.FilterScope.MINE).run()[0].get('Id_cnt'), 'the running user owns both');
    Assert.areEqual(2, q.usingScope(Enums.FilterScope.EVERYTHING).run()[0].get('Id_cnt'));
  }

  @IsTest
  static void aDateLiteralIsWrittenInWhereAndInHavingAndNeverBound() {
    Account acme = new Account(Name = 'Acme');
    insert acme;
    insert new List<Opportunity>{
      new Opportunity(Name = 'Soon', StageName = 'Prospecting', CloseDate = Date.today().addDays(3), AccountId = acme.Id, Amount = 10),
      new Opportunity(Name = 'Later', StageName = 'Qualification', CloseDate = Date.today().addDays(500), AccountId = acme.Id, Amount = 20),
      new Opportunity(Name = 'Long ago', StageName = 'Closed Lost', CloseDate = Date.today().addYears(-3), AccountId = acme.Id, Amount = 40)
    };
    IAggregateQuery q = Application.s.model(Opportunity.SObjectType).aggregateQuery();
    q.aggregates().add(Application.s.max(Opportunity.CloseDate));
    q.aggregates().add(Application.s.sum(Opportunity.Amount));
    q.groupBys().add(Application.s.path(Opportunity.StageName));
    q.filters().add(Application.s.ne(Opportunity.Name, 'Other'));
    q.filters().add(Application.s.ge(Opportunity.CloseDate, DateLiteral.lastNYears(1)));
    q.havingFilters().add(Application.s.le(Application.s.max(Opportunity.CloseDate), DateLiteral.nextNDays(30)));
    q.havingFilters().add(Application.s.gt(Application.s.sum(Opportunity.Amount), 1));

    Assert.areEqual(
      'SELECT StageName, MAX(CloseDate) CloseDate_max, SUM(Amount) Amount_sum FROM Opportunity ' +
        'WHERE (Name != :a0 AND CloseDate >= LAST_N_YEARS:1) GROUP BY StageName ' +
        'HAVING (MAX(CloseDate) <= NEXT_N_DAYS:30 AND SUM(Amount) > :a1)',
      q.toSoql(true)
    );
    Assert.isTrue(q.toSoql().contains('HAVING (MAX(CloseDate) <= NEXT_N_DAYS:30 AND SUM(Amount) > 1)'), q.toSoql());
    List<AggregateResult> groups = q.run();
    Assert.areEqual(1, groups.size(), 'one stage closes within thirty days; the old one was filtered out before grouping');
    Assert.areEqual('Prospecting', groups[0].get('StageName'));
    Assert.areEqual(10, groups[0].get('Amount_sum'));
  }

  @IsTest
  static void rowsAreGroupedByAPathThroughAPolymorphicLookup() {
    Account acme = new Account(Name = 'Acme');
    insert acme;
    insert new List<Task>{ new Task(Subject = 'one', WhatId = acme.Id), new Task(Subject = 'two', WhatId = acme.Id), new Task(Subject = 'none') };
    IAggregateQuery q = Application.s.model(Task.SObjectType).aggregateQuery();
    q.aggregates().add(Application.s.count(Task.Id));
    q.groupBys().add(Application.s.model(Task.SObjectType).path('What.Type'));
    q.filters().add(Application.s.ne('What.Type', null));

    Assert.areEqual('SELECT What.Type, COUNT(Id) Id_cnt FROM Task WHERE (What.Type != null) GROUP BY What.Type', q.toSoql());
    List<AggregateResult> groups = q.run();
    Assert.areEqual(1, groups.size());
    Assert.areEqual('Account', groups[0].get('Type'));
    Assert.areEqual(2, groups[0].get('Id_cnt'));
  }

  @IsTest
  static void aDateLiteralInHavingIsCheckedAsInWhere() {
    IAggregateQuery q = Application.s.model(Opportunity.SObjectType).aggregateQuery();
    q.aggregates().add(Application.s.max(Opportunity.CloseDate));
    q.groupBys().add(Application.s.path(Opportunity.StageName));
    ForeignLiteral foreign = new ForeignLiteral('next_n_days:30');
    q.havingFilters().add(Application.s.le(Application.s.max(Opportunity.CloseDate), foreign));

    Assert.isTrue(q.toSoql().endsWith('HAVING (MAX(CloseDate) <= NEXT_N_DAYS:30)'), 'a real literal is written as the framework writes it');
    Assert.areEqual(0, q.run().size());

    // Text of another class that is no date literal never reaches the SOQL, written or run
    foreign.text = 'TODAY OR MAX(CloseDate) != null';
    for (Boolean binding : new List<Boolean>{ false, true }) {
      try {
        q.toSoql(binding);
        Assert.fail('text that is no date literal was written into HAVING');
      } catch (IllegalArgumentException refused) {
        Assert.areEqual('Not a SOQL date literal: TODAY OR MAX(CloseDate) != null', refused.getMessage());
      }
    }
    try {
      q.run();
      Assert.fail('text that is no date literal was run in HAVING');
    } catch (IllegalArgumentException refused) {
      Assert.areEqual('Not a SOQL date literal: TODAY OR MAX(CloseDate) != null', refused.getMessage());
    }

    // HAVING compares with one value, so a list of literals is refused when the condition is built
    try {
      Application.s.eq(Application.s.max(Opportunity.CloseDate), new List<IDateLiteral>{ foreign });
      Assert.fail('a list of date literals was compared with an aggregate function');
    } catch (Filtering.ConditionException refused) {
      Assert.areEqual('Cannot compare MAX(CloseDate) with a list of date literals: HAVING takes one', refused.getMessage());
    }
  }

  @IsTest
  static void aDateAgainstTheLatestDateTimeIsWrittenAsMidnightGmt() {
    insert new Opportunity(Name = 'Now', StageName = 'Prospecting', CloseDate = Date.today());
    Date longAgo = Date.newInstance(2020, 1, 15);
    Map<Object, String> writtenByField = new Map<Object, String>{
      Opportunity.CreatedDate => 'MAX(CreatedDate) > 2020-01-15T00:00:00.000Z',
      'CreatedDate' => 'MAX(CreatedDate) > 2020-01-15T00:00:00.000Z',
      Application.s.path(Opportunity.CreatedDate) => 'MAX(CreatedDate) > 2020-01-15T00:00:00.000Z',
      Opportunity.CloseDate => 'MAX(CloseDate) > 2020-01-15'
    };

    for (Object field : writtenByField.keySet()) {
      IAggregateQuery q = Application.s.model(Opportunity.SObjectType).aggregateQuery();
      q.aggregates().add(Application.s.count(Opportunity.Id));
      q.groupBys().add(Application.s.path(Opportunity.StageName));
      q.havingFilters().add(Application.s.gt(Application.s.max(field), longAgo));

      Assert.isTrue(q.toSoql().endsWith('HAVING (' + writtenByField.get(field) + ')'), q.toSoql());
      Assert.areEqual(1, Database.query(q.toSoql()).size(), 'the platform takes what is written: ' + q.toSoql());
      Assert.areEqual(1, q.run().size(), 'and the bound date gives the same groups');
    }
  }

  @IsTest
  static void groupsWithNothingInThemAreConstantsInWhereAndInHaving() {
    insert new List<Account>{ new Account(Name = 'A', Industry = 'Energy'), new Account(Name = 'B', Industry = 'Retail') };
    IAggregateQuery q = Application.s.model(Account.SObjectType).aggregateQuery();
    q.aggregates().add(Application.s.count(Account.Id));
    q.groupBys().add(Application.s.path(Account.Industry));
    q.filters().add(Application.s.all(new List<ICondition>()));
    q.havingFilters().add(Application.s.any(new List<ICondition>()));
    String never =
      'SELECT Industry, COUNT(Id) Id_cnt FROM Account WHERE ((Id = null OR Id != null)) GROUP BY Industry ' +
      'HAVING ((COUNT(Id) = null AND COUNT(Id) != null))';

    Assert.areEqual(never, q.toSoql(), 'HAVING takes no bare field, so its constant is written on COUNT(Id)');
    Assert.areEqual(never, q.toSoql(true));
    Assert.areEqual(0, q.run().size(), 'an empty OR in HAVING keeps no group');

    q.havingFilters().clear().add(Application.s.all(new List<ICondition>()));
    Assert.isTrue(q.toSoql().endsWith('HAVING ((COUNT(Id) = null OR COUNT(Id) != null))'), q.toSoql());
    Assert.areEqual(2, q.run().size(), 'an empty AND keeps them all');

    q.filters().clear().add(Application.s.any(new List<ICondition>()));
    Assert.areEqual(0, q.run().size(), 'an empty OR in WHERE keeps no row');

    IAggregateQuery untouched = Application.s.model(Account.SObjectType).aggregateQuery();
    untouched.aggregates().add(Application.s.count(Account.Id));
    Assert.areEqual('SELECT COUNT(Id) Id_cnt FROM Account', untouched.toSoql(), 'the roots themselves, when empty, write no clause');
  }

  @IsTest
  static void anAggregateIsNotOrderedAgainstNull() {
    IAggregateQuery q = Application.s.model(Opportunity.SObjectType).aggregateQuery();
    q.aggregates().add(Application.s.sum(Opportunity.Amount));
    q.groupBys().add(Application.s.path(Opportunity.StageName));
    q.havingFilters().add(Application.s.gt(Application.s.sum(Opportunity.Amount), null));

    for (Boolean binding : new List<Boolean>{ false, true }) {
      try {
        q.toSoql(binding);
        Assert.fail('an aggregate was ordered against null');
      } catch (Filtering.ConditionException refused) {
        Assert.areEqual('Cannot compare SUM(Amount) with null by GT: null goes with EQ and NE', refused.getMessage());
      }
    }
    q.havingFilters().clear().add(Application.s.ne(Application.s.sum(Opportunity.Amount), null));
    Assert.isTrue(q.toSoql().endsWith('HAVING (SUM(Amount) != null)'), q.toSoql());
    Assert.areEqual(0, q.run().size());
  }

  private class ForeignLiteral implements IDateLiteral {
    private String text;

    private ForeignLiteral(String text) {
      this.text = text;
    }

    public String toSoql() {
      return text;
    }
  }
}
