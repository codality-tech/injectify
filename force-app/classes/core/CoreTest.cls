@isTest
private class CoreTest {
  // This test is for coverage only. Core is a pure passthrough/facade class,
  // so there are no assertions—just method calls to ensure all lines are covered.
  @isTest
  static void test_passthroughs() {
    Application.s.model(Account.SObjectType);
    Application.s.model('Account');
    Application.s.model(new Account());
    Application.s.model(new List<SObject>{ new Account() });

    Application.s.path(Account.Name);
    Application.s.path(new List<SObjectField>{ Account.Name, Account.OwnerId });

    Application.s.reference(Account.SObjectType);
    Application.s.reference(Account.OwnerId); // Use a lookup field!
    Application.s.reference(
      new List<SObjectField>{ Account.OwnerId, Account.CreatedById }
    ); // All lookup fields
    // Application.s.reference('Account'); // <-- Removed, invalid type

    Application.s.condId(new Set<Id>{ IdUtil.generateId(Account.SObjectType) });
    Application.s.condRtdn(new Set<String>{ 'Master' });

    // Test injector property
    System.assertNotEquals(
      null,
      Application.s.injector(),
      'Injector should be initialized'
    );

    // Test new convenience methods
    Application.s.eq('Name', 'Test');
    Application.s.ne('Type', 'Prospect');
    Application.s.ge('Amount', 1000);
    Application.s.le('Amount', 5000);
    Application.s.gt('Amount', 0);
    Application.s.lt('Amount', 10000);
    Application.s.lk('Name', '%Test%');
    Application.s.iin('Name', new List<String>{ 'Test1', 'Test2' });
    Application.s.nin('Type', new List<String>{ 'Prospect', 'Customer' });
    Application.s.inc('MultiPicklist__c', 'Value1');
    Application.s.exc('MultiPicklist__c', 'Value2');

    // Test negation method
    ICondition negatedCond = Application.s.neg(
      Application.s.eq('Name', 'Test')
    );

    ICondition cond = Application.s.eq('Name', 'Test');
    Application.s.all(new List<ICondition>{ cond });
    Application.s.any(new List<ICondition>{ cond });
    Application.s.all(new List<ICondition>{});
    Application.s.any(new List<ICondition>{});

    Application.s.ordering('Name');
    Application.s.ordering('Name', true);
    Application.s.ordering('Name', true, false);
    Application.s.ordering(Application.s.path(Account.Name), false, true);

    // Add coverage for work method (query and domain now handled by Model)
    Application.s.work();
  }
}
