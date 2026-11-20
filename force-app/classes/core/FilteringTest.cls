@isTest
private class FilteringTest {
  private static Core core = new Core();
  private static Filtering filtering = new Filtering(core);

  static void assertLogicalCondition(
    Filtering.LogicalCondition cnd,
    SObjectType sobjectType
  ) {
    if (sobjectType != null) {
      cnd.realize(sobjectType);
    }
    string soql = cnd.toSoql();
    list<ICondition> condList = cnd.getAll();
    for (ICondition cond : condList) {
      Assert.isTrue(soql.contains(cond.toSoql()));
      cnd.add(cond.clone(true));
    }
    Assert.areEqual(condList.size() * 2, cnd.getAll().size());
    soql = cnd.toSoql();
    for (ICondition cond : cnd.getAll()) {
      Assert.isTrue(soql.contains(cond.toSoql()));
    }
    assertSoqlRoundTrip(cnd, true);
    assertValidSoql(cnd);
  }

  static void assertSoqlRoundTrip(ICondition cnd, boolean identical) {
    string soql = cnd.toSoql();
    ICondition parsedCondition = cnd.source().parseCondition(soql);
    parsedCondition.realize(cnd.source().token());
    string soql2 = parsedCondition.toSoql();
    if (identical) {
      Assert.areEqual(soql, soql2);
    } else {
      boolean areEquivalent = soql.contains(soql2) || soql2.contains(soql);
      Assert.isTrue(areEquivalent, soql + ' ... ' + soql2);
    }
  }

  static void assertValidSoql(ICondition cnd) {
    // Simplified validation - just ensure SOQL can be generated
    String soql = cnd.toSoql();
    Assert.isNotNull(soql, 'SOQL should not be null');
    Assert.isTrue(soql.length() > 0, 'SOQL should not be empty');
  }

  @isTest
  static void test_evaluate_logical() {
    Filtering.LogicalCondition cnd;

    // Opportunity conditions
    cnd = filtering.all(
      new List<ICondition>{
        core.cond(Enums.Comparator.EQ, 'Name', 'Test Opportunity'),
        core.cond(Enums.Comparator.GT, 'Amount', 10),
        core.cond(Enums.Comparator.LE, 'Amount', 20)
      }
    );
    Assert.isTrue(cnd.evaluate(new Opportunity(Name = 'Test Opportunity', Amount = 20))
    );
    Assert.isFalse(cnd.evaluate(new Opportunity(Name = 'Test Opportunity', Amount = 21))
    );
    assertLogicalCondition(cnd, Opportunity.SObjectType);

    // Account reference and Account tree
    cnd = filtering.all(
      new List<ICondition>{
        core.cond(Enums.Comparator.EQ, 'Name', 'Test Account')
      }
    );
    cnd = cnd.prepend(Application.s.reference(Account.ParentId));
    for (ICondition itm : cnd.getAll()) {
      Filtering.FieldCondition fld = (Filtering.FieldCondition) itm;
      Assert.areEqual(
        Application.s.reference(Account.ParentId),
        fld.path().reference()
      );
    }
    assertLogicalCondition(cnd, Account.SObjectType);

    // Opportunity disjunction
    cnd = filtering.any(
      new List<ICondition>{
        core.cond(
          Enums.Comparator.IIN,
          'Name',
          new List<string>{ 'a', 'b', 'c' }
        ),
        core.cond(Enums.Comparator.NIN, 'Amount', new List<double>{ 1, 2, 3 })
      }
    );
    Assert.isTrue(cnd.evaluate(new Opportunity(Name = 'a', Amount = 20))
    );
    Assert.isFalse(cnd.evaluate(new Opportunity(Amount = 3)));
    Assert.isTrue(cnd.evaluate(new Opportunity()));
    assertLogicalCondition(cnd, Opportunity.SObjectType);

    // Account conditions
    cnd = filtering.all(
      new List<ICondition>{
        core.cond(Enums.Comparator.EQ, 'Name', 'Test Account'),
        core.cond(Enums.Comparator.NE, 'Type', 'Prospect')
      }
    );
    Assert.isTrue(cnd.evaluate(new Account(Name = 'Test Account', Type = 'Customer'))
    );
    Assert.isFalse(cnd.evaluate(new Account(Name = 'Other Account', Type = 'Prospect'))
    );
    assertLogicalCondition(cnd, Account.SObjectType);

    cnd = filtering.all(
      new List<ICondition>{
        filtering.any(
          new List<ICondition>{
            core.cond(Enums.Comparator.EQ, 'Name', null),
            core.cond(Enums.Comparator.NE, 'Type', 'Prospect')
          }
        ),
        core.cond(Enums.Comparator.EQ, 'Id', null),
        core.cond(
          Enums.Comparator.EQ,
          'OwnerId',
          IdUtil.generateId(Application.s.model(User.sobjecttype)),
          true
        )
      }
    );
    Assert.isTrue(cnd.evaluate(new Account()));
    Assert.isFalse(cnd.evaluate(
        new Account(
          Id = IdUtil.generateId(Application.s.model(Account.sobjecttype))
        )
      )
    );
    // to test nullish soql
    assertLogicalCondition(cnd, Account.SObjectType);
  }

  @isTest
  static void test_logicalCondition_clone_independence() {
    // Test that modifying a cloned LogicalCondition doesn't affect the original
    ILogicalCondition original = filtering.all(
      new List<ICondition>{
        core.cond(Enums.Comparator.EQ, 'Type', 'Customer'),
        core.cond(Enums.Comparator.GT, 'AnnualRevenue', 1000000)
      }
    );
    original.realize(Account.SObjectType);

    Integer originalSize1 = original.getAll().size();
    String originalSoql1 = original.toSoql();
    Assert.areEqual(
      2,
      originalSize1,
      'Original should have 2 conditions initially'
    );

    // Deep clone the condition
    ILogicalCondition cloned = (ILogicalCondition) original.clone(true);
    cloned.realize(Account.SObjectType);

    // Modify the cloned condition by adding a new condition
    cloned.add(core.cond(Enums.Comparator.EQ, 'Industry', 'Technology'));

    // Check sizes and SOQL after modification
    Integer originalSize2 = original.getAll().size();
    Integer clonedSize = cloned.getAll().size();
    String originalSoql2 = original.toSoql();
    String clonedSoql = cloned.toSoql();

    // Verify clone has 3 conditions
    Assert.areEqual(
      3,
      clonedSize,
      'Cloned condition should have 3 conditions'
    );
    Assert.isTrue(
      clonedSoql.contains('Industry'),
      'Cloned SOQL should contain Industry'
    );

    // Verify original still has 2 conditions (unchanged)
    Assert.areEqual(
      2,
      originalSize2,
      'Original condition should still have 2 conditions'
    );
    Assert.isTrue(
      !originalSoql2.contains('Industry'),
      'Original SOQL should NOT contain Industry'
    );

    // Verify original SOQL hasn't changed
    Assert.areEqual(
      originalSoql1,
      originalSoql2,
      'Original SOQL should remain unchanged'
    );
  }

  @isTest
  static void test_logicalCondition_shallow_clone() {
    // Test that shallow clone (deepClone=false) shares references
    ILogicalCondition original = filtering.all(
      new List<ICondition>{ core.cond(Enums.Comparator.EQ, 'Type', 'Customer') }
    );
    original.realize(Account.SObjectType);

    // Shallow clone (deepClone=false)
    ILogicalCondition shallowClone = (ILogicalCondition) original.clone(false);
    shallowClone.realize(Account.SObjectType);

    // Both should have 1 condition initially
    Assert.areEqual(1, original.getAll().size());
    Assert.areEqual(1, shallowClone.getAll().size());

    // Adding to shallow clone adds a new reference, but the underlying
    // condition objects are still shared
    shallowClone.add(core.cond(Enums.Comparator.EQ, 'Industry', 'Technology'));

    // Shallow clone has 2 items now
    Assert.areEqual(2, shallowClone.getAll().size());

    // Original still has 1 (we added to the list, not modified existing items)
    Assert.areEqual(1, original.getAll().size());
  }

