/**
 * Date literals: what they write, what they refuse, the days they cover, and that conditions
 * built on them give the same answer in memory as the database gives for inserted records.
 */
@IsTest
private class DateLiteralTest {
  private static final String MARK = 'date-literal-test';
  private static final List<Enums.Comparator> COMPARATORS = new List<Enums.Comparator>{
    Enums.Comparator.EQ,
    Enums.Comparator.NE,
    Enums.Comparator.LT,
    Enums.Comparator.LE,
    Enums.Comparator.GT,
    Enums.Comparator.GE
  };

  // What they write

  @IsTest
  static void everyLiteralOfTheSoqlReferenceHasAFactory() {
    Map<String, IDateLiteral> made = new Map<String, IDateLiteral>{
      'YESTERDAY' => DateLiteral.yesterday(),
      'TODAY' => DateLiteral.today(),
      'TOMORROW' => DateLiteral.tomorrow(),
      'LAST_90_DAYS' => DateLiteral.last90Days(),
      'NEXT_90_DAYS' => DateLiteral.next90Days(),
      'LAST_N_DAYS:1' => DateLiteral.lastNDays(1),
      'NEXT_N_DAYS:2' => DateLiteral.nextNDays(2),
      'N_DAYS_AGO:3' => DateLiteral.nDaysAgo(3),
      'LAST_WEEK' => DateLiteral.lastWeek(),
      'THIS_WEEK' => DateLiteral.thisWeek(),
      'NEXT_WEEK' => DateLiteral.nextWeek(),
      'LAST_N_WEEKS:4' => DateLiteral.lastNWeeks(4),
      'NEXT_N_WEEKS:5' => DateLiteral.nextNWeeks(5),
      'N_WEEKS_AGO:6' => DateLiteral.nWeeksAgo(6),
      'LAST_MONTH' => DateLiteral.lastMonth(),
      'THIS_MONTH' => DateLiteral.thisMonth(),
      'NEXT_MONTH' => DateLiteral.nextMonth(),
      'LAST_N_MONTHS:7' => DateLiteral.lastNMonths(7),
      'NEXT_N_MONTHS:8' => DateLiteral.nextNMonths(8),
      'N_MONTHS_AGO:9' => DateLiteral.nMonthsAgo(9),
      'LAST_QUARTER' => DateLiteral.lastQuarter(),
      'THIS_QUARTER' => DateLiteral.thisQuarter(),
      'NEXT_QUARTER' => DateLiteral.nextQuarter(),
      'LAST_N_QUARTERS:10' => DateLiteral.lastNQuarters(10),
      'NEXT_N_QUARTERS:11' => DateLiteral.nextNQuarters(11),
      'N_QUARTERS_AGO:12' => DateLiteral.nQuartersAgo(12),
      'LAST_YEAR' => DateLiteral.lastYear(),
      'THIS_YEAR' => DateLiteral.thisYear(),
      'NEXT_YEAR' => DateLiteral.nextYear(),
      'LAST_N_YEARS:13' => DateLiteral.lastNYears(13),
      'NEXT_N_YEARS:14' => DateLiteral.nextNYears(14),
      'N_YEARS_AGO:15' => DateLiteral.nYearsAgo(15),
      'LAST_FISCAL_QUARTER' => DateLiteral.lastFiscalQuarter(),
      'THIS_FISCAL_QUARTER' => DateLiteral.thisFiscalQuarter(),
      'NEXT_FISCAL_QUARTER' => DateLiteral.nextFiscalQuarter(),
      'LAST_N_FISCAL_QUARTERS:16' => DateLiteral.lastNFiscalQuarters(16),
      'NEXT_N_FISCAL_QUARTERS:17' => DateLiteral.nextNFiscalQuarters(17),
      'N_FISCAL_QUARTERS_AGO:18' => DateLiteral.nFiscalQuartersAgo(18),
      'LAST_FISCAL_YEAR' => DateLiteral.lastFiscalYear(),
      'THIS_FISCAL_YEAR' => DateLiteral.thisFiscalYear(),
      'NEXT_FISCAL_YEAR' => DateLiteral.nextFiscalYear(),
      'LAST_N_FISCAL_YEARS:19' => DateLiteral.lastNFiscalYears(19),
      'NEXT_N_FISCAL_YEARS:20' => DateLiteral.nextNFiscalYears(20),
      'N_FISCAL_YEARS_AGO:0' => DateLiteral.nFiscalYearsAgo(0)
    };

    Set<String> keywords = new Set<String>();
    for (String written : made.keySet()) {
      Assert.areEqual(written, made.get(written).toSoql());
      Assert.areEqual(written, String.valueOf(made.get(written)), 'a literal prints as its SOQL');
      Assert.areEqual(made.get(written), DateLiteral.of(written), 'of() makes the same literal');
      keywords.add(written.substringBefore(':'));
    }
    Assert.areEqual(44, made.size());
    Assert.areEqual(DateLiteral.keywords(), keywords, 'a factory for every keyword, and no other');
  }

  @IsTest
  static void ofReadsTheTextInAnyCaseAndWithSpacesAroundTheColon() {
    Assert.areEqual('TODAY', DateLiteral.of(' today ').toSoql());
    Assert.areEqual('LAST_N_DAYS:30', DateLiteral.of('last_n_days : 30').toSoql());
    Assert.areEqual('NEXT_N_FISCAL_QUARTERS:2', DateLiteral.of('Next_N_Fiscal_Quarters:002').toSoql());
    Assert.areEqual(DateLiteral.lastNDays(30).hashCode(), DateLiteral.of('LAST_N_DAYS:30').hashCode());
    Assert.areNotEqual(DateLiteral.lastNDays(30), DateLiteral.lastNDays(31));
    Assert.isTrue(DateLiteral.isLiteralText('THIS_WEEK'));
    Assert.isFalse(DateLiteral.isLiteralText('THIS_WEEK:1'));
    Assert.isFalse(DateLiteral.isLiteralText('Name'));
    Assert.isFalse(DateLiteral.isLiteralText(null));
  }

