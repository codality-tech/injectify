@IsTest
private class TypingTest {
  private static final Set<Enums.Comparator> COLLECTION_OPERATORS = new Set<Enums.Comparator>{
    Enums.Comparator.IIN,
    Enums.Comparator.NIN,
    Enums.Comparator.INC,
    Enums.Comparator.EXC
  };

  @IsTest
  static void operatorsKnowTheirKeywordAndShape() {
    Map<Enums.Comparator, String> keywords = new Map<Enums.Comparator, String>{
      Enums.Comparator.EQ => '=',
      Enums.Comparator.NE => '!=',
      Enums.Comparator.GE => '>=',
      Enums.Comparator.LE => '<=',
      Enums.Comparator.GT => '>',
      Enums.Comparator.LT => '<',
      Enums.Comparator.LK => 'LIKE',
      Enums.Comparator.IIN => 'IN',
      Enums.Comparator.NIN => 'NOT IN',
      Enums.Comparator.INC => 'INCLUDES',
      Enums.Comparator.EXC => 'EXCLUDES'
    };

    Assert.areEqual(keywords.keySet(), new Set<Enums.Comparator>(Enums.Comparator.values()), 'every comparator is covered');
    for (Enums.Comparator kind : keywords.keySet()) {
      Typing.Operator op = Typing.operator(kind);
      Assert.areEqual(kind, op.comparator());
      Assert.areEqual(keywords.get(kind), op.toSoql());
      Assert.areEqual(COLLECTION_OPERATORS.contains(kind), op.isPlural(), String.valueOf(kind));
      Boolean literalOnly = kind == Enums.Comparator.INC || kind == Enums.Comparator.EXC;
      Assert.areEqual(!literalOnly, op.supportsBinding(), String.valueOf(kind));
    }
    Assert.isNull(Typing.operator(null));
  }

  @IsTest
  static void operatorsApplyOnlyToSuitableFields() {
    DescribeFieldResult checkbox = Opportunity.IsClosed.getDescribe();
    DescribeFieldResult amount = Opportunity.Amount.getDescribe();
    DescribeFieldResult picklist = Account.Industry.getDescribe();

    Assert.isFalse(Typing.operator(Enums.Comparator.GT).supportsField(checkbox), 'checkboxes have no order');
    Assert.isTrue(Typing.operator(Enums.Comparator.EQ).supportsField(checkbox));
    Assert.isTrue(Typing.operator(Enums.Comparator.LK).supportsField(picklist), 'picklists are text');
    Assert.isFalse(Typing.operator(Enums.Comparator.LK).supportsField(amount));
    Assert.isFalse(Typing.operator(Enums.Comparator.INC).supportsField(picklist), 'single-select');
    Assert.isTrue(Typing.operator(Enums.Comparator.IIN).supportsField(amount));
  }

  @IsTest
  static void comparisonsWriteValuesInline() {
    Map<String, Typing.Comparison> expected = new Map<String, Typing.Comparison>{
      'Name = \'Acme\'' => compare(Account.Name, Enums.Comparator.EQ, 'Acme'),
      'Name = \'O\\\'Brien\'' => compare(Account.Name, Enums.Comparator.EQ, 'O\'Brien'),
      'Name IN (\'a\', \'b\')' => compare(Account.Name, Enums.Comparator.IIN, new List<String>{ 'a', 'b' }),
      'Name LIKE \'50\\% off%\'' => compare(Account.Name, Enums.Comparator.LK, '50\\% off%'),
      'Name = null' => compare(Account.Name, Enums.Comparator.EQ, null),
      'Amount <= 12.5' => compare(Opportunity.Amount, Enums.Comparator.LE, 12.5),
      'IsClosed = true' => compare(Opportunity.IsClosed, Enums.Comparator.EQ, true),
      'CloseDate > 2026-01-31' => compare(Opportunity.CloseDate, Enums.Comparator.GT, Date.newInstance(2026, 1, 31)),
      'CreatedDate >= 2026-01-31T09:30:15.000Z' => compare(
        Account.CreatedDate,
        Enums.Comparator.GE,
        Datetime.newInstanceGmt(2026, 1, 31, 9, 30, 15)
      ),
      'MondayStartTime < 09:30:00.250Z' => compare(
        BusinessHours.MondayStartTime,
        Enums.Comparator.LT,
        Time.newInstance(9, 30, 0, 250)
      )
    };

    for (String soql : expected.keySet()) {
      Assert.areEqual(soql, expected.get(soql).toSoql());
    }
    Assert.areEqual('Name = :a0', compare(Account.Name, Enums.Comparator.EQ, 'Acme').toSoql(':a0'));
  }