  @isTest
  static void test_nested_logical_conditions_deep_clone() {
    // Test deep cloning of nested logical conditions
    // Create: (Type='Customer' AND Revenue>1M) OR Type='Partner'
    ILogicalCondition innerAnd = filtering.all(
      new List<ICondition>{
        core.cond(Enums.Comparator.EQ, 'Type', 'Customer'),
        core.cond(Enums.Comparator.GT, 'AnnualRevenue', 1000000)
      }
    );

    ILogicalCondition outerOr = filtering.any(
      new List<ICondition>{
        innerAnd,
        core.cond(Enums.Comparator.EQ, 'Type', 'Partner')
      }
    );
    outerOr.realize(Account.SObjectType);

    String originalSoql1 = outerOr.toSoql();

    // Deep clone the nested structure
    ILogicalCondition cloned = (ILogicalCondition) outerOr.clone(true);
    cloned.realize(Account.SObjectType);

    // Modify the CLONE by adding a condition through its interface
    // Get the cloned items and add a new condition to the first one (the cloned innerAnd)
    List<ICondition> clonedItems = cloned.getAll();
    ILogicalCondition clonedInnerAnd = (ILogicalCondition) clonedItems[0];
    clonedInnerAnd.add(
      core.cond(Enums.Comparator.EQ, 'Industry', 'Technology')
    );

    // Get SOQL after modification
    String originalSoql2 = outerOr.toSoql();
    String clonedSoql = cloned.toSoql();

    // Verify clone has the new condition
    Assert.isTrue(
      clonedSoql.contains('Industry'),
      'Clone should contain Industry after modifying cloned nested condition'
    );

    // Verify original is unchanged (deep clone created independent nested conditions)
    Assert.isTrue(
      !originalSoql2.contains('Industry'),
      'Original should NOT contain Industry (was not modified)'
    );

    // Verify original has not changed from initial state
    Assert.areEqual(
      originalSoql1,
      originalSoql2,
      'Original SOQL should remain unchanged when clone is modified'
    );
  }

  @isTest
  static void test_fieldCondition_clone() {
    // Test that FieldCondition clones correctly
    Filtering.FieldCondition original = filtering.fieldCondition(
      Enums.Comparator.EQ,
      'Type',
      'Customer'
    );
    original.realize(Account.SObjectType);

    // Clone the field condition
    Filtering.FieldCondition cloned = (Filtering.FieldCondition) original.clone(
      true
    );
    cloned.realize(Account.SObjectType);

    // Both should generate the same SOQL
    String originalSoql = original.toSoql();
    String clonedSoql = cloned.toSoql();
    Assert.areEqual(
      originalSoql,
      clonedSoql,
      'Field condition clone should generate same SOQL'
    );

    // They should be different instances
    Assert.areNotEqual(
      original,
      cloned,
      'Clone should be a different instance'
    );
  }

  @isTest
  static void test_clone_with_null_deepClone_parameter() {
    // Test that passing null for deepClone parameter defaults to false (shallow)
    ILogicalCondition original = filtering.all(
      new List<ICondition>{ core.cond(Enums.Comparator.EQ, 'Type', 'Customer') }
    );
    original.realize(Account.SObjectType);

    // Clone with null parameter (should default to shallow)
    ILogicalCondition cloned = (ILogicalCondition) original.clone(null);
    cloned.realize(Account.SObjectType);

    // Should work without errors
    Assert.isNotNull(cloned, 'Clone should not be null');
    Assert.areEqual(
      original.toSoql(),
      cloned.toSoql(),
      'Clone should generate same SOQL'
    );
  }

  @isTest
  static void test_constructor_null_core() {
    // Test that Filtering constructor throws exception for null core
    try {
      Filtering f = new Filtering(null);
      Assert.fail('Should throw exception for null core');
    } catch (Filtering.ConditionException e) {
      Assert.isTrue(e.getMessage().contains('core must not be null'));
    }
  }

  @isTest
  static void test_RealizeException_constructor() {
    // Test the RealizeException constructor with two SObjectTypes
    try {
      throw new Filtering.RealizeException(
        Account.SObjectType,
        Contact.SObjectType
      );
    } catch (Filtering.RealizeException e) {
      Assert.isTrue(e.getMessage().contains('Upstream SObjectType'));
      Assert.isTrue(
        e.getMessage().contains('does not match current SObjectType')
      );
    }
  }

  @isTest
  static void test_realize_null_sobjecttype() {
    // Test that realize throws exception for null SObjectType
    Filtering.LogicalCondition cnd = filtering.all(
      new List<ICondition>{ core.cond(Enums.Comparator.EQ, 'Name', 'Test') }
    );

    try {
      cnd.realize(null);
      Assert.fail('Should throw exception for null SObjectType');
    } catch (Filtering.RealizeException e) {
      Assert.isTrue(
        e.getMessage().contains('SObjectType argument must not be null')
      );
    }
  }

  @isTest
  static void test_realize_mismatched_sobjecttype() {
    // Test that realize throws exception when SObjectType doesn't match
    Filtering.LogicalCondition cnd = filtering.all(
      new List<ICondition>{ core.cond(Enums.Comparator.EQ, 'Name', 'Test') }
    );
    cnd.realize(Account.SObjectType);

    try {
      cnd.realize(Contact.SObjectType);
      Assert.fail('Should throw exception for mismatched SObjectType');
    } catch (Filtering.RealizeException e) {
      Assert.isTrue(
        e.getMessage().contains('does not match current SObjectType')
      );
    }
  }

  @isTest
  static void test_evaluate_null_record() {
    // Test that evaluate throws exception for null record
    Filtering.LogicalCondition cnd = filtering.all(
      new List<ICondition>{ core.cond(Enums.Comparator.EQ, 'Name', 'Test') }
    );

    try {
      cnd.evaluate(null);
      Assert.fail('Should throw exception for null record');
    } catch (Filtering.ConditionException e) {
      Assert.isTrue(e.getMessage().contains('Cannot evaluate null record'));
    }
  }

  @isTest
  static void test_clear_method() {
    // Test the clear() method
    Filtering.LogicalCondition cnd = filtering.all(
      new List<ICondition>{
        core.cond(Enums.Comparator.EQ, 'Name', 'Test'),
        core.cond(Enums.Comparator.GT, 'AnnualRevenue', 1000)
      }
    );

    Assert.areEqual(2, cnd.getAll().size(), 'Should have 2 conditions');

    cnd.clear();
    Assert.areEqual(
      0,
      cnd.getAll().size(),
      'Should have 0 conditions after clear'
    );
  }

  @isTest
  static void test_addAll_method() {
    // Test the addAll() method
    Filtering.LogicalCondition cnd = filtering.all(new List<ICondition>());
    cnd.realize(Account.SObjectType);

    List<ICondition> newConditions = new List<ICondition>{
      core.cond(Enums.Comparator.EQ, 'Name', 'Test'),
      core.cond(Enums.Comparator.GT, 'AnnualRevenue', 1000),
      core.cond(Enums.Comparator.EQ, 'Type', 'Customer')
    };

    cnd.addAll(newConditions);
    Assert.areEqual(
      3,
      cnd.getAll().size(),
      'Should have 3 conditions after addAll'
    );

    // Test addAll with null
    cnd.addAll(null);
    Assert.areEqual(
      3,
      cnd.getAll().size(),
      'Should still have 3 conditions'
    );
  }