  @IsTest
  static void ofRefusesWhatIsNotADateLiteral() {
    Map<String, String> refusals = new Map<String, String>{
      'NOW' => 'Not a SOQL date literal: NOW',
      'LAST_N_HOURS:2' => 'Not a SOQL date literal: LAST_N_HOURS:2',
      'LAST_N_DAYS:-1' => 'Not a SOQL date literal: LAST_N_DAYS:-1',
      'LAST_N_DAYS:1.5' => 'Not a SOQL date literal: LAST_N_DAYS:1.5',
      '' => 'Not a SOQL date literal: ',
      'LAST_N_DAYS' => 'LAST_N_DAYS needs a number, as in LAST_N_DAYS:7, not LAST_N_DAYS',
      'TODAY:3' => 'TODAY takes no number: TODAY:3',
      'LAST_90_DAYS:2' => 'LAST_90_DAYS takes no number: LAST_90_DAYS:2',
      'LAST_N_DAYS:12345678901' => 'The number in LAST_N_DAYS:12345678901 is too large'
    };
    for (String text : refusals.keySet()) {
      try {
        DateLiteral.of(text);
        Assert.fail('accepted ' + text);
      } catch (IllegalArgumentException refused) {
        Assert.areEqual(refusals.get(text), refused.getMessage());
      }
    }
    try {
      DateLiteral.of(null);
      Assert.fail('accepted null');
    } catch (IllegalArgumentException refused) {
      Assert.areEqual('Not a SOQL date literal: null', refused.getMessage());
    }
  }

  @IsTest
  static void aCountIsZeroOrMore() {
    Assert.areEqual('N_DAYS_AGO:0', DateLiteral.nDaysAgo(0).toSoql());
    for (Integer bad : new List<Integer>{ -1, null }) {
      try {
        DateLiteral.lastNWeeks(bad);
        Assert.fail('accepted ' + bad);
      } catch (IllegalArgumentException refused) {
        Assert.areEqual('LAST_N_WEEKS needs a number that is zero or more, not ' + bad, refused.getMessage());
      }
    }
  }

  @IsTest
  static void aLiteralOfAnotherClassIsReadFromItsSoql() {
    DateLiteral.Value read = DateLiteral.checked(new ForeignLiteral('n_days_ago:2'));

    Assert.areEqual('N_DAYS_AGO:2', read.toSoql());
    Assert.isFalse(read.isFiscal());
    Assert.isTrue(DateLiteral.checked(DateLiteral.thisFiscalYear()).isFiscal());
    Assert.isTrue(DateLiteral.isLiteral(new ForeignLiteral('TODAY')));
    Assert.isTrue(DateLiteral.isLiteral(new List<IDateLiteral>()));
    Assert.isFalse(DateLiteral.isLiteral('TODAY'), 'text is a value, not a literal');
    try {
      DateLiteral.checked(null);
      Assert.fail('accepted null');
    } catch (IllegalArgumentException refused) {
      Assert.areEqual('A date literal is required', refused.getMessage());
    }
  }

  // The days they cover, worked out for a fixed day

  @IsTest
  static void dayLiteralsCoverWholeDaysAroundToday() {
    DateLiteral.fixedToday = Date.newInstance(2028, 2, 29); // a leap day

    assertSpan(DateLiteral.yesterday(), Date.newInstance(2028, 2, 28), Date.newInstance(2028, 2, 29));
    assertSpan(DateLiteral.today(), Date.newInstance(2028, 2, 29), Date.newInstance(2028, 3, 1));
    assertSpan(DateLiteral.tomorrow(), Date.newInstance(2028, 3, 1), Date.newInstance(2028, 3, 2));
    assertSpan(DateLiteral.lastNDays(1), Date.newInstance(2028, 2, 28), Date.newInstance(2028, 3, 1));
    assertSpan(DateLiteral.lastNDays(0), Date.newInstance(2028, 2, 29), Date.newInstance(2028, 3, 1));
    assertSpan(DateLiteral.nextNDays(2), Date.newInstance(2028, 3, 1), Date.newInstance(2028, 3, 3));
    assertSpan(DateLiteral.nextNDays(0), Date.newInstance(2028, 3, 1), Date.newInstance(2028, 3, 1));
    assertSpan(DateLiteral.nDaysAgo(29), Date.newInstance(2028, 1, 31), Date.newInstance(2028, 2, 1));
    assertSpan(DateLiteral.last90Days(), Date.newInstance(2027, 12, 1), Date.newInstance(2028, 3, 1));
    assertSpan(DateLiteral.next90Days(), Date.newInstance(2028, 3, 1), Date.newInstance(2028, 5, 30));
  }

  @IsTest
  static void weekLiteralsStartOnTheFirstDayOfTheUsersWeek() {
    DateLiteral.fixedToday = Date.newInstance(2027, 12, 31); // a Friday

    // In the United States the week starts on Sunday
    System.runAs(userIn('GMT', 'en_US')) {
      assertSpan(DateLiteral.thisWeek(), Date.newInstance(2027, 12, 26), Date.newInstance(2028, 1, 2));
      assertSpan(DateLiteral.lastWeek(), Date.newInstance(2027, 12, 19), Date.newInstance(2027, 12, 26));
      assertSpan(DateLiteral.nextWeek(), Date.newInstance(2028, 1, 2), Date.newInstance(2028, 1, 9));
      assertSpan(DateLiteral.lastNWeeks(2), Date.newInstance(2027, 12, 12), Date.newInstance(2027, 12, 26));
      assertSpan(DateLiteral.nextNWeeks(2), Date.newInstance(2028, 1, 2), Date.newInstance(2028, 1, 16));
      assertSpan(DateLiteral.nWeeksAgo(2), Date.newInstance(2027, 12, 12), Date.newInstance(2027, 12, 19));
      assertSpan(DateLiteral.lastNWeeks(0), Date.newInstance(2027, 12, 26), Date.newInstance(2027, 12, 26));
    }
    // In the United Kingdom, on Monday
    System.runAs(userIn('GMT', 'en_GB')) {
      assertSpan(DateLiteral.thisWeek(), Date.newInstance(2027, 12, 27), Date.newInstance(2028, 1, 3));
      assertSpan(DateLiteral.lastNWeeks(2), Date.newInstance(2027, 12, 13), Date.newInstance(2027, 12, 27));
      assertSpan(DateLiteral.nextWeek(), Date.newInstance(2028, 1, 3), Date.newInstance(2028, 1, 10));
    }
  }

