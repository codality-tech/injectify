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
}
