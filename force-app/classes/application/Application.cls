global class Application extends Core implements IApplication {
  public static Application s {
    get {
      if (s == null) {
        s = new Application();
      }
      return s;
    }
    private set;
  }
  private ServiceFactory service { get; private set; }
  private QueryFactory query { get; private set; }
  private DomainFactory domain { get; private set; }
  private TriggeredFactory triggered { get; private set; }

  public Application(
    IScheme scheme,
    Map<Type, Type> serviceRegistry,
    Map<Type, Type> queryRegistry,
    Map<Type, Type> domainRegistry,
    Map<Type, Type> triggerRegistry
  ) {
    super(scheme);
    this.service = new ServiceFactory(this, serviceRegistry);
    this.query = new QueryFactory(this, queryRegistry);
    this.domain = new DomainFactory(this, domainRegistry);
    this.triggered = new TriggeredFactory(this, triggerRegistry);
  }

  public Application(IScheme scheme) {
    this(
      scheme,
      new Map<Type, Type>(),
      new Map<Type, Type>(),
      new Map<Type, Type>(),
      new Map<Type, Type>()
    );
  }

  public Application() {
    this(
      null,
      new Map<Type, Type>(),
      new Map<Type, Type>(),
      new Map<Type, Type>(),
      new Map<Type, Type>()
    );
  }

  // Static factory methods
  global static Application make(
    IScheme scheme,
    Map<Type, Type> serviceRegistry,
    Map<Type, Type> queryRegistry,
    Map<Type, Type> domainRegistry,
    Map<Type, Type> triggerRegistry
  ) {
    return new Application(
      scheme,
      serviceRegistry,
      queryRegistry,
      domainRegistry,
      triggerRegistry
    );
  }

  /**
   * FFLIB traditional approach - uses domainTriggerRegistry for both domain and trigger handlers.
   * This is convenient when following the pattern where a single class handles both domain logic
   * and trigger events (e.g., AccountDomain handles both domain operations and trigger events).
   */
  global static Application make(
    IScheme scheme,
    Map<Type, Type> serviceRegistry,
    Map<Type, Type> queryRegistry,
    Map<Type, Type> domainTriggerRegistry
  ) {
    return new Application(
      scheme,
      serviceRegistry,
      queryRegistry,
      domainTriggerRegistry,
      domainTriggerRegistry
    );
  }

  global static Application make(IScheme scheme) {
    return new Application(scheme);
  }

  global static Application make() {
    return new Application();
  }

  // Interface implementation
  public IServiceFactory sf() {
    return this.service;
  }

  public IQueryFactory qf() {
    return this.query;
  }

  public IDomainFactory df() {
    return this.domain;
  }

  public ITriggeredFactory tf() {
    return this.triggered;
  }

  //* Exception class for factories
  global class FactoryException extends Exception {
  }

  public abstract class Factory implements IBaseFactory {
    protected Core core;
    protected Map<Type, Type> registry;
    protected Factory(ICore core, Map<Type, Type> registry) {
      this.core = (Core) core; // Cast ICore to Core for internal access
      this.registry = new Map<Type, Type>();
      register(registry);
    }

    @testvisible
    protected virtual boolean isValidPair(Type key, Type value) {
      return true;
    }

    public void register(Map<Type, Type> registryPatch) {
      if (registryPatch == null)
        return;
      for (Type key : registryPatch.keySet()) {
        Type value = registryPatch.get(key);
        if (value != null && isValidPair(key, value) != true) {
          throw new FactoryException('Invalid pairing: ' + key + ' , ' + value);
        }
      }
      this.registry.putAll(registryPatch);
    }
    public Type getRegisteredClass(Type key) {
      return registry.get(key);
    }

    public Map<Type, Type> getRegistry() {
      return registry.clone();
    }
  }
}