  @IsTest
  static void monthQuarterAndYearLiteralsFollowTheCalendar() {
    DateLiteral.fixedToday = Date.newInstance(2027, 12, 31); // the last day of a month, quarter and year

    assertSpan(DateLiteral.thisMonth(), Date.newInstance(2027, 12, 1), Date.newInstance(2028, 1, 1));
    assertSpan(DateLiteral.lastMonth(), Date.newInstance(2027, 11, 1), Date.newInstance(2027, 12, 1));
    assertSpan(DateLiteral.nextMonth(), Date.newInstance(2028, 1, 1), Date.newInstance(2028, 2, 1));
    assertSpan(DateLiteral.lastNMonths(12), Date.newInstance(2026, 12, 1), Date.newInstance(2027, 12, 1));
    assertSpan(DateLiteral.nextNMonths(2), Date.newInstance(2028, 1, 1), Date.newInstance(2028, 3, 1));
    assertSpan(DateLiteral.nMonthsAgo(10), Date.newInstance(2027, 2, 1), Date.newInstance(2027, 3, 1));

    assertSpan(DateLiteral.thisQuarter(), Date.newInstance(2027, 10, 1), Date.newInstance(2028, 1, 1));
    assertSpan(DateLiteral.lastQuarter(), Date.newInstance(2027, 7, 1), Date.newInstance(2027, 10, 1));
    assertSpan(DateLiteral.nextQuarter(), Date.newInstance(2028, 1, 1), Date.newInstance(2028, 4, 1));
    assertSpan(DateLiteral.lastNQuarters(2), Date.newInstance(2027, 4, 1), Date.newInstance(2027, 10, 1));
    assertSpan(DateLiteral.nextNQuarters(2), Date.newInstance(2028, 1, 1), Date.newInstance(2028, 7, 1));
    assertSpan(DateLiteral.nQuartersAgo(4), Date.newInstance(2026, 10, 1), Date.newInstance(2027, 1, 1));

    assertSpan(DateLiteral.thisYear(), Date.newInstance(2027, 1, 1), Date.newInstance(2028, 1, 1));
    assertSpan(DateLiteral.lastYear(), Date.newInstance(2026, 1, 1), Date.newInstance(2027, 1, 1));
    assertSpan(DateLiteral.nextYear(), Date.newInstance(2028, 1, 1), Date.newInstance(2029, 1, 1));
    assertSpan(DateLiteral.lastNYears(5), Date.newInstance(2022, 1, 1), Date.newInstance(2027, 1, 1));
    assertSpan(DateLiteral.nextNYears(5), Date.newInstance(2028, 1, 1), Date.newInstance(2033, 1, 1));
    assertSpan(DateLiteral.nYearsAgo(2), Date.newInstance(2025, 1, 1), Date.newInstance(2026, 1, 1));

    DateLiteral.fixedToday = Date.newInstance(2028, 1, 1); // and the first day of all three
    assertSpan(DateLiteral.thisMonth(), Date.newInstance(2028, 1, 1), Date.newInstance(2028, 2, 1));
    assertSpan(DateLiteral.thisQuarter(), Date.newInstance(2028, 1, 1), Date.newInstance(2028, 4, 1));
    assertSpan(DateLiteral.lastQuarter(), Date.newInstance(2027, 10, 1), Date.newInstance(2028, 1, 1));
    assertSpan(DateLiteral.thisYear(), Date.newInstance(2028, 1, 1), Date.newInstance(2029, 1, 1));
    assertSpan(DateLiteral.lastMonth(), Date.newInstance(2027, 12, 1), Date.newInstance(2028, 1, 1));
  }

  @IsTest
  static void fiscalLiteralsFollowAStandardFiscalYearFromItsStartMonth() {
    DateLiteral.fiscalStartMonth = 2; // a fiscal year from February to January
    DateLiteral.fixedToday = Date.newInstance(2028, 1, 31); // its last day

    assertSpan(DateLiteral.thisFiscalYear(), Date.newInstance(2027, 2, 1), Date.newInstance(2028, 2, 1));
    assertSpan(DateLiteral.lastFiscalYear(), Date.newInstance(2026, 2, 1), Date.newInstance(2027, 2, 1));
    assertSpan(DateLiteral.nextFiscalYear(), Date.newInstance(2028, 2, 1), Date.newInstance(2029, 2, 1));
    assertSpan(DateLiteral.lastNFiscalYears(2), Date.newInstance(2025, 2, 1), Date.newInstance(2027, 2, 1));
    assertSpan(DateLiteral.nextNFiscalYears(2), Date.newInstance(2028, 2, 1), Date.newInstance(2030, 2, 1));
    assertSpan(DateLiteral.nFiscalYearsAgo(1), Date.newInstance(2026, 2, 1), Date.newInstance(2027, 2, 1));

    assertSpan(DateLiteral.thisFiscalQuarter(), Date.newInstance(2027, 11, 1), Date.newInstance(2028, 2, 1));
    assertSpan(DateLiteral.lastFiscalQuarter(), Date.newInstance(2027, 8, 1), Date.newInstance(2027, 11, 1));
    assertSpan(DateLiteral.nextFiscalQuarter(), Date.newInstance(2028, 2, 1), Date.newInstance(2028, 5, 1));
    assertSpan(DateLiteral.lastNFiscalQuarters(4), Date.newInstance(2026, 11, 1), Date.newInstance(2027, 11, 1));
    assertSpan(DateLiteral.nextNFiscalQuarters(2), Date.newInstance(2028, 2, 1), Date.newInstance(2028, 8, 1));
    assertSpan(DateLiteral.nFiscalQuartersAgo(3), Date.newInstance(2027, 2, 1), Date.newInstance(2027, 5, 1));

    DateLiteral.fixedToday = Date.newInstance(2028, 2, 1); // the first day of the next one
    assertSpan(DateLiteral.thisFiscalYear(), Date.newInstance(2028, 2, 1), Date.newInstance(2029, 2, 1));
    assertSpan(DateLiteral.thisFiscalQuarter(), Date.newInstance(2028, 2, 1), Date.newInstance(2028, 5, 1));

    DateLiteral.fiscalStartMonth = 1; // a fiscal year that is the calendar year
    DateLiteral.fixedToday = Date.newInstance(2027, 5, 15);
    assertSpan(DateLiteral.thisFiscalYear(), Date.newInstance(2027, 1, 1), Date.newInstance(2028, 1, 1));
    assertSpan(DateLiteral.thisFiscalQuarter(), Date.newInstance(2027, 4, 1), Date.newInstance(2027, 7, 1));
  }