  @IsTest
  static void emptyCollectionsBecomeConstantTests() {
    Assert.areEqual('(Id = null AND Id != null)', compare(Account.Name, Enums.Comparator.IIN, new Set<String>()).toSoql());
    Assert.areEqual('(Id = null OR Id != null)', compare(Account.Name, Enums.Comparator.NIN, null).toSoql());
    Assert.areEqual(
      '(LinkedEntityId = null AND LinkedEntityId != null)',
      compare(ContentDocumentLink.ShareType, Enums.Comparator.IIN, new List<String>()).toSoql(),
      'ContentDocumentLink cannot be filtered on Id'
    );
  }

  @IsTest
  static void comparisonsTestRecordsInMemory() {
    Account acme = new Account(Name = 'Acme Corp', AnnualRevenue = 500);

    Assert.isTrue(compare(Account.Name, Enums.Comparator.EQ, 'acme corp').evaluate(acme), 'case is ignored');
    Assert.isTrue(compare(Account.Name, Enums.Comparator.LK, 'ac%').evaluate(acme));
    Assert.isTrue(compare(Account.Name, Enums.Comparator.NIN, new Set<String>{ 'Globex' }).evaluate(acme));
    Assert.isTrue(compare(Account.AnnualRevenue, Enums.Comparator.GT, 499).evaluate(acme));
    Assert.isFalse(compare(Account.AnnualRevenue, Enums.Comparator.IIN, new List<Integer>{ 1, 2 }).evaluate(acme));
    Assert.isFalse(compare(Account.Industry, Enums.Comparator.EQ, 'Energy').evaluate(acme));
    Assert.isTrue(compare(Account.Industry, Enums.Comparator.EQ, null).evaluate(acme), 'blank equals null');
  }

  @IsTest
  static void setOperatorSwapsTheOperatorOnly() {
    Typing.Comparison comparison = compare(Account.Name, Enums.Comparator.EQ, 'Acme');

    comparison.setOperator(Typing.operator(Enums.Comparator.NE));

    Assert.areEqual('Name != \'Acme\'', comparison.toSoql());
    Assert.isTrue(comparison.evaluate(new Account(Name = 'Globex')));
    Assert.areEqual('Name', comparison.path().name());
  }

  @IsTest
  static void unsuitableValuesAreRejected() {
    Map<String, Object[]> attempts = new Map<String, Object[]>{
      'takes a list or set' => new List<Object>{ Account.Name, Enums.Comparator.IIN, 'single' },
      'takes one value' => new List<Object>{ Account.Name, Enums.Comparator.EQ, new Set<String>{ 'a' } },
      'does not apply to IsClosed' => new List<Object>{ Opportunity.IsClosed, Enums.Comparator.GT, true },
      'does not apply to Name' => new List<Object>{ Account.Name, Enums.Comparator.INC, new Set<String>{ 'a' } },
      'cannot be compared with integer' => new List<Object>{ Account.Name, Enums.Comparator.EQ, 5 },
      'cannot be compared with string' => new List<Object>{ Opportunity.Amount, Enums.Comparator.EQ, 'five' },
      'with a value of that type' => new List<Object>{ Account.Name, Enums.Comparator.EQ, new Account() }
    };

    for (String fragment : attempts.keySet()) {
      Object[] parts = attempts.get(fragment);
      try {
        compare((SObjectField) parts[0], (Enums.Comparator) parts[1], parts[2]);
        Assert.fail('accepted: ' + fragment);
      } catch (Typing.ValidationException expected) {
        Assert.isTrue(expected.getMessage().contains(fragment), expected.getMessage());
      }
    }
  }

