@IsTest
private class ServiceFactoryTest {
  // Faux service for testing state and config
  public interface FauxServiceInterface {
    String getValue();
    void setValue(String value);
    Boolean isInitialized();
  }

  public class FauxServiceImplementation implements FauxServiceInterface {
    private String serviceValue = '';
    private Boolean initialized = false;

    public String getValue() {
      return serviceValue;
    }

    public void setValue(String value) {
      serviceValue = value;
      initialized = true;
    }

    public Boolean isInitialized() {
      return initialized;
    }
  }

  @IsTest
  static void testRegisterAndGet() {
    // Create Core and ServiceFactory
    Core core = new Core(new SchemeDefault());
    Map<Type, Type> serviceMap = new Map<Type, Type>{
      FauxServiceInterface.class => FauxServiceImplementation.class
    };
    ServiceFactory factory = new ServiceFactory(core, serviceMap);

    System.assert(
      factory.getRegistry().containsKey(FauxServiceInterface.class),
      'Should be registered'
    );
    Object service = factory.get(FauxServiceInterface.class);
    System.assertNotEquals(
      null,
      service,
      'Service instance should not be null'
    );
    System.assert(
      service instanceof FauxServiceImplementation,
      'Should be FauxServiceImplementation'
    );
  }

  @IsTest
  static void testMakeMethod() {
    // Create Core and ServiceFactory
    Core core = new Core(new SchemeDefault());
    Map<Type, Type> serviceMap = new Map<Type, Type>{
      FauxServiceInterface.class => FauxServiceImplementation.class
    };
    ServiceFactory factory = new ServiceFactory(core, serviceMap);

    // Test make method
    Object service = factory.make(FauxServiceInterface.class);
    System.assertNotEquals(
      null,
      service,
      'Service instance should not be null'
    );
    System.assert(
      service instanceof FauxServiceImplementation,
      'Should be FauxServiceImplementation'
    );
  }

  @IsTest
  static void testServiceState() {
    // Test service state tracking
    FauxServiceImplementation service = new FauxServiceImplementation();
    System.assertEquals(
      false,
      service.isInitialized(),
      'Should not be initialized initially'
    );
    System.assertEquals(
      '',
      service.getValue(),
      'Should have empty value initially'
    );

    Test.startTest();
    service.setValue('test value');
    Test.stopTest();

    System.assertEquals(true, service.isInitialized(), 'Should be initialized');
    System.assertEquals(
      'test value',
      service.getValue(),
      'Should have correct value'
    );
  }

  @IsTest
  static void testMakeErrors() {
    Core core = new Core(new SchemeDefault());
    ServiceFactory factory = new ServiceFactory(core);

    try {
      factory.make((Type) null);
      System.assert(false, 'Should throw exception for null type');
    } catch (ServiceFactory.ServiceFactoryException e) {
      System.assert(
        e.getMessage().contains('Type key cannot be null'),
        'Should throw correct exception message'
      );
    }

    try {
      factory.make(FauxServiceInterface.class);
      System.assert(false, 'Should throw exception for unregistered service');
    } catch (ServiceFactory.ServiceFactoryException e) {
      System.assert(
        e.getMessage().contains('No Service class registered'),
        'Should throw correct exception message'
      );
    }
  }

  @IsTest
  static void testGetErrors() {
    Core core = new Core(new SchemeDefault());
    ServiceFactory factory = new ServiceFactory(core);

    try {
      factory.get((Type) null);
      Assert.fail('Should throw exception for null type');
    } catch (ServiceFactory.ServiceFactoryException e) {
      Assert.areEqual('Type key cannot be null', e.getMessage());
    }

    try {
      factory.get(FauxServiceInterface.class);
      Assert.fail('Should throw exception for unregistered service');
    } catch (ServiceFactory.ServiceFactoryException e) {
      Assert.isTrue(e.getMessage().contains('No Service class registered'), e.getMessage());
    }
  }

  @IsTest
  static void testConstructorWithMap() {
    Core core = new Core(new SchemeDefault());
    Map<Type, Type> customServiceMap = new Map<Type, Type>{
      FauxServiceInterface.class => FauxServiceImplementation.class
    };
    ServiceFactory customFactory = new ServiceFactory(core, customServiceMap);
    System.assert(
      customFactory.getRegistry().containsKey(FauxServiceInterface.class),
      'Should be registered from constructor'
    );
  }