  @IsTest
  static void theFiscalYearIsAskedOfTheSchemeOncePerTransaction() {
    DateLiteral.fixedToday = Date.newInstance(2027, 5, 15);
    Organization fromMarch = (Organization) JSON.deserialize(
      '{"attributes":{"type":"Organization"},"FiscalYearStartMonth":3}',
      Organization.class
    );
    MockScheme scheme = new MockScheme().returning(Organization.SObjectType, new List<SObject>{ fromMarch });
    ICondition thisFiscalQuarter = new Core(scheme).eq(Opportunity.CloseDate, DateLiteral.thisFiscalQuarter());

    Assert.isTrue(thisFiscalQuarter.evaluate(new Opportunity(CloseDate = Date.newInstance(2027, 3, 1))));
    Assert.isFalse(thisFiscalQuarter.evaluate(new Opportunity(CloseDate = Date.newInstance(2027, 6, 1))));
    Assert.areEqual(Date.newInstance(2027, 3, 1), DateLiteral.checked(DateLiteral.thisFiscalYear()).firstDay(scheme));
    Assert.areEqual(
      new List<String>{
        'SELECT COUNT() FROM FiscalYearSettings WHERE IsStandardYear = false LIMIT 1',
        'SELECT FiscalYearStartMonth FROM Organization LIMIT 1'
      },
      scheme.queries(),
      'one query for custom fiscal years, one for the start month, and none after that'
    );
  }

  @IsTest
  static void customFiscalYearsAreToldFromTheSchemesAnswer() {
    MockScheme scheme = new MockScheme().returning(FiscalYearSettings.SObjectType, new List<SObject>{ new FiscalYearSettings() });
    ICondition thisFiscalYear = new Core(scheme).eq(Opportunity.CloseDate, DateLiteral.thisFiscalYear());

    for (Integer attempt = 0; attempt < 2; attempt++) {
      try {
        thisFiscalYear.evaluate(new Opportunity(CloseDate = Date.newInstance(2027, 5, 15)));
        Assert.fail('a custom fiscal year was worked out from a start month');
      } catch (Filtering.ConditionException refused) {
        Assert.areEqual('Cannot evaluate a fiscal date literal in memory: the organization has custom fiscal years', refused.getMessage());
      }
    }
    Assert.areEqual(1, scheme.queries().size(), 'asked once: the start month is never read');
  }

  @IsTest
  static void aSchemeThatReturnsNoOrganizationGivesNoFiscalYear() {
    try {
      new Core(new MockScheme()).eq(Opportunity.CloseDate, DateLiteral.thisFiscalYear()).evaluate(new Opportunity());
      Assert.fail('a fiscal year was worked out without a start month');
    } catch (Filtering.ConditionException refused) {
      Assert.areEqual('Cannot evaluate a fiscal date literal in memory: no Organization row gives the start month', refused.getMessage());
    }
  }

  @IsTest
  static void theOrganizationsOwnFiscalYearIsReadThroughTheDefaultScheme() {
    Integer startMonth = [SELECT FiscalYearStartMonth FROM Organization LIMIT 1].FiscalYearStartMonth;
    Boolean custom = hasCustomFiscalYears();
    Integer before = Limits.getQueries();
    DateLiteral.Value thisFiscalYear = DateLiteral.checked(DateLiteral.thisFiscalYear());

    if (custom) {
      assertRefusedForCustomFiscalYears(new List<IDateLiteral>{ thisFiscalYear });
    } else {
      Assert.areEqual(startMonth, thisFiscalYear.firstDay(null).month());
      Assert.areEqual(1, thisFiscalYear.firstDay(null).day());
      Assert.areEqual(2, Limits.getQueries() - before, 'two queries, however often it is asked');
    }
  }

  @IsTest
  static void customFiscalYearsAreNotWorkedOutInMemory() {
    DateLiteral.customFiscalYears = true; // as in an organization that has them
    DateLiteral.fixedToday = Date.newInstance(2027, 6, 16);
    ICondition thisFiscalYear = Application.s.eq(Opportunity.CloseDate, DateLiteral.thisFiscalYear());

    Assert.areEqual('CloseDate = THIS_FISCAL_YEAR', thisFiscalYear.toSoql(), 'a query still takes it');
    try {
      thisFiscalYear.evaluate(new Opportunity(CloseDate = Date.newInstance(2027, 6, 16)));
      Assert.fail('a custom fiscal year was worked out from a start month');
    } catch (Filtering.ConditionException refused) {
      Assert.areEqual(
        'Cannot evaluate a fiscal date literal in memory: the organization has custom fiscal years',
        refused.getMessage()
      );
    }
    Assert.isTrue(
      Application.s.eq(Opportunity.CloseDate, DateLiteral.thisYear()).evaluate(new Opportunity(CloseDate = Date.newInstance(2027, 6, 16))),
      'calendar literals are not affected'
    );
  }

  @IsTest
  static void customFiscalYearsOnceKnownCostNoQuery() {
    DateLiteral.customFiscalYears = true; // as in an organization that has them
    DateLiteral.Value thisFiscalYear = DateLiteral.checked(DateLiteral.thisFiscalYear());
    Integer before = Limits.getQueries();

    for (Integer attempt = 0; attempt < 3; attempt++) {
      try {
        thisFiscalYear.firstDay(null);
        Assert.fail('a custom fiscal year was worked out from a start month');
      } catch (Filtering.ConditionException refused) {
        Assert.isTrue(refused.getMessage().contains('custom fiscal years'), refused.getMessage());
      }
    }

    Assert.areEqual(before, Limits.getQueries(), 'the answer is known, so nothing is asked again');
  }