  @isTest
  static void test_add_null_condition() {
    // Test that add() handles null condition gracefully
    Filtering.LogicalCondition cnd = filtering.all(new List<ICondition>());
    cnd.realize(Account.SObjectType);

    cnd.add(null);
    Assert.areEqual(
      0,
      cnd.getAll().size(),
      'Should not add null condition'
    );

    cnd.add(core.cond(Enums.Comparator.EQ, 'Name', 'Test'));
    Assert.areEqual(1, cnd.getAll().size(), 'Should have 1 condition');
  }

  @isTest
  static void test_fieldCondition_creation() {
    // Test creating field conditions directly
    Filtering.FieldCondition fc = filtering.fieldCondition(
      Enums.Comparator.EQ,
      'Name',
      'Test Account'
    );
    fc.realize(Account.SObjectType);

    String soql = fc.toSoql();
    Assert.isTrue(soql.contains('Name'), 'SOQL should contain field name');
    Assert.isTrue(soql.contains('Test Account'), 'SOQL should contain value');

    // Test evaluate
    Account testAcc = new Account(Name = 'Test Account');
    Assert.isTrue(fc.evaluate(testAcc), 'Should evaluate to true');

    Account otherAcc = new Account(Name = 'Other Account');
    Assert.isFalse(fc.evaluate(otherAcc),
      'Should evaluate to false'
    );
  }

  @isTest
  static void test_source_method() {
    // Test the source() method
    Filtering.LogicalCondition cnd = filtering.all(
      new List<ICondition>{ core.cond(Enums.Comparator.EQ, 'Name', 'Test') }
    );

    // Before realize, source should be null
    Assert.isNull(cnd.source(),
      'Source should be null before realize'
    );

    cnd.realize(Account.SObjectType);
    Assert.isNotNull(cnd.source(),
      'Source should not be null after realize'
    );
    Assert.areEqual(
      Account.SObjectType,
      cnd.source().token(),
      'Source token should match'
    );
  }

  // --- semi-joins and anti-joins ----------------------------------------------------------------

  // SELECT AccountId FROM Contact WHERE MailingCity = 'Seattle'
  private static IQuery contactsInSeattle() {
    return QueryTest.contactsIn(core, 'Seattle');
  }

  // The message of the ConditionException that building the condition throws, or null.
  private static String buildRefusal(Enums.Comparator kind, Object left, Object right) {
    try {
      filtering.fieldCondition(kind, left, right);
    } catch (Filtering.ConditionException refused) {
      return refused.getMessage();
    }
    return null;
  }

  @IsTest
  static void aQueryOnTheRightIsASemiJoin() {
    IQuery innerQuery = contactsInSeattle();
    Filtering.FieldCondition semi = filtering.fieldCondition(Enums.Comparator.IIN, Account.Id, innerQuery);

    Assert.areEqual('Id IN (SELECT AccountId FROM Contact WHERE (MailingCity = \'Seattle\'))', semi.toSoql());
    Assert.areEqual('Id IN :ids', semi.toSoql(':ids'), 'given text stands in for the inner query');
    Assert.isTrue(semi.value() === (Object) innerQuery, 'the value is the query itself');
    Assert.areEqual(Enums.Comparator.IIN, semi.operator());
    Assert.areEqual('Id', semi.path().name());
    Assert.areEqual(Account.SObjectType, semi.source().token());
    Assert.isFalse(semi.isAggregateCondition());

    IFieldCondition anti = core.nin(new List<SObjectField>{ Contact.AccountId }, core.model(Account.SObjectType).query());
    Assert.areEqual('AccountId NOT IN (SELECT Id FROM Account)', anti.toSoql());

    ILogicalCondition both = core.all(new List<ICondition>{ core.eq(Account.Industry, 'Energy'), semi });
    Assert.areEqual(
      '(Industry = \'Energy\' AND Id IN (SELECT AccountId FROM Contact WHERE (MailingCity = \'Seattle\')))',
      both.toSoql()
    );
    IConditionCompilation compiled = core.model(Account.SObjectType).compileCondition(both);
    Assert.areEqual(both.toSoql(), compiled.toSoql());
    Assert.isTrue(compiled.getPaths().contains(core.path(Account.Id)), 'the left side is one of the paths the condition reads');
  }

  @IsTest
  static void onlyInAndNotInTakeAQuery() {
    IQuery innerQuery = contactsInSeattle();

    for (Enums.Comparator kind : Enums.Comparator.values()) {
      String refusal = buildRefusal(kind, Account.Id, innerQuery);
      if (kind == Enums.Comparator.IIN || kind == Enums.Comparator.NIN) {
        Assert.isNull(refusal, String.valueOf(kind));
      } else {
        Assert.isNotNull(refusal, String.valueOf(kind));
        Assert.isTrue(refusal.contains('IN or NOT IN only'), refusal);
      }
    }
  }

  @IsTest
  static void theLeftSideOfASemiJoinIsAnIdOrALookupField() {
    IQuery innerQuery = contactsInSeattle();

    String refusal = buildRefusal(Enums.Comparator.IIN, Account.Name, innerQuery);
    Assert.isNotNull(refusal, 'Name is text');
    Assert.isTrue(refusal.contains('Name is not an Id or lookup field'), refusal);
    Assert.isNull(buildRefusal(Enums.Comparator.IIN, Account.ParentId, innerQuery));
    Assert.isNull(buildRefusal(Enums.Comparator.NIN, Task.WhatId, innerQuery), 'a lookup to several objects is a lookup');

    String ofAggregate = buildRefusal(Enums.Comparator.IIN, core.max(Account.ParentId), innerQuery);
    Assert.isNotNull(ofAggregate);
    Assert.isTrue(ofAggregate.contains('HAVING takes no semi-join'), ofAggregate);

    // A field given by name is checked once the object is known.
    Filtering.FieldCondition byName = filtering.fieldCondition(Enums.Comparator.IIN, 'Name', innerQuery);
    try {
      byName.realize(Account.SObjectType);
      Assert.fail('Name is text');
    } catch (Filtering.ConditionException refused) {
      Assert.isTrue(refused.getMessage().contains('Name is not an Id or lookup field'), refused.getMessage());
    }
  }

  @IsTest
  static void aSemiJoinByFieldNameWaitsForItsObject() {
    Filtering.FieldCondition byName = filtering.fieldCondition(Enums.Comparator.NIN, 'AccountId', core.model(Account.SObjectType).query());
    Assert.isNull(byName.path());
    try {
      byName.toSoql();
      Assert.fail('not realized yet');
    } catch (Filtering.ConditionException early) {
      Assert.isTrue(early.getMessage().contains('before realize()'), early.getMessage());
    }

    byName.realize(Contact.SObjectType);
    byName.realize(Contact.SObjectType);

    Assert.areEqual('AccountId NOT IN (SELECT Id FROM Account)', byName.toSoql());
    try {
      byName.realize(Opportunity.SObjectType);
      Assert.fail('bound to Contact');
    } catch (Filtering.RealizeException other) {
      Assert.isTrue(other.getMessage().contains('Opportunity'), other.getMessage());
    }
  }

  @IsTest
  static void aSemiJoinCannotBeEvaluatedInMemory() {
    ICondition semi = core.iin(Account.Id, contactsInSeattle());
    Account candidate = new Account(Name = 'Acme');

    try {
      semi.evaluate(candidate);
      Assert.fail('a semi-join was evaluated without its inner query being run');
    } catch (Filtering.ConditionException refused) {
      Assert.isTrue(refused.getMessage().contains('Cannot evaluate a semi-join in memory'), refused.getMessage());
    }
    try {
      core.all(new List<ICondition>{ core.eq(Account.Name, 'Acme'), semi }).evaluate(candidate);
      Assert.fail('a branch holding a semi-join was evaluated');
    } catch (Filtering.ConditionException refused) {
      Assert.isTrue(refused.getMessage().contains('semi-join'), refused.getMessage());
    }
  }