  @IsTest
  static void aPathAndAnOperatorAreRequired() {
    for (Integer attempt = 0; attempt < 2; attempt++) {
      try {
        Typing.comparison(
          attempt == 0 ? null : Application.s.path(Account.Name),
          attempt == 0 ? Enums.Comparator.EQ : null,
          'x'
        );
        Assert.fail('attempt ' + attempt);
      } catch (Typing.ComparisonException expected) {
        Assert.isTrue(expected.getMessage().startsWith('A comparison needs'), expected.getMessage());
      }
    }
  }

  @IsTest
  static void textComparesWithoutCase() {
    DescribeFieldResult name = Opportunity.Name.getDescribe();

    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.EQ, name, 'a', 'A'));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.EQ, name, '', null), 'null counts as blank');
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.NE, name, 'a', 'b'));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.LT, name, 'a', 'b'));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.GE, name, 'b', 'b'));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.IIN, name, 'B', new Set<String>{ 'a', 'b' }));
    Assert.isFalse(Typing.doEvaluate(Enums.Comparator.NIN, name, 'a', new List<String>{ 'a' }));
    Assert.isFalse(Typing.doEvaluate(Enums.Comparator.IIN, name, 'a', null), 'nothing to be in');
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.INC, name, 'red;green', new Set<String>{ 'GREEN' }));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.EXC, name, null, new Set<String>{ 'red' }));
  }

  @IsTest
  static void idsMatchInCollections() {
    DescribeFieldResult idField = Opportunity.Id.getDescribe();
    List<Id> ids = IdUtil.generateIds(Application.s.model(Opportunity.SObjectType), 2);

    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.IIN, idField, ids[0], new Set<Id>(ids)));
    Assert.isFalse(Typing.doEvaluate(Enums.Comparator.NIN, idField, ids[1], ids));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.EQ, idField, ids[0], String.valueOf(ids[0])));
  }

  @IsTest
  static void numbersCompareByValue() {
    DescribeFieldResult amount = Opportunity.Amount.getDescribe();

    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.EQ, amount, 2, 2.0));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.GT, amount, 3, 2.5));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.LE, amount, 2, 2));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.IIN, amount, 2, new Set<Integer>{ 1, 2 }));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.IIN, amount, 2, new Set<Double>{ 2.0 }));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.IIN, amount, 2, new List<Long>{ 2L }));
    Assert.isFalse(Typing.doEvaluate(Enums.Comparator.NIN, amount, 2, new Set<Decimal>{ 2 }));
    Assert.isNull(Typing.doEvaluate(Enums.Comparator.LK, amount, 2, 2), 'LIKE is for text');
  }

  @IsTest
  static void nullsNeverSatisfyAnOrdering() {
    DescribeFieldResult amount = Opportunity.Amount.getDescribe();

    for (Enums.Comparator kind : new List<Enums.Comparator>{ Enums.Comparator.GT, Enums.Comparator.GE, Enums.Comparator.LT, Enums.Comparator.LE }) {
      Assert.isNull(Typing.doEvaluate(kind, amount, null, 1), 'unknown: null left, ' + kind);
      Assert.isNull(Typing.doEvaluate(kind, amount, 1, null), 'unknown: null right, ' + kind);
    }
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.EQ, amount, null, null));
  }

  @IsTest
  static void datesTimesAndCheckboxes() {
    DescribeFieldResult closeDate = Opportunity.CloseDate.getDescribe();
    DescribeFieldResult opening = BusinessHours.MondayStartTime.getDescribe();
    DescribeFieldResult closed = Opportunity.IsClosed.getDescribe();
    Date today = Date.today();

    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.EQ, closeDate, today, today));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.LT, closeDate, today, today.addDays(1)));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.IIN, closeDate, today, new Set<Date>{ today }));
    Assert.isFalse(Typing.doEvaluate(Enums.Comparator.NIN, closeDate, today, new List<Date>{ today }));

    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.GT, opening, Time.newInstance(9, 0, 0, 0), Time.newInstance(8, 0, 0, 0)));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.IIN, opening, Time.newInstance(9, 0, 0, 0), new Set<Time>{ Time.newInstance(9, 0, 0, 0) }));

    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.NE, closed, true, false));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.IIN, closed, false, new List<Boolean>{ false }));
    Assert.isNull(Typing.doEvaluate(Enums.Comparator.GT, closed, true, false), 'checkboxes have no order');
  }

  @IsTest
  static void likeFollowsSoqlRules() {
    Map<String, Map<String, Boolean>> outcomes = new Map<String, Map<String, Boolean>>{
      'ac%' => new Map<String, Boolean>{ 'ACME' => true, 'xacme' => false },
      '%corp' => new Map<String, Boolean>{ 'Acme Corp' => true, 'Corporate' => false },
      'b_t' => new Map<String, Boolean>{ 'bat' => true, 'boat' => false },
      '100\\%' => new Map<String, Boolean>{ '100%' => true, '1000' => false },
      'a\\_b' => new Map<String, Boolean>{ 'a_b' => true, 'axb' => false },
      'a.c' => new Map<String, Boolean>{ 'a.c' => true, 'abc' => false },
      '%' => new Map<String, Boolean>{ '' => true, 'line\nbreak' => true }
    };

    for (String expression : outcomes.keySet()) {
      Map<String, Boolean> byText = outcomes.get(expression);
      for (String text : byText.keySet()) {
        Assert.areEqual(byText.get(text), Typing.doEvaluateLike(text, expression), text + ' LIKE ' + expression);
      }
    }
    Assert.isTrue(Typing.doEvaluateLike(null, ''), 'null and blank');
    Assert.isFalse(Typing.doEvaluateLike('x', null));
  }

  @IsTest
  static void valuesAreTypedNarrowestFirst() {
    Id someId = UserInfo.getUserId();
    Map<String, Object> samples = new Map<String, Object>{
      'id' => someId,
      'string' => '42',
      'integer' => 1,
      'long' => 3000000000L,
      'double' => 2.5,
      'date' => Date.today(),
      'datetime' => Datetime.now(),
      'time' => Time.newInstance(1, 2, 3, 4),
      'boolean' => false,
      'list<id>' => new List<Id>{ someId },
      'list<string>' => new List<String>(),
      'list<integer>' => new List<Integer>{ 1 },
      'list<double>' => new List<Decimal>{ 1.5 },
      'list<date>' => new List<Date>(),
      'list<time>' => new List<Time>(),
      'set<id>' => new Set<Id>{ someId },
      'set<decimal>' => new Set<Decimal>{ 1 },
      'set<long>' => new Set<Long>{ 1L },
      'set<datetime>' => new Set<Datetime>(),
      'set<boolean>' => new Set<Boolean>{ true }
    };

    for (String expected : samples.keySet()) {
      Assert.areEqual(expected, Typing.getSoapyValue(samples.get(expected), null).typeName());
    }
    Assert.isNull(Typing.getSoapyValue(new Account(), null), 'records are not values');
    Assert.isNull(Typing.getSoapyValue(Blob.valueOf('x'), null));
  }

  @IsTest
  static void nullTakesTheFieldsFamily() {
    Typing.SoapyValue forText = Typing.getSoapyValue(null, SoapType.ID);
    Typing.SoapyValue untyped = Typing.getSoapyValue(null, null);

    Assert.areEqual('list<string>', forText.typeName());
    Assert.isTrue(forText.isPlural());
    Assert.isTrue(forText.getEvaluator().itemsToSoql().isEmpty());
    Assert.isNull(untyped.typeName());
    Assert.isNull(untyped.getEvaluator());
    Assert.isNull(Typing.doEvaluate(Enums.Comparator.EQ, Opportunity.Amount.getDescribe(), 1, new Account()));
  }

  @IsTest
  static void evaluatorsWriteSoqlLiterals() {
    Map<Object, List<String>> expected = new Map<Object, List<String>>{
      new List<String>{ 'it\'s', null } => new List<String>{ '\'it\\\'s\'', 'null' },
      new List<Decimal>{ 1.25, -3 } => new List<String>{ '1.25', '-3' },
      new List<Date>{ Date.newInstance(2026, 2, 3) } => new List<String>{ '2026-02-03' },
      new List<Time>{ Time.newInstance(23, 5, 9, 7), null } => new List<String>{ '23:05:09.007Z', 'null' },
      new List<Boolean>{ true, false } => new List<String>{ 'true', 'false' }
    };

    for (Object values : expected.keySet()) {
      Typing.Evaluator evaluator = Typing.getSoapyValue(values, null).getEvaluator();
      Assert.areEqual(expected.get(values), evaluator.itemsToSoql());
    }
  }

  @IsTest
  static void combineMergesSetsAndJoinsLists() {
    Datetime start = Datetime.newInstanceGmt(2026, 1, 1, 8, 0, 0);

    Assert.areEqual(
      new Set<String>{ 'a', 'b', 'c' },
      Typing.combine(new List<Set<String>>{ new Set<String>{ 'a', 'b' }, new Set<String>{ 'b', 'c' } })
    );
    Assert.areEqual(
      new Set<Integer>{ 1, 2, 3 },
      Typing.combine((List<Object>) new List<Set<Integer>>{ new Set<Integer>{ 1, 2 }, new Set<Integer>{ 2, 3 } })
    );
    Assert.areEqual(
      new Set<Datetime>{ start, start.addHours(1) },
      Typing.combine((List<Object>) new List<Set<Datetime>>{ new Set<Datetime>{ start }, new Set<Datetime>{ start, start.addHours(1) } })
    );
    Assert.areEqual(
      new Set<Time>{ start.timeGmt() },
      Typing.combine((List<Object>) new List<Set<Time>>{ new Set<Time>{ start.timeGmt() }, new Set<Time>{ start.timeGmt() } })
    );
    Assert.areEqual(
      new List<Integer>{ 1, 1, 2 },
      Typing.combine((List<Object>) new List<List<Integer>>{ new List<Integer>{ 1 }, new List<Integer>{ 1, 2 } })
    );
    Assert.areEqual(
      new List<String>{ 'x', 'y' },
      Typing.combine(new List<List<String>>{ new List<String>{ 'x' }, new List<String>{ 'y' } })
    );
    Assert.isNull(Typing.combine(new List<Object>{ 'not a collection' }));
    Assert.isNull(Typing.combine(new List<Object>()));
    Assert.isNull(Typing.combine(null));
  }

  private static Typing.Comparison compare(SObjectField field, Enums.Comparator kind, Object value) {
    return Typing.comparison(Application.s.path(field), kind, value);
  }

  @IsTest
  static void aDateLiteralIsARangeNotAValue() {
    DateLiteral.fixedToday = Date.newInstance(2027, 6, 16);
    Typing.Comparison thisYear = compare(Opportunity.CloseDate, Enums.Comparator.EQ, DateLiteral.thisYear());
    Typing.Comparison lately = compare(
      Opportunity.CreatedDate,
      Enums.Comparator.NIN,
      new List<IDateLiteral>{ DateLiteral.yesterday(), DateLiteral.today() }
    );

    Assert.areEqual('CloseDate = THIS_YEAR', thisYear.toSoql());
    Assert.areEqual('CloseDate = :a0', thisYear.toSoql(':a0'), 'given text is still written as given');
    Assert.areEqual('CreatedDate NOT IN (YESTERDAY, TODAY)', lately.toSoql());
    Assert.areEqual(
      '(Id = null AND Id != null)',
      compare(Opportunity.CloseDate, Enums.Comparator.IIN, new List<IDateLiteral>()).toSoql(),
      'IN no range at all is never true'
    );

    Assert.isTrue(thisYear.evaluate(new Opportunity(CloseDate = Date.newInstance(2027, 12, 31))));
    Assert.isFalse(thisYear.evaluate(new Opportunity(CloseDate = Date.newInstance(2028, 1, 1))));
    Assert.isFalse(lately.evaluate((Opportunity) JSON.deserialize('{"attributes":{"type":"Opportunity"},"CreatedDate":"2027-06-15T12:00:00.000+0000"}', Opportunity.class)));
    Assert.isTrue(lately.evaluate((Opportunity) JSON.deserialize('{"attributes":{"type":"Opportunity"},"CreatedDate":"2027-06-13T12:00:00.000+0000"}', Opportunity.class)));
    Assert.isNull(thisYear.evaluate(new Opportunity()), 'unknown for an empty date');
    Assert.isTrue(compare(Opportunity.CloseDate, Enums.Comparator.NE, DateLiteral.thisYear()).evaluate(new Opportunity()));

    Assert.isTrue(lately.evaluate(new Opportunity(Name = 'no CreatedDate')), 'an empty field is in neither range');
    Assert.isNull(
      compare(Opportunity.CloseDate, Enums.Comparator.IIN, new List<IDateLiteral>{ DateLiteral.today() }).evaluate(new Opportunity())
    );
    Assert.isFalse(compare(Opportunity.CloseDate, Enums.Comparator.IIN, new List<IDateLiteral>()).evaluate(new Opportunity()));
  }

  @IsTest
  static void aDateLiteralIsRejectedWhereThePlatformRejectsIt() {
    Map<String, Object[]> attempts = new Map<String, Object[]>{
      'Name holds string values, so it cannot be compared with a date literal' => new List<Object>{ Opportunity.Name, Enums.Comparator.EQ, DateLiteral.lastNDays(3) },
      'Amount holds decimal values' => new List<Object>{ Opportunity.Amount, Enums.Comparator.GT, DateLiteral.today() },
      'MondayStartTime holds time values' => new List<Object>{ BusinessHours.MondayStartTime, Enums.Comparator.EQ, DateLiteral.today() },
      'LK does not apply to a date literal' => new List<Object>{ Opportunity.CloseDate, Enums.Comparator.LK, DateLiteral.today() },
      'EXC does not apply to a date literal' => new List<Object>{ Opportunity.CloseDate, Enums.Comparator.EXC, DateLiteral.today() },
      'NIN takes a list of date literals, not one' => new List<Object>{ Opportunity.CloseDate, Enums.Comparator.NIN, DateLiteral.today() },
      'GE takes one date literal, not a list of them' => new List<Object>{ Opportunity.CloseDate, Enums.Comparator.GE, new List<IDateLiteral>{ DateLiteral.today() } }
    };

    for (String fragment : attempts.keySet()) {
      Object[] parts = attempts.get(fragment);
      try {
        compare((SObjectField) parts[0], (Enums.Comparator) parts[1], parts[2]);
        Assert.fail('accepted: ' + fragment);
      } catch (Typing.ValidationException expected) {
        Assert.isTrue(expected.getMessage().contains(fragment), expected.getMessage());
      }
    }
  }

  @IsTest
  static void anEmptyNumberDateOrTimeHasNoOrder() {
    DescribeFieldResult amount = Opportunity.Amount.getDescribe();
    DescribeFieldResult closeDate = Opportunity.CloseDate.getDescribe();
    DescribeFieldResult opening = BusinessHours.MondayStartTime.getDescribe();
    DescribeFieldResult name = Opportunity.Name.getDescribe();

    for (Enums.Comparator kind : new List<Enums.Comparator>{ Enums.Comparator.GT, Enums.Comparator.GE, Enums.Comparator.LT, Enums.Comparator.LE }) {
      Assert.isNull(Typing.doEvaluate(kind, amount, null, 1), 'unknown: an empty number, ' + kind);
      Assert.isNull(Typing.doEvaluate(kind, closeDate, null, Date.today()), 'unknown: an empty date, ' + kind);
      Assert.isNull(Typing.doEvaluate(kind, opening, null, Time.newInstance(9, 0, 0, 0)), 'unknown: an empty time, ' + kind);
      Assert.isNotNull(Typing.doEvaluate(kind, name, null, 'a'), 'empty text reads as blank, and has an order: ' + kind);
    }
    Assert.isFalse(Typing.doEvaluate(Enums.Comparator.EQ, amount, null, 1), 'equality answers for an empty field');
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.NE, closeDate, null, Date.today()));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.NIN, amount, null, new Set<Integer>{ 1 }));
  }

  @IsTest
  static void likeNeverMatchesAnEmptyField() {
    DescribeFieldResult name = Opportunity.Name.getDescribe();

    Assert.isFalse(Typing.doEvaluate(Enums.Comparator.LK, name, null, '%'), 'not even with %');
    Assert.isFalse(Typing.doEvaluate(Enums.Comparator.LK, name, null, 'a%'));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.LK, name, '', '%'), 'blank text that is there does match');
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.LK, name, null, ''), 'an empty pattern is not SOQL; bound, it matches empty fields');
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.LK, name, 'Acme', 'ac%'));
  }

  @IsTest
  static void idsMatchInTheirExactCaseAndInEitherLength() {
    DescribeFieldResult lookup = Opportunity.AccountId.getDescribe();
    Id accountId = IdUtil.generateId(Account.SObjectType);
    String whole = String.valueOf(accountId);
    String shortForm = whole.left(15);

    Assert.areEqual(18, whole.length());
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.EQ, lookup, accountId, shortForm), '15 characters match 18');
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.EQ, lookup, shortForm, whole), 'and 18 match 15');
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.IIN, lookup, accountId, new Set<String>{ shortForm }));
    Assert.isFalse(Typing.doEvaluate(Enums.Comparator.NIN, lookup, accountId, new List<String>{ shortForm }));
    Assert.isFalse(Typing.doEvaluate(Enums.Comparator.EQ, lookup, accountId, whole.toLowerCase()), 'another case is another Id');
    Assert.isFalse(Typing.doEvaluate(Enums.Comparator.EQ, lookup, accountId, 'not an id here'));
    Assert.isFalse(Typing.doEvaluate(Enums.Comparator.EQ, lookup, accountId, 'not an id here!'), 'fifteen characters that are not an Id');
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.EQ, lookup, null, null));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.EQ, Opportunity.Name.getDescribe(), 'acme', 'ACME'), 'text still ignores case');
  }

  @IsTest
  static void aCheckboxReadsNullAsFalse() {
    DescribeFieldResult closed = Opportunity.IsClosed.getDescribe();

    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.EQ, closed, false, null), 'as SOQL does: IsClosed = null finds the open ones');
    Assert.isFalse(Typing.doEvaluate(Enums.Comparator.EQ, closed, true, null));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.NE, closed, true, null));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.EQ, closed, null, false), 'a checkbox that was not set is unchecked');
    Assert.isFalse(Typing.doEvaluate(Enums.Comparator.IIN, closed, false, new List<Boolean>()), 'in nothing');
  }

  @IsTest
  static void aDateOnADateTimeFieldIsWrittenAsMidnightGmt() {
    Date day = Date.newInstance(2026, 1, 15);

    Assert.areEqual('CreatedDate > 2026-01-15T00:00:00.000Z', compare(Opportunity.CreatedDate, Enums.Comparator.GT, day).toSoql());
    Assert.areEqual(
      'CreatedDate IN (2026-01-15T00:00:00.000Z)',
      compare(Opportunity.CreatedDate, Enums.Comparator.IIN, new Set<Date>{ day }).toSoql()
    );
    Assert.areEqual('CloseDate > 2026-01-15', compare(Opportunity.CloseDate, Enums.Comparator.GT, day).toSoql(), 'a date field takes the date');
    Assert.isTrue(
      compare(Opportunity.CreatedDate, Enums.Comparator.EQ, day)
        .evaluate((Opportunity) JSON.deserialize('{"attributes":{"type":"Opportunity"},"CreatedDate":"2026-01-15T00:00:00.000+0000"}', Opportunity.class)),
      'and in memory it is the same moment'
    );
  }

  @IsTest
  static void aMultiSelectValueMayNameSeveralChoices() {
    DescribeFieldResult anyText = Opportunity.Name.getDescribe(); // INCLUDES reads the value alike whatever the field

    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.INC, anyText, 'red;green;blue', new List<String>{ 'green;RED' }), 'it has both');
    Assert.isFalse(Typing.doEvaluate(Enums.Comparator.INC, anyText, 'red', new List<String>{ 'green;red' }), 'it has one of the two');
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.INC, anyText, 'red', new List<String>{ 'green;red', 'red' }), 'the values are alternatives');
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.EXC, anyText, 'red', new List<String>{ 'green;red' }));
    Assert.isFalse(Typing.doEvaluate(Enums.Comparator.EXC, anyText, 'green;red', new List<String>{ 'red;green' }));
    Assert.isNull(Typing.doEvaluate(Enums.Comparator.INC, anyText, null, new Set<String>{ 'red' }), 'unknown: an empty field includes nothing, and NOT leaves it out too');
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.EXC, anyText, null, new Set<String>{ 'red' }), 'but it does exclude everything');
    Assert.isFalse(Typing.doEvaluate(Enums.Comparator.INC, anyText, null, new Set<String>()), 'a list of nothing is a constant, with an answer');
  }
}