  @IsTest
  static void aCountThePlatformRefusesIsRefusedInMemory() {
    DateLiteral.fixedToday = Date.newInstance(2027, 6, 16);
    DateLiteral.fiscalStartMonth = 1;
    Task dated = new Task(ActivityDate = Date.newInstance(2027, 6, 16));
    List<String> counted = new List<String>{
      'LAST_N_DAYS',
      'NEXT_N_WEEKS',
      'N_MONTHS_AGO',
      'LAST_N_QUARTERS',
      'NEXT_N_YEARS',
      'N_FISCAL_QUARTERS_AGO',
      'LAST_N_FISCAL_YEARS'
    };

    for (String keyword : counted) {
      for (Integer tooMany : new List<Integer>{ 365001, 999999999 }) {
        String text = keyword + ':' + tooMany;
        IDateLiteral literal = DateLiteral.of(text);
        Assert.areEqual(text, literal.toSoql(), 'it is still written: the platform answers for itself');
        for (Task row : new List<Task>{ dated, new Task() }) {
          try {
            Application.s.ne(Task.ActivityDate, literal).evaluate(row);
            Assert.fail('a date was worked out for ' + text);
          } catch (Filtering.ConditionException refused) {
            Assert.areEqual('Cannot evaluate ' + text + ' in memory: the count is over 365000', refused.getMessage());
          }
        }
      }
    }

    // The largest count the platform takes is worked out
    assertSpan(DateLiteral.lastNDays(365000), Date.newInstance(2027, 6, 16).addDays(-365000), Date.newInstance(2027, 6, 17));
    Assert.isTrue(Application.s.gt(Task.ActivityDate, DateLiteral.nWeeksAgo(365000)).evaluate(dated));
    Assert.isTrue(Application.s.gt(Task.ActivityDate, DateLiteral.nFiscalYearsAgo(365000)).evaluate(dated));
    Assert.isTrue(Application.s.lt(Task.ActivityDate, DateLiteral.nextNWeeks(365000)).evaluate(dated));
  }

  @IsTest
  static void thePlatformTakesACountUpTo365000() {
    List<Task> rows = aroundEachDay(-1, 1);
    for (String keyword : new List<String>{ 'LAST_N_DAYS', 'NEXT_N_WEEKS', 'N_MONTHS_AGO', 'NEXT_N_FISCAL_YEARS' }) {
      try {
        Database.query('SELECT Id FROM Task WHERE ActivityDate = ' + keyword + ':365001');
        Assert.fail('the platform took ' + keyword + ':365001');
      } catch (QueryException platform) {
        Assert.areEqual('Date formula too large', platform.getMessage());
      }
    }

    Test.startTest();
    assertSameAsSoql(
      new List<IDateLiteral>{
        DateLiteral.lastNDays(365000),
        DateLiteral.nextNDays(365000),
        DateLiteral.nDaysAgo(365000),
        DateLiteral.nextNWeeks(365000),
        DateLiteral.lastNWeeks(100000),
        DateLiteral.nWeeksAgo(100000)
      },
      rows
    );
    Test.stopTest();
  }

  // What a comparison answers

  @IsTest
  static void aValueIsComparedWithTheRangeAsSoqlDoes() {
    DateLiteral.fixedToday = Date.newInstance(2027, 6, 16);
    DateLiteral.Value june = DateLiteral.checked(DateLiteral.thisMonth());
    Date before = Date.newInstance(2027, 5, 31);
    Date inside = Date.newInstance(2027, 6, 30);
    Date after = Date.newInstance(2027, 7, 1);

    assertAnswers(june, Enums.Comparator.EQ, before, inside, after, new List<Boolean>{ false, true, false });
    assertAnswers(june, Enums.Comparator.NE, before, inside, after, new List<Boolean>{ true, false, true });
    assertAnswers(june, Enums.Comparator.LT, before, inside, after, new List<Boolean>{ true, false, false });
    assertAnswers(june, Enums.Comparator.LE, before, inside, after, new List<Boolean>{ true, true, false });
    assertAnswers(june, Enums.Comparator.GT, before, inside, after, new List<Boolean>{ false, false, true });
    assertAnswers(june, Enums.Comparator.GE, before, inside, after, new List<Boolean>{ false, true, true });
  }

  @IsTest
  static void anEmptyFieldMatchesNotEqualAloneAndIsOtherwiseUnknown() {
    DateLiteral.Value today = DateLiteral.checked(DateLiteral.today());

    Assert.isTrue(today.test(Enums.Comparator.NE, null, null));
    for (Enums.Comparator kind : COMPARATORS) {
      if (kind != Enums.Comparator.NE) {
        Assert.isNull(today.test(kind, null, null), kind + ' has no answer for an empty field');
      }
    }
  }

  @IsTest
  static void aDateTimeIsReadAsADayInTheUsersTimeZone() {
    // In Los Angeles the clocks go forward on this day, which has 23 hours there
    Date day = Date.newInstance(2027, 3, 14);
    DateLiteral.fixedToday = day;
    DateLiteral.Value today = DateLiteral.checked(DateLiteral.today());
    Time midnight = Time.newInstance(0, 0, 0, 0);

    System.runAs(userIn('America/Los_Angeles', 'en_US')) {
      Datetime firstMoment = Datetime.newInstance(day, midnight);
      Datetime firstOfTomorrow = Datetime.newInstance(day.addDays(1), midnight);

      Assert.areEqual(23L, (firstOfTomorrow.getTime() - firstMoment.getTime()) / 3600000, 'the day the clocks change');
      Assert.isTrue(today.test(Enums.Comparator.EQ, firstMoment, null));
      Assert.isTrue(today.test(Enums.Comparator.EQ, firstOfTomorrow.addSeconds(-1), null), 'the last second of today');
      Assert.isFalse(today.test(Enums.Comparator.EQ, firstMoment.addSeconds(-1), null), 'the last second of yesterday');
      Assert.isTrue(today.test(Enums.Comparator.GT, firstOfTomorrow, null), 'the first moment of tomorrow');
      Assert.isTrue(today.test(Enums.Comparator.EQ, Datetime.newInstanceGmt(2027, 3, 15, 6, 59, 59), null), 'tomorrow in GMT, today here');
    }
  }