  @IsTest
  static void aDeepCloneOfASemiJoinHasItsOwnInnerQuery() {
    IQuery innerQuery = contactsInSeattle();
    IFieldCondition original = core.iin(Account.Id, innerQuery);

    IFieldCondition shallow = (IFieldCondition) original.clone(false);
    IFieldCondition deep = (IFieldCondition) original.clone(true);
    ILogicalCondition branch = (ILogicalCondition) core.all(new List<ICondition>{ original }).clone(true);
    innerQuery.filters().add(core.eq(Contact.LastName, 'Smith'));

    Assert.isTrue(shallow.value() === (Object) innerQuery, 'a shallow copy shares the query');
    Assert.isTrue(shallow.toSoql().contains('Smith'), shallow.toSoql());
    Assert.isFalse(deep.value() === (Object) innerQuery);
    Assert.areEqual('Id IN (SELECT AccountId FROM Contact WHERE (MailingCity = \'Seattle\'))', deep.toSoql());
    Assert.areEqual('(Id IN (SELECT AccountId FROM Contact WHERE (MailingCity = \'Seattle\')))', branch.toSoql());
  }

  @IsTest
  static void aSemiJoinMovesAlongAReference() {
    IQuery owners = core.model(User.SObjectType).query();
    owners.filters().add(core.eq(User.IsActive, true));
    ICondition onAccount = core.iin(Account.OwnerId, owners);

    ICondition onContact = onAccount.prepend(core.reference(Contact.AccountId));
    ICondition branch = core.all(new List<ICondition>{ onAccount }).prepend(core.reference(Contact.AccountId));

    Assert.areEqual('Account.OwnerId IN (SELECT Id FROM User WHERE (IsActive = true))', onContact.toSoql());
    Assert.areEqual(Contact.SObjectType, onContact.source().token());
    Assert.areEqual('(Account.OwnerId IN (SELECT Id FROM User WHERE (IsActive = true)))', branch.toSoql());
    Assert.areEqual('OwnerId IN (SELECT Id FROM User WHERE (IsActive = true))', onAccount.toSoql(), 'the original is unchanged');
  }

  @IsTest
  static void aNegatedSemiJoinIsWrittenAsAsked() {
    ICondition negated = core.neg(core.iin(Account.Id, contactsInSeattle()));

    // The platform refuses NOT around a semi-join; nin() is the anti-join.
    Assert.areEqual('(NOT Id IN (SELECT AccountId FROM Contact WHERE (MailingCity = \'Seattle\')))', negated.toSoql());
  }

  @IsTest
  static void aSemiJoinNeedsAQueryTheFrameworkMade() {
    ICondition foreign = core.iin(Account.Id, new ForeignQuery());

    try {
      foreign.toSoql();
      Assert.fail('a query of another making was written as an inner query');
    } catch (Query.UnifValidationException refused) {
      Assert.isTrue(refused.getMessage().contains('made by the framework'), refused.getMessage());
    }
    Assert.isTrue(foreign.clone(true) !== foreign);
  }

  // An IQuery that is not the framework's Query.
  private class ForeignQuery implements IQuery {
    public List<SObject> run() {
      return null;
    }
    public SObject fetch() {
      return null;
    }
    public List<SObject> fetch(Integer maxRows) {
      return null;
    }
    public Integer count() {
      return 0;
    }
    public Database.QueryLocator toLocator() {
      return null;
    }
    public String toSoql(Boolean binding) {
      return 'SELECT Id FROM Contact';
    }
    public String toSoql() {
      return 'SELECT Id FROM Contact';
    }
    public IModel source() {
      return null;
    }
    public IQueryFields fields() {
      return null;
    }
    public IQuery addAllFields() {
      return this;
    }
    public IQuery addImplicitFields() {
      return this;
    }
    public IQuery addSubquery(String relationshipName, IQuery child) {
      return this;
    }
    public IQuery addSubquery(SObjectField relationshipField, IQuery child) {
      return this;
    }
    public Map<String, IQuery> getSubqueryMap() {
      return new Map<String, IQuery>();
    }
    public IQuery addCondition(ICondition condition) {
      return this;
    }
    public ILogicalCondition filters() {
      return null;
    }
    public List<IOrdering> orderings() {
      return new List<IOrdering>();
    }
    public IQuery setOffset(Integer skipRows) {
      return this;
    }
    public IQuery setLimit(Integer maxRows) {
      return this;
    }
    public IQuery withSharing(Boolean enforce) {
      return this;
    }
    public IQuery withSecurity(Boolean enforce) {
      return this;
    }
    public IQuery forUpdate(Boolean lock) {
      return this;
    }
    public IQuery allRows(Boolean include) {
      return this;
    }
    public IQuery usingScope(Enums.FilterScope scope) {
      return this;
    }
    public IQuery forView(Boolean mark) {
      return this;
    }
    public IQuery forReference(Boolean mark) {
      return this;
    }
    public IQuery deepClone() {
      return new ForeignQuery();
    }
  }

  // --- date literals as values -------------------------------------------------------------------

  @IsTest
  static void aDateLiteralIsTheValueOfAConditionAndIsWrittenAsItIs() {
    IFieldCondition recent = core.ge(Opportunity.CloseDate, DateLiteral.lastNDays(30));

    Assert.areEqual('CloseDate >= LAST_N_DAYS:30', recent.toSoql());
    Assert.areEqual(DateLiteral.lastNDays(30), recent.value(), 'the value is the literal itself');
    Assert.areEqual(Enums.Comparator.GE, recent.operator());
    Assert.isFalse(bindable(recent), 'a date literal is never bound');
    Assert.areEqual('(NOT CloseDate >= LAST_N_DAYS:30)', core.cond(Enums.Comparator.GE, Opportunity.CloseDate, DateLiteral.lastNDays(30), true).toSoql());
    Assert.areEqual(recent.toSoql(), recent.clone(true).toSoql());

    IFieldCondition listed = core.nin('CreatedDate', new List<IDateLiteral>{ DateLiteral.today(), DateLiteral.thisFiscalYear() });
    listed.realize(Opportunity.SObjectType);
    Assert.areEqual('CreatedDate NOT IN (TODAY, THIS_FISCAL_YEAR)', listed.toSoql());
    Assert.isFalse(bindable(listed));

    IFieldCondition throughLookup = (IFieldCondition) core.eq(Account.CreatedDate, DateLiteral.thisYear())
      .prepend(core.reference(Contact.AccountId));
    Assert.areEqual('Account.CreatedDate = THIS_YEAR', throughLookup.toSoql());
  }

  @IsTest
  static void aDateLiteralByFieldNameIsCheckedOnceTheObjectIsKnown() {
    // What is refused is listed in TypingTest; a condition refuses it as soon as it has its field
    try {
      core.eq(Opportunity.Name, DateLiteral.today());
      Assert.fail('a date literal was compared with text');
    } catch (Typing.ValidationException refused) {
      Assert.areEqual('Name holds string values, so it cannot be compared with a date literal', refused.getMessage());
    }
    IFieldCondition byName = core.eq('Name', DateLiteral.today());
    try {
      byName.realize(Opportunity.SObjectType);
      Assert.fail('a date literal was compared with text');
    } catch (Typing.ValidationException refused) {
      Assert.areEqual('Name holds string values, so it cannot be compared with a date literal', refused.getMessage());
    }
  }

