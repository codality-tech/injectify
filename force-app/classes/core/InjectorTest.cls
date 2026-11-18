@isTest
private class InjectorTest {
  // Test class for singleton behavior
  private class TestClass {
    public String value = 'test';
  }

  @isTest
  static void test_getInstance_singleton() {
    // Create injector instance
    Injector injector = new Injector(new SchemeDefault());

    // Test that getInstance returns the same instance
    TestClass instance1 = (TestClass) injector.getInstance(TestClass.class);
    TestClass instance2 = (TestClass) injector.getInstance(TestClass.class);

    System.assertNotEquals(
      null,
      instance1,
      'First instance should not be null'
    );
    System.assertNotEquals(
      null,
      instance2,
      'Second instance should not be null'
    );
    System.assertEquals(
      instance1,
      instance2,
      'Both instances should be the same (singleton)'
    );
  }

  @isTest
  static void test_newInstance_creates_new_instances() {
    // Create injector instance
    Injector injector = new Injector(new SchemeDefault());

    // Test that newInstance creates different instances
    TestClass instance1 = (TestClass) injector.newInstance(TestClass.class);
    TestClass instance2 = (TestClass) injector.newInstance(TestClass.class);

    System.assertNotEquals(
      null,
      instance1,
      'First instance should not be null'
    );
    System.assertNotEquals(
      null,
      instance2,
      'Second instance should not be null'
    );
    System.assertNotEquals(
      instance1,
      instance2,
      'Instances should be different'
    );
  }

  @isTest
  static void test_newInstance_with_string() {
    // Create injector instance
    Injector injector = new Injector(new SchemeDefault());

    // Test newInstance with string className - use a standard SObject instead of inner class
    Account instance = (Account) injector.newInstance('Account');

    System.assertNotEquals(null, instance, 'Instance should not be null');
    System.assertEquals(
      'Account',
      instance.getSObjectType().getDescribe().getName(),
      'Should be an Account instance'
    );
  }

  @isTest
  static void test_getType() {
    // Create injector instance
    Injector injector = new Injector(new SchemeDefault());

    // Test type resolution with a standard SObject
    Type resolvedType = injector.getType('Account');

    System.assertNotEquals(
      null,
      resolvedType,
      'Resolved type should not be null'
    );
    System.assertEquals(
      Account.class,
      resolvedType,
      'Resolved type should match Account'
    );
  }

  @isTest
  static void test_scheme_integration() {
    // Test that injector uses the scheme for type resolution
    Injector injector = new Injector(new SchemeDefault());

    // This should work through the scheme's getTypeForName method
    Type resolvedType = injector.getType('Account');

    System.assertNotEquals(
      null,
      resolvedType,
      'Resolved type should not be null'
    );
    System.assertEquals(
      Account.class,
      resolvedType,
      'Resolved type should match Account'
    );
  }
}