  @IsTest
  static void onlyDatesAndComparisonsOfOneRangeAreTested() {
    DateLiteral.Value today = DateLiteral.checked(DateLiteral.today());
    try {
      today.test(Enums.Comparator.EQ, 'text', null);
      Assert.fail('compared text');
    } catch (Filtering.ConditionException refused) {
      Assert.areEqual('A date literal compares dates and date-times, not text', refused.getMessage());
    }
    try {
      today.test(Enums.Comparator.LK, Date.newInstance(2027, 6, 16), null);
      Assert.fail('compared with LIKE');
    } catch (Filtering.ConditionException refused) {
      Assert.areEqual('LK cannot compare a field with the date literal TODAY', refused.getMessage());
    }
  }

  // The platform takes every literal

  @IsTest
  static void everyLiteralRunsOnADateField() {
    assertEveryLiteralRuns(Opportunity.CloseDate);
  }

  @IsTest
  static void everyLiteralRunsOnADateTimeField() {
    assertEveryLiteralRuns(Opportunity.CreatedDate);
  }

  // The same answer in memory as from the database, for inserted records

  @IsTest
  static void dayLiteralsAnswerAsSoqlDoes() {
    List<Task> rows = aroundEachDay(-93, 93);
    Test.startTest();
    assertSameAsSoql(
      new List<IDateLiteral>{ DateLiteral.yesterday(), DateLiteral.today(), DateLiteral.tomorrow(), DateLiteral.nDaysAgo(3) },
      rows
    );
    Test.stopTest();
  }

  @IsTest
  static void rangesOfDaysAnswerAsSoqlDoes() {
    List<Task> rows = aroundEachDay(-93, 93);
    Test.startTest();
    assertSameAsSoql(
      new List<IDateLiteral>{ DateLiteral.last90Days(), DateLiteral.next90Days(), DateLiteral.lastNDays(3), DateLiteral.nextNDays(3) },
      rows
    );
    Test.stopTest();
  }

  @IsTest
  static void weekLiteralsAnswerAsSoqlDoes() {
    List<Task> rows = aroundEachDay(-30, 30);
    Test.startTest();
    assertSameAsSoql(
      new List<IDateLiteral>{
        DateLiteral.lastWeek(),
        DateLiteral.thisWeek(),
        DateLiteral.nextWeek(),
        DateLiteral.lastNWeeks(2),
        DateLiteral.nextNWeeks(2),
        DateLiteral.nWeeksAgo(2)
      },
      rows
    );
    Test.stopTest();
  }

  @IsTest
  static void monthLiteralsAnswerAsSoqlDoes() {
    List<Task> rows = aroundEachMonthStart();
    Test.startTest();
    assertSameAsSoql(
      new List<IDateLiteral>{
        DateLiteral.lastMonth(),
        DateLiteral.thisMonth(),
        DateLiteral.nextMonth(),
        DateLiteral.lastNMonths(2),
        DateLiteral.nextNMonths(2),
        DateLiteral.nMonthsAgo(2)
      },
      rows
    );
    Test.stopTest();
  }

  @IsTest
  static void quarterLiteralsAnswerAsSoqlDoes() {
    List<Task> rows = aroundEachMonthStart();
    Test.startTest();
    assertSameAsSoql(
      new List<IDateLiteral>{
        DateLiteral.lastQuarter(),
        DateLiteral.thisQuarter(),
        DateLiteral.nextQuarter(),
        DateLiteral.lastNQuarters(2),
        DateLiteral.nextNQuarters(2),
        DateLiteral.nQuartersAgo(2)
      },
      rows
    );
    Test.stopTest();
  }

  @IsTest
  static void yearLiteralsAnswerAsSoqlDoes() {
    List<Task> rows = aroundEachMonthStart();
    Test.startTest();
    assertSameAsSoql(
      new List<IDateLiteral>{
        DateLiteral.lastYear(),
        DateLiteral.thisYear(),
        DateLiteral.nextYear(),
        DateLiteral.lastNYears(2),
        DateLiteral.nextNYears(2),
        DateLiteral.nYearsAgo(2)
      },
      rows
    );
    Test.stopTest();
  }

  @IsTest
  static void fiscalQuarterLiteralsAnswerAsSoqlDoes() {
    List<Task> rows = aroundEachMonthStart();
    Test.startTest();
    assertFiscalSameAsSoql(
      new List<IDateLiteral>{
        DateLiteral.lastFiscalQuarter(),
        DateLiteral.thisFiscalQuarter(),
        DateLiteral.nextFiscalQuarter(),
        DateLiteral.lastNFiscalQuarters(2),
        DateLiteral.nextNFiscalQuarters(2),
        DateLiteral.nFiscalQuartersAgo(2)
      },
      rows
    );
    Test.stopTest();
  }

  @IsTest
  static void fiscalYearLiteralsAnswerAsSoqlDoes() {
    List<Task> rows = aroundEachMonthStart();
    Test.startTest();
    assertFiscalSameAsSoql(
      new List<IDateLiteral>{
        DateLiteral.lastFiscalYear(),
        DateLiteral.thisFiscalYear(),
        DateLiteral.nextFiscalYear(),
        DateLiteral.lastNFiscalYears(2),
        DateLiteral.nextNFiscalYears(2),
        DateLiteral.nFiscalYearsAgo(2)
      },
      rows
    );
    Test.stopTest();
  }

  @IsTest
  static void aCountOfZeroAnswersAsSoqlDoes() {
    List<Task> rows = aroundEachDay(-40, 40);
    rows.addAll(aroundEachMonthStart());
    Test.startTest();
    assertSameAsSoql(
      new List<IDateLiteral>{
        DateLiteral.lastNDays(0),
        DateLiteral.nextNDays(0),
        DateLiteral.nDaysAgo(0),
        DateLiteral.lastNWeeks(0),
        DateLiteral.nextNMonths(0),
        DateLiteral.nQuartersAgo(0),
        DateLiteral.lastNYears(0)
      },
      rows
    );
    Test.stopTest();
  }

