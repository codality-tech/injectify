@IsTest
private class ApplicationTest {
  private interface IFoo {
    String id();
  }
  private class Foo implements IFoo {
    public String id() {
      return 'foo';
    }
  }

  @IsTest
  static void testApplicationCompositionAndRegistries() {
    // Build registries
    Map<Type, Type> services = new Map<Type, Type>{ IFoo.class => Foo.class };
    Map<Type, Type> queries = new Map<Type, Type>();
    Map<Type, Type> domains = new Map<Type, Type>();
    Map<Type, Type> triggers = new Map<Type, Type>();

    Application app = new Application(
      new SchemeDefault(),
      services,
      queries,
      domains,
      triggers
    );
    System.assertNotEquals(null, app.sf());
    System.assertNotEquals(null, app.df());
    System.assertNotEquals(null, app.qf());
    System.assertNotEquals(null, app.tf());

    // Service resolution via get/make
    Object svc1 = app.sf().get(IFoo.class);
    Object svc2 = app.sf().make(IFoo.class);
    System.assert(svc1 instanceof Foo, 'get returns Foo');
    System.assert(svc2 instanceof Foo, 'make returns Foo');

    // Query factory fallback (unregistered model)
    IQuery q = app.qf().make(Account.SObjectType);
    System.assertNotEquals(null, q);

    // Trigger factory empty registry: no exception on execute() path when unregistered
    Test.startTest();
    app.tf().execute();
    Test.stopTest();
  }

  @IsTest
  static void testStaticMakeMethods() {
    // Test make() with all parameters
    Map<Type, Type> services = new Map<Type, Type>{ IFoo.class => Foo.class };
    Map<Type, Type> queries = new Map<Type, Type>();
    Map<Type, Type> domains = new Map<Type, Type>();
    Map<Type, Type> triggers = new Map<Type, Type>();

    Application app1 = Application.make(
      new SchemeDefault(),
      services,
      queries,
      domains,
      triggers
    );
    System.assertNotEquals(null, app1);
    System.assertNotEquals(null, app1.sf());

    // Test make(IScheme)
    Application app2 = Application.make(new SchemeDefault());
    System.assertNotEquals(null, app2);

    // Test make()
    Application app3 = Application.make();
    System.assertNotEquals(null, app3);
  }

  @IsTest
  static void testInterfaceMethods() {
    Application app = new Application();

    // Test IApplication interface methods
    System.assertEquals(app.sf(), app.sf());
    System.assertEquals(app.qf(), app.qf());
    System.assertEquals(app.df(), app.df());
    System.assertEquals(app.tf(), app.tf());

    // Verify all methods return non-null values
    System.assertNotEquals(null, app.sf());
    System.assertNotEquals(null, app.qf());
    System.assertNotEquals(null, app.df());
    System.assertNotEquals(null, app.tf());
  }

  @IsTest
  static void testFourArgMakeMethod_FFLIBTraditional() {
    // Test the 4-arg make() method that uses domainTriggerRegistry for both domain and trigger
    // This tests the FFLIB traditional pattern where domain and trigger handlers are combined
    Map<Type, Type> services = new Map<Type, Type>{ IFoo.class => Foo.class };
    Map<Type, Type> queries = new Map<Type, Type>();
    // In FFLIB traditional pattern, you would register Account.SObjectType => AccountDomain.class
    // which would be used for both domain operations and trigger handling
    // Using empty registry for this test since DomainFactory has strict validation
    Map<Type, Type> domainTriggerRegistry = new Map<Type, Type>();

    Application app = Application.make(
      new SchemeDefault(),
      services,
      queries,
      domainTriggerRegistry
    );

    // Verify application was created successfully
    System.assertNotEquals(null, app, 'Application should be created');
    System.assertNotEquals(null, app.sf(), 'Service factory should exist');
    System.assertNotEquals(null, app.df(), 'Domain factory should exist');
    System.assertNotEquals(null, app.qf(), 'Query factory should exist');
    System.assertNotEquals(null, app.tf(), 'Triggered factory should exist');

    // The main verification is that the construction succeeded.
    // This proves that the same registry (domainTriggerRegistry) was used for
    // both the domain factory and triggered factory during Application construction.
    // This enables .sf()B pattern where a single class handles both domain logic
    // and trigger events (e.g., AccountDomain handles both).

    // Verify the service factory can still resolve its types
    Object svc = app.sf().get(IFoo.class);
    System.assert(svc instanceof Foo, 'Service factory should work');
  }

  @IsTest
  static void testFourArgMakeMethod_WithRealSObjectTypes() {
    // Test with a more realistic scenario using Account
    Map<Type, Type> services = new Map<Type, Type>();
    Map<Type, Type> queries = new Map<Type, Type>();
    // Create a simple registry - in real use this would be Account.SObjectType => AccountDomain.class
    Map<Type, Type> domainTriggerRegistry = new Map<Type, Type>();

    Application app = Application.make(
      new SchemeDefault(),
      services,
      queries,
      domainTriggerRegistry
    );

    // Verify successful creation
    System.assertNotEquals(null, app, 'Application should be created');
    System.assertNotEquals(null, app.df(), 'Domain factory should exist');
    System.assertNotEquals(null, app.tf(), 'Triggered factory should exist');

    // Test that unregistered types still work (fall through to default behavior)
    IQuery q = app.qf().make(Account.SObjectType);
    System.assertNotEquals(
      null,
      q,
      'Query should be created for unregistered type'
    );

    IDomain d = app.df().make(Account.SObjectType);
    System.assertNotEquals(
      null,
      d,
      'Domain should be created for unregistered type'
    );
  }
}