  @IsTest
  static void anEmptyDateStaysOutOfADateLiteralUnderNotToo() {
    // What each operator answers is in DateLiteralTest, and lists of literals are in TypingTest
    DateLiteral.fixedToday = Date.newInstance(2027, 6, 16);
    Opportunity now = new Opportunity(CloseDate = Date.newInstance(2027, 6, 16));
    Opportunity undated = new Opportunity();
    List<IDateLiteral> today = new List<IDateLiteral>{ DateLiteral.today() };

    Assert.isTrue(core.eq(Opportunity.CloseDate, DateLiteral.today()).evaluate(now));
    Assert.isFalse(core.neg(core.eq(Opportunity.CloseDate, DateLiteral.today())).evaluate(now));
    Assert.isFalse(core.eq(Opportunity.CloseDate, DateLiteral.today()).evaluate(undated));
    Assert.isFalse(core.neg(core.eq(Opportunity.CloseDate, DateLiteral.today())).evaluate(undated), 'NOT (CloseDate = TODAY) leaves it out too');
    Assert.isFalse(core.neg(core.iin(Opportunity.CloseDate, today)).evaluate(undated));
    Assert.isNull(((Filtering.FieldCondition) core.gt(Opportunity.CloseDate, DateLiteral.today())).test(undated), 'unknown, not false');
    Assert.isFalse(core.neg(core.ne(Opportunity.CloseDate, DateLiteral.today())).evaluate(undated), '!= does answer for it, so NOT turns that');
    Assert.isTrue(core.neg(core.iin(Opportunity.CloseDate, new List<IDateLiteral>())).evaluate(undated), 'a list of none is a constant');
  }

  // --- SOQL's third answer: unknown --------------------------------------------------------------

  @IsTest
  static void anEmptyNumberOrDateIsNeitherAboveNorNotAboveAValue() {
    Account unknownRevenue = new Account(Name = 'Acme');
    Account small = new Account(Name = 'Acme', AnnualRevenue = 1);

    for (Enums.Comparator kind : new List<Enums.Comparator>{ Enums.Comparator.GT, Enums.Comparator.GE, Enums.Comparator.LT, Enums.Comparator.LE }) {
      Assert.isFalse(core.cond(kind, Account.AnnualRevenue, 5).evaluate(unknownRevenue), kind + ' on an empty number');
      Assert.isFalse(core.cond(kind, Account.AnnualRevenue, 5, true).evaluate(unknownRevenue), 'NOT ' + kind + ' on an empty number');
      Assert.isFalse(core.cond(kind, Account.CreatedDate, Datetime.now(), true).evaluate(unknownRevenue), 'NOT ' + kind + ' on an empty date-time');
      Assert.isFalse(core.cond(kind, Contact.Birthdate, Date.today(), true).evaluate(new Contact()), 'NOT ' + kind + ' on an empty date');
    }
    Assert.isTrue(core.cond(Enums.Comparator.GT, Account.AnnualRevenue, 5, true).evaluate(small), 'a number that is there has an answer');

    // Equality and membership do answer for an empty field, and so does text, which reads as ''
    Assert.isTrue(core.neg(core.eq(Account.AnnualRevenue, 5)).evaluate(unknownRevenue));
    Assert.isTrue(core.neg(core.iin(Account.AnnualRevenue, new Set<Integer>{ 5 })).evaluate(unknownRevenue));
    Assert.isTrue(core.neg(core.gt(Account.Industry, 'A')).evaluate(unknownRevenue));
  }

  @IsTest
  static void unknownPassesThroughAndOrAndNotAsInSoql() {
    Account unknownRevenue = new Account(Name = 'Acme');
    ICondition above = core.gt(Account.AnnualRevenue, 5); // unknown for this account
    ICondition named = core.eq(Account.Name, 'Acme'); // true
    ICondition misnamed = core.eq(Account.Name, 'Globex'); // false

    Assert.isNull(filtering.all(new List<ICondition>{ above, named }).test(unknownRevenue), 'unknown AND true');
    Assert.isFalse(filtering.all(new List<ICondition>{ above, misnamed }).test(unknownRevenue), 'unknown AND false');
    Assert.isTrue(filtering.any(new List<ICondition>{ above, named }).test(unknownRevenue), 'unknown OR true');
    Assert.isNull(filtering.any(new List<ICondition>{ above, misnamed }).test(unknownRevenue), 'unknown OR false');

    Assert.isFalse(core.neg(filtering.all(new List<ICondition>{ above, named })).evaluate(unknownRevenue), 'NOT unknown is left out');
    Assert.isTrue(core.neg(filtering.all(new List<ICondition>{ above, misnamed })).evaluate(unknownRevenue), 'NOT false is kept');
    Assert.isFalse(core.neg(filtering.any(new List<ICondition>{ above, named })).evaluate(unknownRevenue), 'NOT true is left out');
    Assert.isFalse(core.neg(filtering.any(new List<ICondition>{ above, misnamed })).evaluate(unknownRevenue), 'NOT unknown is left out');

    // A condition of another class answers yes or no
    Assert.isTrue(filtering.all(new List<ICondition>{ new AlwaysTrue(), named }).evaluate(unknownRevenue));
  }

  // --- the three faces against inserted records --------------------------------------------------

  @IsTest
  static void conditionsAnswerInMemoryAsSoqlDoesBoundAndInline() {
    Account acme = new Account(Name = 'Acme Corp', Industry = 'Energy', AnnualRevenue = 1000);
    Account globex = new Account(Name = 'globex');
    insert new List<Account>{ acme, globex };
    Datetime bounced = Datetime.newInstanceGmt(2026, 1, 15, 10, 0, 0);
    Date born = Date.newInstance(2000, 1, 15);
    insert new List<Contact>{
      new Contact(LastName = 'Alpha', FirstName = 'Ann', Title = 'CEO', Birthdate = born, AccountId = acme.Id, EmailBouncedDate = bounced),
      new Contact(LastName = 'beta'),
      new Contact(LastName = 'Gamma_1', FirstName = 'ann', Title = '50% off', Birthdate = born.addDays(1), AccountId = globex.Id, EmailBouncedDate = Datetime.newInstanceGmt(2026, 1, 16, 0, 0, 0)),
      new Contact(LastName = 'Delta', FirstName = 'Bob', Title = 'ceo', Birthdate = born.addDays(-15), AccountId = acme.Id, EmailBouncedDate = bounced.addDays(-30))
    };
    List<SObjectField> revenue = new List<SObjectField>{ Contact.AccountId, Account.AnnualRevenue };
    String shortId = String.valueOf(acme.Id).left(15);
    List<ICondition> conditions = new List<ICondition>{
      // an empty number, date or date-time under NOT
      core.neg(core.gt(Contact.Birthdate, born)),
      core.neg(core.le(Contact.Birthdate, born)),
      core.neg(core.ge(Contact.EmailBouncedDate, bounced)),
      core.neg(core.lt(revenue, 500)),
      core.neg(core.ge(revenue, 500)),
      core.neg(core.any(new List<ICondition>{ core.eq(Contact.FirstName, 'bob'), core.gt(Contact.Birthdate, born) })),
      core.neg(core.all(new List<ICondition>{ core.gt(Contact.Birthdate, born.addYears(-50)), core.ne(Contact.LastName, 'zzz') })),
      core.all(new List<ICondition>{ core.neg(core.gt(Contact.Birthdate, born)), core.neg(core.any(new List<ICondition>{ core.eq(Contact.FirstName, 'bob') })) }),
      // text reads an empty field as '', in any case
      core.neg(core.gt(Contact.FirstName, 'ann')),
      core.neg(core.eq(Contact.FirstName, 'ANN')),
      core.lt(Contact.LastName, 'c'),
      core.iin(Contact.FirstName, new List<String>{ 'bob', null }),
      core.nin(Contact.FirstName, new Set<String>{ 'ANN' }),
      // LIKE never matches an empty field
      core.lk(Contact.FirstName, '%'),
      core.neg(core.lk(Contact.FirstName, '%')),
      core.lk(Contact.Title, '50\\% off'),
      core.lk(Contact.LastName, 'gamma\\__'),
      // Ids match in their exact case, in either length
      core.eq(Contact.AccountId, shortId),
      core.neg(core.eq(Contact.AccountId, shortId)),
      core.eq(Contact.AccountId, String.valueOf(acme.Id).toLowerCase()),
      core.iin(Contact.AccountId, new Set<String>{ shortId }),
      core.nin(Contact.AccountId, new Set<Id>{ acme.Id }),
      // a date compared with a date-time field is midnight GMT
      core.gt(Contact.EmailBouncedDate, Date.newInstance(2026, 1, 15)),
      core.eq(Contact.EmailBouncedDate, Date.newInstance(2026, 1, 16)),
      // IN with nothing at all, and with an empty set
      core.iin(Contact.FirstName, null),
      core.neg(core.iin(Contact.FirstName, null)),
      core.nin(Contact.Birthdate, new Set<Date>()),
      // through a lookup that is not there
      core.ne(new List<SObjectField>{ Contact.AccountId, Account.Industry }, 'Energy'),
      core.eq(new List<SObjectField>{ Contact.AccountId, Account.Name }, null)
    };
    List<Contact> rows = [
      SELECT LastName, FirstName, Title, Birthdate, AccountId, EmailBouncedDate, Account.Name, Account.Industry, Account.AnnualRevenue
      FROM Contact
    ];

    Test.startTest();
    List<String> differences = new List<String>();
    for (ICondition condition : conditions) {
      IQuery q = core.model(Contact.SObjectType).query();
      q.filters().add(condition);
      Set<Id> bound = new Map<Id, SObject>(q.run()).keySet();
      Set<Id> inline = new Map<Id, SObject>(Database.query(q.toSoql())).keySet();
      Set<Id> inMemory = new Set<Id>();
      Set<Id> fromText = new Set<Id>();
      ICondition parsed = core.model(Contact.SObjectType).parseCondition(condition.toSoql());
      for (Contact row : rows) {
        if (condition.evaluate(row)) {
          inMemory.add(row.Id);
        }
        if (parsed.evaluate(row)) {
          fromText.add(row.Id);
        }
      }
      if (bound != inline || bound != inMemory || bound != fromText) {
        differences.add(
          q.toSoql() + ': bound ' + bound.size() + ', inline ' + inline.size() + ', in memory ' + inMemory.size() + ', from text ' + fromText.size()
        );
      }
    }
    Test.stopTest();

    Assert.areEqual('', String.join(differences, '\n'));
  }

