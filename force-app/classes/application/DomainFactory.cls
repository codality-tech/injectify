public class DomainFactory extends Application.Factory implements IDomainFactory {
  //* Exception class
  public class DomainFactoryException extends Exception {
  }

  public DomainFactory(ICore core, Map<Type, Type> registry) {
    super(core, registry);
  }

  public DomainFactory(ICore core) {
    super(core, new Map<Type, Type>());
  }

  //* Override validation to ensure domain classes implement IDomain and key is SObject
  protected override Boolean isValidPair(Type key, Type value) {
    if (value == null || key == null)
      return false;
    return IDomain.class.isAssignableFrom(value) &&
      SObject.class.isAssignableFrom(key);
  }

  //* Primary factory method - create Domain instances with SObjectType and records
  //* Ensures Scheme isolation by always rebuilding model from this Core's scheme
  public IDomain make(SObjectType token, List<SObject> records) {
    if (token == null) {
      return null;
    }

    // CRITICAL: Always rebuild model using this Core's Scheme (prevents cross-Application contamination)
    IModel model = core.model(token);

    Type key = core.injector().getType(model.name());
    Type impClass = getRegisteredClass(key);
    if (impClass != null) {
      IDomain domain = (IDomain) core.injector().newInstance(impClass);
      // Initialize with model and provided records
      // For BaseDomain, this will call onInitialized() hook
      domain.init(model, records);
      return domain;
    }
    // Fallback: return base Domain instance with records
    return new Domain(model, records);
  }

  //* Factory method with token only (empty records)
  public IDomain make(SObjectType token) {
    return make(token, new List<SObject>());
  }

  //* Factory method with String name (extracts token, flows through make(SObjectType))
  public IDomain make(String name) {
    if (name == null) {
      throw new DomainFactoryException('Object name cannot be null');
    }
    SObjectType token = core.model(name).token();
    return make(token, new List<SObject>());
  }

  //* Factory method with list of records (extracts token from list, flows through primary)
  public IDomain make(List<SObject> records) {
    if (records == null || records.isEmpty()) {
      return null;
    }

    // Extract token from records
    SObjectType token = records.getSObjectType();
    if (token == null && records.size() > 0) {
      token = records[0].getSObjectType();
    }

    if (token == null) {
      throw new DomainFactoryException(
        'Cannot determine SObjectType from records'
      );
    }

    return make(token, records);
  }
}
