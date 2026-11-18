public class TriggeredFactory extends Application.Factory implements ITriggeredFactory {
  //* Exception class
  public class TriggerFactoryException extends Exception {
  }

  //* Configuration is provided by top-level TriggeredConfiguration class

  //* Trigger state management: SObjectType -> TriggerState
  private Map<SObjectType, TriggerState> triggerStates = new Map<SObjectType, TriggerState>();

  //* Instance-level recycle map for triggered instance reuse
  //* Key: SObjectType, Value: Map of BEFORE operation -> instance
  //* This ensures BEFORE_INSERT pairs with AFTER_INSERT, etc.
  private Map<SObjectType, Map<TriggerOperation, ITriggered>> recycleTriggerMap = new Map<SObjectType, Map<TriggerOperation, ITriggered>>();

  //* Global bypass counter for all triggers
  private Integer bypassCount = 0;

  //* Rules given to disableWhen, asked each time a trigger is about to run
  private List<ITriggeredBypass> bypassRules = new List<ITriggeredBypass>();

  public TriggeredFactory(ICore core, Map<Type, Type> registry) {
    super(core, registry);
  }

  public TriggeredFactory(ICore core) {
    super(core, new Map<Type, Type>());
  }

  protected override Boolean isValidPair(Type key, Type value) {
    if (value == null || key == null)
      return false;
    return ITriggered.class.isAssignableFrom(value) &&
      SObject.class.isAssignableFrom(key);
  }

  //* Primary factory method - create Triggered instances with SObjectType
  //* Ensures Scheme isolation by always rebuilding model from this Core's scheme
  public ITriggered make(SObjectType token) {
    if (token == null)
      throw new TriggerFactoryException('SObjectType token cannot be null');

    // CRITICAL: Always rebuild model using this Core's Scheme (prevents cross-Application contamination)
    IModel model = core.model(token);
    if (model == null)
      throw new TriggerFactoryException(
        'Could not create model for token: ' + token
      );

    Type key = core.injector().getType(model.name());
    Type impClass = getRegisteredClass(key);
    if (impClass == null)
      throw new TriggerFactoryException(
        'No Triggered class registered for Type: ' + key
      );

    try {
      return (ITriggered) core.injector().newInstance(impClass);
    } catch (Exception e) {
      throw new TriggerFactoryException(
        'Failed to create triggered instance: ' + e.getMessage()
      );
    }
  }

  //* Factory method with String name (extracts token, flows through make(SObjectType))
  public ITriggered make(String name) {
    if (String.isBlank(name))
      throw new TriggerFactoryException('Name cannot be blank');
    SObjectType token = core.model(name).token();
    if (token == null)
      throw new TriggerFactoryException('Could not resolve token for: ' + name);
    return make(token);
  }

  public void execute() {
    executeTrigger(null, null, null, null);
  }

  @testVisible
  private void executeTrigger(
    TriggerOperation triggerOp,
    list<SObject> triggerNew,
    List<Sobject> triggerOld,
    Map<Id, SObject> triggerOldMap
  ) {
    triggerOp = triggerOp ?? Trigger.operationType;
    triggerNew = triggerNew ?? Trigger.new;
    triggerOld = triggerOld ?? Trigger.old;
    triggerOldMap = triggerOldMap ?? Trigger.oldMap;

    list<sobject> records = triggerNew ?? triggerOld;
    if (records == null || records.isEmpty())
      return;
    sobjecttype token = this.core.model(records).token();

    // Check factory-level bypass first
    if (this.bypassCount > 0)
      return;

    TriggerState state = getOrCreateTriggerState(token);
    if (state?.isEnabled(triggerOp) != true)
      return;

    Type key = core.injector().getType(String.valueOf(token));
    Type impClass = getRegisteredClass(key);
    if (impClass == null)
      return;

    if (isBypassedByRule(token, triggerOp))
      return;

    ITriggered triggered = (ITriggered) core.injector().newInstance(impClass);

    Boolean recycleInstance = false;
    Boolean enforceSecurity = false;

    // Check if triggered implements ITriggeredConfigured
    if (triggered instanceof ITriggeredConfigured) {
      ITriggeredConfigured configured = (ITriggeredConfigured) triggered;
      recycleInstance = configured.shouldRecycleInstance();
      enforceSecurity = configured.shouldEnforceSecurity();
    }

    if (enforceSecurity) {
      checkPermission(core.model(token), permissionFor(triggerOp));
    }

    if (recycleInstance) {
      switch on triggerOp {
        when BEFORE_INSERT, BEFORE_UPDATE, BEFORE_DELETE {
          // Store instance keyed by SObjectType and BEFORE operation
          if (!recycleTriggerMap.containsKey(token)) {
            recycleTriggerMap.put(
              token,
              new Map<TriggerOperation, ITriggered>()
            );
          }
          recycleTriggerMap.get(token).put(triggerOp, triggered);
        }
        when AFTER_INSERT {
          // Retrieve instance that was stored during BEFORE_INSERT
          ITriggered recycled = recycleTriggerMap.get(token)
            ?.get(TriggerOperation.BEFORE_INSERT);
          triggered = recycled != null
            ? recycled
            : (ITriggered) core.injector().newInstance(impClass);
        }
        when AFTER_UPDATE {
          // Retrieve instance that was stored during BEFORE_UPDATE
          ITriggered recycled = recycleTriggerMap.get(token)
            ?.get(TriggerOperation.BEFORE_UPDATE);
          triggered = recycled != null
            ? recycled
            : (ITriggered) core.injector().newInstance(impClass);
        }
        when AFTER_DELETE {
          // Retrieve instance that was stored during BEFORE_DELETE
          ITriggered recycled = recycleTriggerMap.get(token)
            ?.get(TriggerOperation.BEFORE_DELETE);
          triggered = recycled != null
            ? recycled
            : (ITriggered) core.injector().newInstance(impClass);
        }
      }
    }

    if (Test.isRunningTest() && (triggered instanceof Domain)) {
      ((Domain) triggered)
        .setTriggerMock(triggerOp, triggerNew, triggerOld, triggerOldMap);
    }

    IModel model = core.model(token);
    triggered.handleTrigger(
      triggerOp,
      triggerNew,
      triggerOld,
      triggerOldMap,
      model
    );
  }

  @TestVisible
  private void resetRecycled() {
    recycleTriggerMap.clear();
  }

  public void disable(Map<SObjectType, Set<TriggerOperation>> bypasses) {
    if (bypasses == null)
      return;
    for (SObjectType token : bypasses.keySet()) {
      Set<TriggerOperation> operations = bypasses.get(token);
      getOrCreateTriggerState(token).disable(operations);
    }
  }

  public void enable(Map<SObjectType, Set<TriggerOperation>> bypasses) {
    if (bypasses == null)
      return;
    for (SObjectType token : bypasses.keySet()) {
      Set<TriggerOperation> operations = bypasses.get(token);
      TriggerState triggerState = triggerStates.get(token);
      if (triggerState != null) {
        triggerState.enable(operations);
      }
    }
  }

  //* Disable all triggers across all SObjectTypes
  public void disable() {
    this.bypassCount++;
  }

  //* Enable all triggers across all SObjectTypes
  public void enable() {
    if (this.bypassCount > 0) {
      this.bypassCount--;
    }
  }

  //* Disable all operations for specific SObjectTypes
  public void disable(Iterable<SObjectType> tokens) {
    if (tokens == null)
      return;
    for (SObjectType token : tokens) {
      getOrCreateTriggerState(token).disableAll();
    }
  }

  //* Enable all operations for specific SObjectTypes
  public void enable(Iterable<SObjectType> tokens) {
    if (tokens == null)
      return;
    for (SObjectType token : tokens) {
      TriggerState triggerState = triggerStates.get(token);
      if (triggerState != null) {
        triggerState.enableAll();
      }
    }
  }

  //* Triggers stay off while a rule says so. Rules add up: one that says yes is enough.
  public void disableWhen(ITriggeredBypass rule) {
    if (rule != null) {
      bypassRules.add(rule);
    }
  }

  private Boolean isBypassedByRule(SObjectType token, TriggerOperation triggerOp) {
    for (ITriggeredBypass rule : bypassRules) {
      if (rule.bypasses(token, triggerOp) == true) {
        return true;
      }
    }
    return false;
  }

  private TriggerState getOrCreateTriggerState(SObjectType token) {
    TriggerState triggerState = triggerStates.get(token);
    if (triggerState == null) {
      triggerState = new TriggerState();
      triggerStates.put(token, triggerState);
    }
    return triggerState;
  }

  // The object permission a trigger operation needs. Inserting needs create, not "insert".
  @TestVisible
  private static String permissionFor(TriggerOperation triggerOp) {
    switch on triggerOp {
      when BEFORE_INSERT, AFTER_INSERT {
        return 'create';
      }
      when BEFORE_UPDATE, AFTER_UPDATE {
        return 'update';
      }
      when BEFORE_DELETE, AFTER_DELETE {
        return 'delete';
      }
      when else {
        return 'undelete';
      }
    }
  }

  @testVisible
  private void checkPermission(IModel model, String operation) {
    if (model == null)
      return;
    Boolean hasPermission = false;
    String name = model.name();
    switch on operation {
      when 'create' {
        hasPermission = model.describe().isCreateable();
      }
      when 'update' {
        hasPermission = model.describe().isUpdateable();
      }
      when 'delete' {
        hasPermission = model.describe().isDeletable();
      }
      when 'undelete' {
        hasPermission = model.describe().isUndeletable();
      }
      when else {
        throw new TriggerFactoryException('Unknown operation: ' + operation);
      }
    }
    if (!hasPermission) {
      throw new TriggerFactoryException(
        'Permission to ' + operation + ' ' + name + ' denied'
      );
    }
  }

  @TestVisible
  public Map<SObjectType, TriggerState> getTriggerStates() {
    return new Map<SObjectType, TriggerState>(this.triggerStates);
  }

  public class TriggerState {
    private Map<TriggerOperation, Integer> bypassMap = new Map<TriggerOperation, Integer>();
    private Integer bypassCount = 0;

    public TriggerState() {
      for (TriggerOperation op : TriggerOperation.values()) {
        bypassMap.put(op, 0);
      }
    }

    public Boolean isEnabled(TriggerOperation operation) {
      // Check TriggerState-level bypass first
      if (this.bypassCount > 0)
        return false;
      // Check operation-specific bypass
      Integer count = bypassMap.get(operation);
      return count == 0;
    }

    public void disable(Set<TriggerOperation> operations) {
      for (TriggerOperation op : operations) {
        Integer count = bypassMap.get(op);
        bypassMap.put(op, count + 1);
      }
    }

    public void enable(Set<TriggerOperation> operations) {
      for (TriggerOperation op : operations) {
        Integer count = bypassMap.get(op);
        if (count > 0) {
          bypassMap.put(op, count - 1);
        }
      }
    }

    public void disableAll() {
      this.bypassCount++;
    }

    public void enableAll() {
      if (this.bypassCount > 0) {
        this.bypassCount--;
      }
    }
  }
}