  @IsTest
  static void listsNegationAndGroupsAnswerAsSoqlDoes() {
    List<Task> rows = aroundEachDay(-12, 12);
    List<IDateLiteral> ranges = new List<IDateLiteral>{ DateLiteral.yesterday(), DateLiteral.nextNDays(2) };
    Core core = Application.s;
    List<ICondition> conditions = new List<ICondition>();
    for (SObjectField field : new List<SObjectField>{ Task.ActivityDate, Task.ReminderDateTime }) {
      conditions.add(core.iin(field, ranges));
      conditions.add(core.nin(field, ranges));
      conditions.add(core.neg(core.iin(field, ranges)));
      conditions.add(core.neg(core.nin(field, ranges)));
      conditions.add(core.iin(field, new List<IDateLiteral>()));
      conditions.add(core.neg(core.iin(field, new List<IDateLiteral>())));
      for (Enums.Comparator kind : COMPARATORS) {
        conditions.add(core.cond(kind, field, DateLiteral.today(), true));
      }
      conditions.add(core.neg(core.any(new List<ICondition>{ core.gt(field, DateLiteral.today()), core.eq(Task.Subject, 'none') })));
      conditions.add(core.neg(core.all(new List<ICondition>{ core.le(field, DateLiteral.today()), core.ne(Task.Subject, 'none') })));
      conditions.add(core.model(Task.SObjectType).parseCondition('NOT (' + field + ' >= LAST_N_DAYS:2 AND ' + field + ' != TODAY)'));
    }

    Test.startTest();
    List<String> differences = new List<String>();
    for (ICondition condition : conditions) {
      compare(condition, rows, differences);
    }
    Test.stopTest();

    Assert.areEqual('', String.join(differences, '\n'));
  }

  @IsTest
  static void inAnotherTimeZoneAndLocaleTheAnswersAreStillSoqls() {
    // Fourteen hours ahead of GMT, and a week that starts on Monday
    System.runAs(userIn('Pacific/Kiritimati', 'en_GB')) {
      Date weekStart = DateLiteral.checked(DateLiteral.thisWeek()).firstDay(null);
      Assert.areEqual('Monday', Datetime.newInstance(weekStart, Time.newInstance(12, 0, 0, 0)).format('EEEE'));
      Assert.areEqual('Pacific/Kiritimati', UserInfo.getTimeZone().getID());
      List<Task> rows = aroundEachDay(-16, 16);
      Test.startTest();
      assertSameAsSoql(
        new List<IDateLiteral>{
          DateLiteral.today(),
          DateLiteral.yesterday(),
          DateLiteral.thisWeek(),
          DateLiteral.lastWeek(),
          DateLiteral.nextNWeeks(1),
          DateLiteral.lastNDays(2)
        },
        rows
      );
      Test.stopTest();
    }
  }

  @IsTest
  static void behindGmtWithAHalfHourOffsetTheAnswersAreStillSoqls() {
    // Nine and a half hours behind GMT, and a week that starts on Sunday
    System.runAs(userIn('Pacific/Marquesas', 'en_US')) {
      Date weekStart = DateLiteral.checked(DateLiteral.thisWeek()).firstDay(null);
      Assert.areEqual('Sunday', Datetime.newInstance(weekStart, Time.newInstance(12, 0, 0, 0)).format('EEEE'));
      List<Task> rows = aroundEachDay(-16, 16);
      rows.addAll(aroundEachMonthStart());
      Test.startTest();
      assertSameAsSoql(
        new List<IDateLiteral>{
          DateLiteral.today(),
          DateLiteral.tomorrow(),
          DateLiteral.thisWeek(),
          DateLiteral.nextWeek(),
          DateLiteral.thisMonth(),
          DateLiteral.thisQuarter()
        },
        rows
      );
      Test.stopTest();
    }
  }

  @IsTest
  static void theRangeIsGivenAsItsFirstAndLastDay() {
    DateLiteral.fixedToday = Date.newInstance(2027, 5, 15);
    IDateLiteral thisMonth = DateLiteral.thisMonth();
    Assert.areEqual(Date.newInstance(2027, 5, 1), thisMonth.startDate());
    Assert.areEqual(Date.newInstance(2027, 5, 31), thisMonth.endDate(), 'the last day, not the day after it');

    IDateLiteral lastThreeDays = DateLiteral.lastNDays(3);
    Assert.areEqual(Date.newInstance(2027, 5, 12), lastThreeDays.startDate());
    Assert.areEqual(Date.newInstance(2027, 5, 15), lastThreeDays.endDate(), 'LAST_N_DAYS includes today');

    IDateLiteral noWeeks = DateLiteral.lastNWeeks(0);
    Assert.areEqual(noWeeks.startDate().addDays(-1), noWeeks.endDate(), 'a range of no days ends the day before it starts');

    DateLiteral.fiscalStartMonth = 4;
    IDateLiteral thisFiscalYear = DateLiteral.thisFiscalYear();
    Assert.areEqual(Date.newInstance(2027, 4, 1), thisFiscalYear.startDate());
    Assert.areEqual(Date.newInstance(2028, 3, 31), thisFiscalYear.endDate());
  }

  // Helpers

  private static void assertSpan(IDateLiteral literal, Date first, Date dayAfterLast) {
    DateLiteral.Value value = DateLiteral.checked(literal);
    Assert.areEqual(first, value.firstDay(null), literal.toSoql() + ' starts');
    Assert.areEqual(dayAfterLast, value.dayAfter(null), literal.toSoql() + ' ends before');
  }

  private static void assertAnswers(
    DateLiteral.Value range,
    Enums.Comparator kind,
    Date before,
    Date inside,
    Date after,
    List<Boolean> expected
  ) {
    List<Boolean> actual = new List<Boolean>{ range.test(kind, before, null), range.test(kind, inside, null), range.test(kind, after, null) };
    Assert.areEqual(expected, actual, kind + ' before, inside and after ' + range);
  }