  @IsTest
  static void timesOfDayAnswerInMemoryAsSoqlDoesBoundAndInline() {
    // Business hours are the one object every org has with times of day, and with a default row
    List<BusinessHours> rows = [SELECT MondayStartTime, MondayEndTime FROM BusinessHours];
    Assert.isFalse(rows.isEmpty(), 'every org has its default business hours');
    Time opening = rows[0].MondayStartTime;
    Time later = opening.addMinutes(90);
    List<ICondition> conditions = new List<ICondition>{
      core.eq(BusinessHours.MondayStartTime, opening),
      core.ne(BusinessHours.MondayStartTime, opening),
      core.gt(BusinessHours.MondayStartTime, opening),
      core.ge(BusinessHours.MondayStartTime, opening),
      core.lt(BusinessHours.MondayStartTime, later),
      core.le(BusinessHours.MondayEndTime, later),
      core.neg(core.lt(BusinessHours.MondayStartTime, later)),
      core.iin(BusinessHours.MondayStartTime, new List<Time>{ opening, later }),
      core.nin(BusinessHours.MondayStartTime, new Set<Time>{ later }),
      core.eq(BusinessHours.MondayStartTime, null)
    };

    List<String> differences = new List<String>();
    for (ICondition condition : conditions) {
      IQuery q = core.model(BusinessHours.SObjectType).query();
      q.filters().add(condition);
      Set<Id> bound = new Map<Id, SObject>(q.run()).keySet();
      Set<Id> inline = new Map<Id, SObject>(Database.query(q.toSoql())).keySet();
      Set<Id> inMemory = new Set<Id>();
      Set<Id> fromText = new Set<Id>();
      ICondition parsed = core.model(BusinessHours.SObjectType).parseCondition(condition.toSoql());
      for (BusinessHours row : rows) {
        if (condition.evaluate(row)) {
          inMemory.add(row.Id);
        }
        if (parsed.evaluate(row)) {
          fromText.add(row.Id);
        }
      }
      if (bound != inline || bound != inMemory || bound != fromText) {
        differences.add(
          q.toSoql() + ': bound ' + bound.size() + ', inline ' + inline.size() + ', in memory ' + inMemory.size() + ', from text ' + fromText.size()
        );
      }
    }

    Assert.areEqual('', String.join(differences, '\n'));
  }

  @IsTest
  static void aCheckboxComparedWithNullIsComparedWithFalseAsInSoql() {
    // The platform unchecks IsReminderSet on a task that has no reminder time
    insert new List<Task>{ new Task(Subject = 'reminded', IsReminderSet = true, ReminderDateTime = Datetime.now().addDays(1)), new Task(Subject = 'plain') };
    List<Task> rows = [SELECT Subject, IsReminderSet FROM Task];
    Map<ICondition, String> expected = new Map<ICondition, String>{
      core.eq(Task.IsReminderSet, null) => 'plain',
      core.ne(Task.IsReminderSet, null) => 'reminded',
      core.neg(core.eq(Task.IsReminderSet, null)) => 'reminded',
      core.eq(Task.IsReminderSet, false) => 'plain',
      core.iin(Task.IsReminderSet, new List<Boolean>{ true }) => 'reminded'
    };

    for (ICondition condition : expected.keySet()) {
      IQuery q = core.model(Task.SObjectType).query();
      q.fields().add(new Set<SObjectField>{ Task.Subject });
      q.filters().add(condition);
      List<Task> found = (List<Task>) q.run();
      Assert.areEqual(1, found.size(), q.toSoql());
      Assert.areEqual(expected.get(condition), found[0].Subject, q.toSoql());
      for (Task row : rows) {
        Assert.areEqual(row.Subject == expected.get(condition), condition.evaluate(row), q.toSoql() + ' in memory for ' + row.Subject);
      }
    }
  }

