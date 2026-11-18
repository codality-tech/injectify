/** ICore.aggregate(): an aggregate function chosen at run time. */
@IsTest
private class CoreAggregateTest {
  @IsTest
  static void everyFunctionIsTheOneItsOwnMethodMakes() {
    ICore core = Application.s;
    Map<Enums.Aggregate, IAggregateFunction> expected = new Map<Enums.Aggregate, IAggregateFunction>{
      Enums.Aggregate.COUNT => core.count(Opportunity.Amount),
      Enums.Aggregate.COUNT_DISTINCT => core.countDistinct(Opportunity.Amount),
      Enums.Aggregate.SUM => core.sum(Opportunity.Amount),
      Enums.Aggregate.AVG => core.avg(Opportunity.Amount),
      Enums.Aggregate.MIN => core.min(Opportunity.Amount),
      Enums.Aggregate.MAX => core.max(Opportunity.Amount)
    };

    Assert.areEqual(Enums.Aggregate.values().size(), expected.size(), 'every value of the enum is covered');
    for (Enums.Aggregate function : Enums.Aggregate.values()) {
      IAggregateFunction made = core.aggregate(function, Opportunity.Amount);
      Assert.areEqual(expected.get(function).toSoql(), made.toSoql());
      Assert.areEqual(expected.get(function).getAlias(), made.getAlias());
      Assert.areEqual(function.name(), made.functionName());
    }
  }

  @IsTest
  static void aCountNeedsNoField() {
    Assert.areEqual('COUNT(Id)', Application.s.aggregate(Enums.Aggregate.COUNT, null).toSoql());
  }

  @IsTest
  static void itGoesIntoAnAggregateQuery() {
    IAggregateQuery totals = Application.s.model(Opportunity.SObjectType).aggregateQuery();
    totals.aggregates().add(Application.s.aggregate(Enums.Aggregate.SUM, Opportunity.Amount));
    totals.groupBys().add(Application.s.path(Opportunity.StageName));

    Assert.areEqual('SELECT StageName, SUM(Amount) Amount_sum FROM Opportunity GROUP BY StageName', totals.toSoql());
  }

  @IsTest
  static void aNullFunctionIsRefused() {
    try {
      Application.s.aggregate(null, Opportunity.Amount);
      Assert.fail('A null function was accepted');
    } catch (IllegalArgumentException refused) {
      Assert.areEqual('An aggregate function is required', refused.getMessage());
    }
  }
}
