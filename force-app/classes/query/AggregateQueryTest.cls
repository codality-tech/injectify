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
      soql.contains('WITH SECURITY_ENFORCED'),
      'Should contain security enforcement'
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
}