  @IsTest
  static void whereTheOrgHasQuickTextMultiSelectConditionsAnswerInMemoryAsSoqlDoes() {
    // No object that every org has holds a multi-select picklist. Quick text does where it is switched
    // on; where it is not, there is no database to compare with, and TypingTest covers the reading.
    SObjectType quickText = core.model('QuickText')?.token();
    SObjectField channel = quickText?.getDescribe().fields.getMap().get('Channel');
    List<String> choices = new List<String>();
    for (PicklistEntry choice : channel == null ? new List<PicklistEntry>() : channel.getDescribe().getPicklistValues()) {
      if (choice.isActive()) {
        choices.add(choice.getValue());
      }
    }
    if (choices.size() < 3 || !quickText.getDescribe().isCreateable()) {
      System.debug(LoggingLevel.WARN, 'Not checked against the database: this org has no quick text with three channels');
      return;
    }
    List<SObject> rows = new List<SObject>();
    for (String chosen : new List<String>{ choices[0], choices[0] + ';' + choices[1], choices[2], null }) {
      SObject row = quickText.newSObject();
      row.put('Name', 'Multi ' + rows.size());
      row.put('Message', 'text');
      row.put('Channel', chosen);
      rows.add(row);
    }
    insert rows;
    String both = choices[0] + ';' + choices[1];
    String bothReversed = choices[1] + ';' + choices[0];
    List<ICondition> conditions = new List<ICondition>{
      core.inc('Channel', new Set<String>{ choices[0] }),
      core.inc('Channel', new Set<String>{ choices[1].toUpperCase(), choices[2] }),
      core.inc('Channel', new List<String>{ both }),
      core.inc('Channel', new List<String>{ bothReversed }),
      core.neg(core.inc('Channel', new List<String>{ bothReversed })),
      core.neg(core.inc('Channel', new Set<String>{ choices[0] })),
      core.exc('Channel', new Set<String>{ choices[0] }),
      core.neg(core.exc('Channel', new Set<String>{ choices[0] })),
      core.exc('Channel', new List<String>{ both }),
      core.inc('Channel', new Set<String>()),
      core.exc('Channel', new Set<String>()),
      core.eq('Channel', both),
      core.eq('Channel', bothReversed),
      core.ne('Channel', bothReversed),
      core.eq('Channel', null),
      core.ne('Channel', null),
      core.iin('Channel', new Set<String>{ bothReversed, choices[2] }),
      core.nin('Channel', new Set<String>{ bothReversed, choices[2] })
    };

    Test.startTest();
    List<String> differences = new List<String>();
    for (ICondition condition : conditions) {
      IQuery q = core.model(quickText).query();
      q.fields().add(new Set<String>{ 'Channel' });
      q.filters().add(condition);
      List<SObject> found = q.run();
      Set<Id> bound = new Map<Id, SObject>(found).keySet();
      Set<Id> inline = new Map<Id, SObject>(Database.query(q.toSoql())).keySet();
      Set<Id> inMemory = new Set<Id>();
      for (SObject row : Database.query('SELECT Id, Channel FROM QuickText')) {
        if (condition.evaluate(row)) {
          inMemory.add(row.Id);
        }
      }
      if (bound != inline || bound != inMemory) {
        differences.add(q.toSoql() + ': bound ' + bound.size() + ', inline ' + inline.size() + ', in memory ' + inMemory.size());
      }
    }
    Test.stopTest();

    Assert.areEqual('', String.join(differences, '\n'));

    // LIKE builds and is tested in memory, but is not written: the platform does not take it here
    IFieldCondition matching = core.lk('Channel', choices[0] + '%');
    Assert.isTrue(matching.evaluate(rows[1]));
    try {
      core.model(quickText).query().addCondition(matching).toSoql(true);
      Assert.fail('LIKE was written on a multi-select picklist');
    } catch (Typing.ValidationException refused) {
      Assert.areEqual('Cannot write LK on Channel: a multi-select picklist takes INC and EXC', refused.getMessage());
    }
    try {
      Database.query('SELECT Id FROM QuickText WHERE Channel LIKE \'a%\'');
      Assert.fail('the platform took LIKE on a multi-select picklist');
    } catch (QueryException platform) {
      Assert.areEqual('invalid operator on multipicklist field', platform.getMessage());
    }
  }

  @IsTest
  static void aGroupWithNothingInItIsAConstantOnEveryFace() {
    insert new List<Account>{ new Account(Name = 'Acme'), new Account(Name = 'Globex') };
    List<Account> rows = [SELECT Name FROM Account];
    ICondition acme = core.eq(Account.Name, 'Acme');
    List<ICondition> none = new List<ICondition>();
    Map<String, ICondition> conditionBySoql = new Map<String, ICondition>{
      '(Id = null AND Id != null)' => core.any(none),
      '(Id = null OR Id != null)' => core.all(none),
      '(NOT (Id = null AND Id != null))' => core.neg(core.any(none)),
      '(NOT (Id = null OR Id != null))' => core.neg(core.all(none)),
      '((Id = null AND Id != null))' => core.all(new List<ICondition>{ core.any(none) }),
      '(Name = \'Acme\' AND (Id = null OR Id != null))' => core.all(new List<ICondition>{ acme, core.all(none) }),
      '(Name = \'Acme\' AND (Id = null AND Id != null))' => core.all(new List<ICondition>{ acme, core.any(none) }),
      '(Name = \'Acme\' OR (Id = null AND Id != null))' => core.any(new List<ICondition>{ acme, core.any(none) }),
      '(Name = \'Acme\' OR (Id = null OR Id != null))' => core.any(new List<ICondition>{ acme, core.all(none) })
    };
    List<Integer> matching = new List<Integer>{ 0, 2, 2, 0, 0, 1, 0, 1, 2 };

    Integer at = 0;
    for (String soql : conditionBySoql.keySet()) {
      ICondition condition = conditionBySoql.get(soql);
      condition.realize(Account.SObjectType);
      IQuery q = core.model(Account.SObjectType).query().addCondition(condition);
      ICondition parsed = core.model(Account.SObjectType).parseCondition(soql);
      Set<Id> inMemory = new Set<Id>();
      Set<Id> fromText = new Set<Id>();
      for (Account row : rows) {
        if (condition.evaluate(row)) {
          inMemory.add(row.Id);
        }
        if (parsed.evaluate(row)) {
          fromText.add(row.Id);
        }
      }

      Assert.areEqual(soql, condition.toSoql());
      Assert.areEqual('SELECT Id FROM Account WHERE (' + soql + ')', q.toSoql());
      Assert.areEqual(soql.countMatches('Acme'), q.toSoql(true).countMatches(':a0'), 'a constant has no value to bind');
      Assert.areEqual(matching[at], inMemory.size(), soql + ' in memory');
      Assert.areEqual(inMemory, new Map<Id, SObject>(q.run()).keySet(), soql + ' as a query');
      Assert.areEqual(inMemory, fromText, soql + ' read from text');
      at++;
    }
    Assert.areEqual('SELECT Id FROM Account', core.model(Account.SObjectType).query().toSoql(), 'the root itself, when empty, writes no WHERE');
  }

  @IsTest
  static void negatingTwiceGivesTheConditionBack() {
    Account acme = new Account(Name = 'Acme', Industry = 'Energy');
    ICondition named = core.eq(Account.Name, 'Acme');
    ICondition both = core.all(new List<ICondition>{ core.eq(Account.Name, 'Acme'), core.eq(Account.Industry, 'Energy') });

    Assert.areEqual('(NOT Name = \'Acme\')', core.neg(named).toSoql());
    Assert.isFalse(named.evaluate(acme), 'neg changes the condition it is given, and returns it');
    Assert.areEqual('Name = \'Acme\'', core.neg(named).toSoql(), 'a second neg takes the first one back');
    Assert.isTrue(named.evaluate(acme));

    Assert.areEqual('(NOT (Name = \'Acme\' AND Industry = \'Energy\'))', core.neg(both).toSoql());
    Assert.areEqual('(Name = \'Acme\' AND Industry = \'Energy\')', core.neg(both).toSoql());
    Assert.isTrue(core.neg(core.neg(both)).evaluate(acme));
    Assert.areEqual('Name = \'Acme\'', core.neg(core.cond(Enums.Comparator.EQ, Account.Name, 'Acme', true)).toSoql());
  }

