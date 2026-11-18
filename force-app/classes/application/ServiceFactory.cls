public class ServiceFactory extends Application.Factory implements IServiceFactory {
  //* Exception class
  public class ServiceFactoryException extends Exception {
  }

  public ServiceFactory(ICore core, Map<Type, Type> registry) {
    super(core, registry);
  }

  public ServiceFactory(ICore core) {
    super(core, new Map<Type, Type>());
  }

  //* Override validation to ensure implementation classes implement the interface
  @TestVisible
  protected override Boolean isValidPair(Type key, Type value) {
    if (key == null || value == null)
      return false;
    return key.isAssignableFrom(value);
  }

  //* Core factory method to create Service instances by Type key
  public Object make(Type key) {
    if (key == null) {
      throw new ServiceFactoryException('Type key cannot be null');
    }

    Type impClass = getRegisteredClass(key);
    if (impClass == null) {
      throw new ServiceFactoryException(
        'No Service class registered for Type: ' + key
      );
    }

    return core.injector().newInstance(impClass);
  }

  //* The shared instance for a Type key (created once); rejects a null or unregistered key like make()
  public Object get(Type key) {
    if (key == null) {
      throw new ServiceFactoryException('Type key cannot be null');
    }
    Type value = getRegisteredClass(key);
    if (value == null) {
      throw new ServiceFactoryException('No Service class registered for Type: ' + key);
    }
    return core.injector().getInstance(value);
  }
}