  @IsTest
  static void testConstructorWithoutMap() {
    Core core = new Core(new SchemeDefault());
    ServiceFactory testFactory = new ServiceFactory(core);
    System.assert(
      !testFactory.getRegistry().containsKey(FauxServiceInterface.class),
      'Should not be registered initially'
    );

    // Use register() method to add to registry
    Map<Type, Type> serviceMap = new Map<Type, Type>{
      FauxServiceInterface.class => FauxServiceImplementation.class
    };
    testFactory.register(serviceMap);
    System.assert(
      testFactory.getRegistry().containsKey(FauxServiceInterface.class),
      'Should be registered after manual addition'
    );
  }

  @IsTest
  static void testIsValidPair() {
    Core core = new Core(new SchemeDefault());
    ServiceFactory testFactory = new ServiceFactory(core);

    // Test valid pair
    System.assert(
      testFactory.isValidPair(
        FauxServiceInterface.class,
        FauxServiceImplementation.class
      ),
      'Should be valid pair'
    );

    // Test invalid pairs
    System.assert(
      !testFactory.isValidPair(null, FauxServiceImplementation.class),
      'Should be invalid with null key'
    );
    System.assert(
      !testFactory.isValidPair(FauxServiceInterface.class, null),
      'Should be invalid with null value'
    );
    System.assert(
      !testFactory.isValidPair(String.class, FauxServiceImplementation.class),
      'Should be invalid - String does not implement FauxServiceInterface'
    );
  }

  @IsTest
  static void testMultipleRegistrations() {
    Core core = new Core(new SchemeDefault());
    ServiceFactory testFactory = new ServiceFactory(core);

    // Register multiple services
    Map<Type, Type> serviceMap = new Map<Type, Type>{
      FauxServiceInterface.class => FauxServiceImplementation.class
    };
    testFactory.register(serviceMap);

    // Test that each is registered
    System.assert(
      testFactory.getRegistry().containsKey(FauxServiceInterface.class),
      'First service should be registered'
    );

    // Test that unregistered services are not found
    System.assert(
      !testFactory.getRegistry().containsKey(String.class),
      'Unregistered service should not be found'
    );
  }

  @IsTest
  static void testRegisterMergesIntoRegistry() {
    Core core = new Core(new SchemeDefault());
    ServiceFactory factory = new ServiceFactory(core);
    System.assertNotEquals(
      null,
      factory.getRegistry(),
      'Registry should be initialized'
    );

    Map<Type, Type> patch = new Map<Type, Type>{
      FauxServiceInterface.class => FauxServiceImplementation.class
    };

    factory.register(patch);

    System.assert(
      factory.getRegistry().containsKey(FauxServiceInterface.class),
      'Registry should contain registered key'
    );
    System.assertEquals(
      FauxServiceImplementation.class,
      factory.getRegisteredClass(FauxServiceInterface.class),
      'Registered value should match'
    );

    // Null patch should be a no-op
    factory.register(null);
    System.assert(
      factory.getRegistry().containsKey(FauxServiceInterface.class),
      'Registry should remain unchanged after null patch'
    );
  }

  @IsTest
  static void testServiceRetrieval() {
    Core core = new Core(new SchemeDefault());
    ServiceFactory testFactory = new ServiceFactory(core);
    Map<Type, Type> serviceMap = new Map<Type, Type>{
      FauxServiceInterface.class => FauxServiceImplementation.class
    };
    testFactory.register(serviceMap);

    // Test retrieval and type casting
    Object service = testFactory.get(FauxServiceInterface.class);
    FauxServiceInterface typedService = (FauxServiceInterface) service;

    System.assertNotEquals(null, typedService, 'Should retrieve service');
    System.assert(
      typedService instanceof FauxServiceImplementation,
      'Should be correct implementation type'
    );
  }

  @IsTest
  static void testCoreIntegration() {
    Core core = new Core(new SchemeDefault());
    ServiceFactory testFactory = new ServiceFactory(core);
    Map<Type, Type> serviceMap = new Map<Type, Type>{
      FauxServiceInterface.class => FauxServiceImplementation.class
    };
    testFactory.register(serviceMap);

    // Test that the factory uses the core's injector
    Object service = testFactory.make(FauxServiceInterface.class);
    System.assertNotEquals(
      null,
      service,
      'Should create service using core injector'
    );
    System.assert(
      service instanceof FauxServiceImplementation,
      'Should be correct implementation'
    );
  }
}