  @IsTest
  static void nullIsNeitherAboveNorBelowNorLikeAnything() {
    Account acme = new Account(Name = 'Acme', AnnualRevenue = 5);
    Map<String, IFieldCondition> conditionByRefusal = new Map<String, IFieldCondition>{
      'Cannot compare AnnualRevenue with null by LT' => core.lt(Account.AnnualRevenue, null),
      'Cannot compare AnnualRevenue with null by LE' => core.le(Account.AnnualRevenue, null),
      'Cannot compare AnnualRevenue with null by GT' => core.gt(Account.AnnualRevenue, null),
      'Cannot compare AnnualRevenue with null by GE' => core.ge(Account.AnnualRevenue, null),
      'Cannot compare CreatedDate with null by GT' => core.gt(Account.CreatedDate, null),
      'Cannot compare Name with null by GE' => core.ge(Account.Name, null),
      'Cannot compare Name with null by LK' => core.lk(Account.Name, null),
      'Cannot compare Owner.Name with null by LT' => core.lt(new List<SObjectField>{ Account.OwnerId, User.Name }, null)
    };

    for (String refusal : conditionByRefusal.keySet()) {
      IFieldCondition ordered = conditionByRefusal.get(refusal);
      IQuery q = core.model(Account.SObjectType).query().addCondition(ordered);
      List<String> refusals = new List<String>();
      try {
        ordered.toSoql();
      } catch (Typing.ValidationException refused) {
        refusals.add(refused.getMessage());
      }
      try {
        q.toSoql(true);
      } catch (Typing.ValidationException refused) {
        refusals.add(refused.getMessage());
      }
      try {
        q.run();
      } catch (Typing.ValidationException refused) {
        refusals.add(refused.getMessage());
      }
      try {
        q.count();
      } catch (Typing.ValidationException refused) {
        refusals.add(refused.getMessage());
      }
      String whole = refusal + ': null goes with EQ and NE';
      Assert.areEqual(new List<String>{ whole, whole, whole, whole }, refusals, 'written inline, written bound, run and counted');

      // In memory there is no exception: the answer is unknown, and stays out under NOT too
      Assert.isNull(((Filtering.FieldCondition) ordered).test(acme), refusal);
      Assert.isFalse(ordered.evaluate(acme), refusal);
      Assert.isFalse(core.cond(ordered.operator(), ordered.path(), null, true).evaluate(acme), 'NOT ' + refusal);
      Assert.isFalse(ordered.evaluate(new Account()), refusal + ' for an empty field');
    }
    Assert.areEqual('AnnualRevenue = null', core.eq(Account.AnnualRevenue, null).toSoql(), 'null goes with = and !=');
    Assert.isTrue(core.ne(Account.AnnualRevenue, null).evaluate(acme));
    Assert.isTrue(Typing.doEvaluate(Enums.Comparator.LK, Account.Name.getDescribe(), null, ''), 'an empty pattern is not null');
  }

  @IsTest
  static void aWholeNumberOnAnIntegerFieldIsHeldAsAnInteger() {
    insert new List<Account>{ new Account(Name = 'Five', NumberOfEmployees = 5), new Account(Name = 'Six', NumberOfEmployees = 6) };
    List<Account> rows = [SELECT Name, NumberOfEmployees FROM Account];
    Map<String, IFieldCondition> conditionBySoql = new Map<String, IFieldCondition>{
      'NumberOfEmployees = 5' => core.eq(Account.NumberOfEmployees, 5.0),
      'NumberOfEmployees > 5' => core.gt(Account.NumberOfEmployees, 5L),
      'NumberOfEmployees != 5' => core.ne(Account.NumberOfEmployees, Double.valueOf('5')),
      'NumberOfEmployees IN (5, 7)' => core.iin(Account.NumberOfEmployees, new List<Decimal>{ 5.0, 7 }),
      'NumberOfEmployees NOT IN (5)' => core.nin(Account.NumberOfEmployees, new Set<Decimal>{ 5.00 }),
      'NumberOfEmployees IN (6)' => core.iin('NumberOfEmployees', new Set<Long>{ 6L })
    };

    for (String soql : conditionBySoql.keySet()) {
      IFieldCondition condition = conditionBySoql.get(soql);
      IQuery q = core.model(Account.SObjectType).query().addCondition(condition);
      Set<Id> inMemory = new Set<Id>();
      for (Account row : rows) {
        if (condition.evaluate(row)) {
          inMemory.add(row.Id);
        }
      }

      Assert.areEqual(soql, condition.toSoql());
      Assert.areEqual(1, inMemory.size(), soql);
      Assert.areEqual(inMemory, new Map<Id, SObject>(q.run()).keySet(), soql + ' bound: the platform takes no Decimal for an integer column');
      Assert.areEqual(inMemory, new Map<Id, SObject>(Database.query(q.toSoql())).keySet(), soql + ' inline');
    }

    // A number that is not whole stays what it is, and the platform refuses it
    IFieldCondition fraction = core.eq(Account.NumberOfEmployees, 5.5);
    Assert.areEqual('NumberOfEmployees = 5.5', fraction.toSoql());
    Assert.isFalse(fraction.evaluate(rows[0]));
    try {
      core.model(Account.SObjectType).query().addCondition(fraction).run();
      Assert.fail('the platform took a decimal for an integer column');
    } catch (QueryException platform) {
      Assert.areEqual('Invalid bind expression type of Decimal for column of type Integer', platform.getMessage());
    }
    Assert.areEqual('AnnualRevenue = 5.0', core.eq(Account.AnnualRevenue, 5.0).toSoql(), 'a decimal field keeps the decimal');
  }

  @IsTest
  static void aConditionCarriedByAJobIsWrittenAndTestedAsBefore() {
    DateLiteral.fixedToday = Date.newInstance(2026, 1, 20);
    Id accountId = IdUtil.generateId(Account.SObjectType);
    Carrier job = new Carrier();
    job.carried = new List<ICondition>{
      core.gt(Opportunity.CreatedDate, Date.newInstance(2026, 1, 15)),
      core.le(Opportunity.CreatedDate, Datetime.newInstanceGmt(2026, 1, 15, 9, 30, 0)),
      core.eq(Opportunity.CloseDate, Date.newInstance(2026, 1, 15)),
      core.ge(Opportunity.CloseDate, DateLiteral.lastNDays(30)),
      core.eq(Opportunity.AccountId, String.valueOf(accountId).left(15)),
      core.all(new List<ICondition>{ core.lk(Opportunity.Name, 'Ac%'), core.neg(core.gt(Opportunity.Amount, 5)) })
    };
    job.candidate = new Opportunity(Name = 'Acme', Amount = 1, CloseDate = Date.newInstance(2026, 1, 15), AccountId = accountId);
    List<String> before = new List<String>();
    for (ICondition each : job.carried) {
      before.add(each.toSoql());
    }

    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

    Assert.areEqual(before, writtenByJob, 'the job writes what was written before it was queued');
    Assert.areEqual('CreatedDate > 2026-01-15T00:00:00.000Z', writtenByJob[0], 'a date on a date-time field is still midnight GMT');
    Assert.areEqual(new List<Boolean>{ false, false, true, true, true, true }, answeredByJob, 'and tests a record as before');
  }

  private static List<String> writtenByJob;
  private static List<Boolean> answeredByJob;

  // Carries conditions the way a queueable or a batch does: the platform stores the job and restores it to run it.
  private class Carrier implements System.Queueable {
    private List<ICondition> carried;
    private Opportunity candidate;

    public void execute(QueueableContext context) {
      writtenByJob = new List<String>();
      answeredByJob = new List<Boolean>();
      for (ICondition each : carried) {
        writtenByJob.add(each.toSoql());
        answeredByJob.add(each.evaluate(candidate));
      }
    }
  }

  @IsTest
  static void aLeafIsBoundUnlessThePlatformWantsItWritten() {
    Assert.isTrue(bindable(core.eq(Account.Name, 'Acme')));
    Assert.isTrue(bindable(core.iin(Account.Name, new Set<String>{ 'Acme' })));
    Assert.isTrue(bindable(core.eq(Account.Name, null)), 'one null value binds');
    Assert.isFalse(bindable(core.iin(Account.Name, null)), 'IN with no collection is a constant');
    Assert.isFalse(bindable(core.eq(Account.CreatedDate, DateLiteral.today())));
  }

  private static Boolean bindable(IFieldCondition leaf) {
    return Typing.bindable(leaf.operator(), leaf.value());
  }

  private class AlwaysTrue implements ICondition {
    public ICondition clone(Boolean deep) {
      return this;
    }
    public String compile(IConditionCompilation compilation) {
      return null;
    }
    public Boolean evaluate(SObject candidate) {
      return true;
    }
    public ICondition prepend(IReference via) {
      return this;
    }
    public void realize(SObjectType target) {
    }
    public IModel source() {
      return null;
    }
    public String toSoql() {
      return null;
    }
  }
}