  private static void assertEveryLiteralRuns(SObjectField field) {
    Test.startTest();
    for (String keyword : DateLiteral.keywords()) {
      String text = keyword.contains('_N_') || keyword.startsWith('N_') ? keyword + ':2' : keyword;
      IQuery q = Application.s.model(Opportunity.SObjectType).query();
      q.filters().add(Application.s.eq(field, DateLiteral.of(text)));
      Assert.areEqual('SELECT Id FROM Opportunity WHERE (' + field + ' = ' + text + ')', q.toSoql(true), 'never bound');
      Assert.areEqual(0, q.run().size(), text);
    }
    Test.stopTest();
  }

  // Two tasks for each day from today: one dated the day before, at its last second, and one
  // dated the day, at its first moment. Any range that starts or ends there splits the pair.
  private static List<Task> aroundEachDay(Integer fromOffset, Integer toOffset) {
    List<Date> starts = new List<Date>();
    for (Integer offset = fromOffset; offset <= toOffset; offset++) {
      starts.add(Date.today().addDays(offset));
    }
    return insertedAround(starts, true);
  }

  // The same pairs around the first day of every month, for forty months back and forward.
  private static List<Task> aroundEachMonthStart() {
    List<Date> starts = new List<Date>();
    for (Integer offset = -40; offset <= 40; offset++) {
      starts.add(Date.today().toStartOfMonth().addMonths(offset));
    }
    return insertedAround(starts, false);
  }

  private static List<Task> insertedAround(List<Date> starts, Boolean withOddOnes) {
    List<Task> rows = new List<Task>();
    for (Date start : starts) {
      Datetime firstMoment = Datetime.newInstance(start, Time.newInstance(0, 0, 0, 0));
      rows.add(new Task(Subject = 'before', CallDisposition = MARK, ActivityDate = start.addDays(-1), ReminderDateTime = firstMoment.addSeconds(-1)));
      rows.add(new Task(Subject = 'from', CallDisposition = MARK, ActivityDate = start, ReminderDateTime = firstMoment));
    }
    if (withOddOnes) {
      rows.add(new Task(Subject = 'empty', CallDisposition = MARK));
      rows.add(new Task(Subject = 'now', CallDisposition = MARK, ActivityDate = Date.today(), ReminderDateTime = Datetime.now()));
      rows.add(new Task(Subject = 'later today', CallDisposition = MARK, ActivityDate = Date.today(), ReminderDateTime = Datetime.now().addMinutes(1)));
    }
    insert rows;
    return rows;
  }

  // Every comparison of each literal with a date field and a date-time field.
  private static void assertSameAsSoql(List<IDateLiteral> literals, List<Task> rows) {
    List<String> differences = new List<String>();
    for (IDateLiteral literal : literals) {
      for (Enums.Comparator kind : COMPARATORS) {
        compare(Application.s.cond(kind, Task.ActivityDate, literal), rows, differences);
        compare(Application.s.cond(kind, Task.ReminderDateTime, literal), rows, differences);
      }
    }
    Assert.areEqual('', String.join(differences, '\n'));
  }

  // Fiscal ranges are compared with the database where fiscal years are standard. Where they are
  // custom, only the database knows them, and what is checked is that in memory they are refused.
  private static void assertFiscalSameAsSoql(List<IDateLiteral> literals, List<Task> rows) {
    if (hasCustomFiscalYears()) {
      assertRefusedForCustomFiscalYears(literals);
    } else {
      assertSameAsSoql(literals, rows);
    }
  }

  private static Boolean hasCustomFiscalYears() {
    return [SELECT COUNT() FROM FiscalYearSettings WHERE IsStandardYear = FALSE] > 0;
  }

  private static void assertRefusedForCustomFiscalYears(List<IDateLiteral> literals) {
    for (IDateLiteral literal : literals) {
      ICondition condition = Application.s.eq(Task.ActivityDate, literal);
      Assert.areEqual(0, Application.s.model(Task.SObjectType).query().addCondition(condition).count(), 'a query takes it');
      try {
        condition.evaluate(new Task(ActivityDate = Date.today()));
        Assert.fail('a custom fiscal year was worked out for ' + literal.toSoql());
      } catch (Filtering.ConditionException refused) {
        Assert.areEqual('Cannot evaluate a fiscal date literal in memory: the organization has custom fiscal years', refused.getMessage());
      }
    }
  }

  // Runs the condition as SOQL and tests it in memory on the same records; notes any difference.
  private static void compare(ICondition condition, List<Task> rows, List<String> differences) {
    IQuery q = Application.s.model(Task.SObjectType).query();
    q.filters().add(Application.s.eq(Task.CallDisposition, MARK));
    q.filters().add(condition);
    Set<Id> fromSoql = new Map<Id, SObject>(q.run()).keySet();
    List<String> wrong = new List<String>();
    for (Task row : rows) {
      Boolean inMemory = condition.evaluate(row);
      if (inMemory != fromSoql.contains(row.Id)) {
        wrong.add(row.ActivityDate + '/' + row.ReminderDateTime + ' is ' + inMemory + ' in memory');
      }
    }
    if (!wrong.isEmpty()) {
      differences.add(condition.toSoql() + ': ' + wrong.size() + ' of ' + rows.size() + ' differ, first ' + wrong[0]);
    }
  }

  private static User userIn(String timeZone, String locale) {
    String unique = 'literal.' + locale + '.' + UserInfo.getOrganizationId() + '.' + System.now().getTime() + '@dateliteral.example.com';
    return new User(
      Alias = 'dlit',
      LastName = 'Literal',
      Email = 'date.literal@example.com',
      Username = unique,
      ProfileId = UserInfo.getProfileId(),
      TimeZoneSidKey = timeZone,
      LocaleSidKey = locale,
      LanguageLocaleKey = 'en_US',
      EmailEncodingKey = 'UTF-8'
    );
  }

  private class ForeignLiteral implements IDateLiteral {
    private String text;

    private ForeignLiteral(String text) {
      this.text = text;
    }

    public String toSoql() {
      return text;
    }

    // Never asked: the framework reads a literal of another class from its text alone.
    public Date startDate() {
      return null;
    }

    public Date endDate() {
      return null;
    }
  }
}
