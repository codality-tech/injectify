public virtual class Domain implements IDomain, ITriggered, ITriggeredConfigured {
  private IModel source;
  private List<SObject> records;
  // catalog() and catalogId() results, remembered per path until the records change.
  private Map<IPath, Map<String, List<SObject>>> catalogs = new Map<IPath, Map<String, List<SObject>>>();
  private Map<IPath, Map<Id, List<SObject>>> catalogsById = new Map<IPath, Map<Id, List<SObject>>>();
  private Map<Id, SObject> toMap;
  private Boolean isInitializedField = false;

  public Boolean isInitialized() {
    return isInitializedField;
  }

  // No-argument constructor for factory usage
  public Domain() {
    this.records = new List<SObject>();
  }

  // Constructor that takes model and records and calls init internally
  public Domain(IModel source, List<SObject> records) {
    init(source, records);
  }

  // IDomain interface implementation
  public virtual void init(IModel source, List<SObject> records) {
    if (isInitialized()) {
      // If source is null, use existing source (handleTrigger passes null)
      if (source == null) {
        source = this.source;
      }
      // Already initialized - verify it's the same model
      if (this.source != source) {
        throw new IllegalArgumentException(
          'Domain has already been initialized with a different model. ' +
            'Expected: ' +
            this.source.token() +
            ', Got: ' +
            source.token()
        );
      }
      // Verify records aren't being changed (null records is OK for idempotent factory calls)
      if (records != null && !records.isEmpty() && records != this.records) {
        throw new IllegalArgumentException(
          'Domain has already been initialized. Cannot change records after initialization.'
        );
      }
      // Same model and no record change - idempotent, just return
      return;
    }
    sobjecttype token = records?.getSObjectType();
    if (source == null) {
      source = this.source;
    }
    if (source != null) {
      if (token != null) {
        if (source.token() != token) {
          throw new IllegalArgumentException(
            'Records provided to not match source model: ' +
              token +
              ' ' +
              source.token()
          );
        }
      } else if (records == null) {
        // Only spawn a new list if records is null, not if token is null
        records = source.spawnRecordList();
      }
    } else {
      if (token != null) {
        source = Application.s.model(token);
      }
    }
    this.source = source;
    refreshRecords(records != null ? records : new List<SObject>());
    this.isInitializedField = true;
  }

  // Takes a new record list and drops everything computed from the old one: the Id map and both
  // catalogs. A recycled instance reaches its AFTER phase with new record instances.
  private void refreshRecords(List<SObject> rows) {
    this.records = rows;
    this.toMap = null;
    catalogs.clear();
    catalogsById.clear();
  }

  // Trigger methods - consolidated upsert handlers (primary extension point)
  protected virtual void onBeforeUpsert(Map<Id, SObject> oldMap) {
    // Override in subclasses for BEFORE_INSERT/BEFORE_UPDATE logic
    // oldMap is null for inserts, non-null for updates
  }

  protected virtual void onAfterUpsert(Map<Id, SObject> oldMap) {
    // Override in subclasses for AFTER_INSERT/AFTER_UPDATE logic
    // oldMap is null for inserts, non-null for updates
  }

  // Trigger methods - granular handlers (internal dispatch only, not for override)
  private void onBeforeInsert() {
    onBeforeUpsert(null);
  }

  private void onBeforeUpdate(Map<Id, SObject> oldMap) {
    onBeforeUpsert(oldMap);
  }

  protected virtual void onBeforeDelete() {
    // Override in subclasses
  }

  private void onAfterInsert() {
    onAfterUpsert(null);
  }

  private void onAfterUpdate(Map<Id, SObject> oldMap) {
    onAfterUpsert(oldMap);
  }

  protected virtual void onAfterDelete() {
    // Override in subclasses
  }

  protected virtual void onAfterUndelete() {
    // Override in subclasses
  }

  TriggerOperation triggerOpPrior;
  TriggerOperation triggerOp;
  list<SObject> triggerNew;
  List<Sobject> triggerOld;
  Map<Id, SObject> triggerOldMap;

  @testVisible
  public void setTriggerMock(
    TriggerOperation triggerOp,
    list<SObject> triggerNew,
    List<Sobject> triggerOld,
    Map<Id, SObject> triggerOldMap
  ) {
    this.triggerOp = triggerOp;
    this.triggerNew = triggerNew;
    this.triggerOld = triggerOld;
    this.triggerOldMap = triggerOldMap;
  }

  // ITriggered interface implementation (explicit signature)
  public virtual void handleTrigger(
    TriggerOperation op,
    List<SObject> trigNew,
    List<SObject> trigOld,
    Map<Id, SObject> trigOldMapParam,
    IModel model
  ) {
    triggerOp = op ?? Trigger.operationType;
    triggerNew = trigNew ?? Trigger.new;
    triggerOld = trigOld ?? Trigger.old;
    triggerOldMap = trigOldMapParam ?? Trigger.oldMap;

    boolean recycled = shouldRecycleInstance();

    // Call appropriate dedicated trigger methods
    switch on (triggerOp ?? Trigger.operationType) {
      when BEFORE_INSERT {
        if (recycled) {
          triggerOpPrior = triggerOp;
        }
        init(null, triggerNew);
        onBeforeInsert();
      }
      when AFTER_INSERT {
        if (recycled && triggerOpPrior == TriggerOperation.BEFORE_INSERT) {
          refreshRecords(triggerNew);
        } else {
          init(null, triggerNew);
        }
        onAfterInsert();
      }
      when BEFORE_UPDATE {
        if (recycled) {
          triggerOpPrior = triggerOp;
        }
        init(null, triggerNew);
        onBeforeUpdate(triggerOldMap);
      }
      when AFTER_UPDATE {
        if (recycled && triggerOpPrior == TriggerOperation.BEFORE_UPDATE) {
          refreshRecords(triggerNew);
        } else {
          init(null, triggerNew);
        }
        onAfterUpdate(triggerOldMap);
      }
      when BEFORE_DELETE {
        if (recycled) {
          triggerOpPrior = triggerOp;
        }
        init(null, triggerOld);
        onBeforeDelete();
      }
      when AFTER_DELETE {
        if (recycled && triggerOpPrior == TriggerOperation.BEFORE_DELETE) {
          refreshRecords(triggerOld);
        } else {
          init(null, triggerOld);
        }
        onAfterDelete();
      }
      when AFTER_UNDELETE {
        init(null, triggerNew);
        onAfterUndelete();
      }
    }
    setTriggerMock(null, null, null, null);
  }

  // ITriggeredConfigured interface implementation
  // NOTE: Public virtual here; BaseDomain exposes them globally for cross-namespace extensibility
  public virtual Boolean shouldRecycleInstance() {
    return false;
  }

  public virtual Boolean shouldEnforceSecurity() {
    return false;
  }

  public IModel source() {
    return source;
  }

  // Backward-compatible no-arg trigger entrypoint for legacy tests
  public void handleTrigger() {
    // Prefer mock values (set by tests) when available; fall back to Trigger statics
    handleTrigger(
      this.triggerOp,
      this.triggerNew,
      this.triggerOld,
      this.triggerOldMap,
      this.source
    );
  }

  /** A copy of the records. */
  public List<SObject> records() {
    return records?.clone();
  }

  public Integer size() {
    return records == null ? 0 : records.size();
  }

  /** The records by Id (a copy); empty when they have no Ids yet. */
  public Map<Id, SObject> toMap() {
    if (toMap == null) {
      Boolean allSaved = true;
      for (SObject record : records) {
        allSaved = allSaved && record.Id != null;
      }
      Map<Id, SObject> byId = new Map<Id, SObject>();
      if (allSaved) {
        try {
          byId = new Map<Id, SObject>(records);
        } catch (ListException repeatedIds) {
          byId = new Map<Id, SObject>();
        }
      }
      toMap = byId;
    }
    return toMap.clone();
  }

  /** As below, by field API name; an unknown name throws. */
  public List<SObject> getChangedRecords(Map<Id, SObject> previous, Set<String> fieldNames) {
    Set<SObjectField> fields = new Set<SObjectField>();
    Map<String, SObjectField> byName = source().fieldMap();
    for (String name : fieldNames ?? new Set<String>()) {
      SObjectField field = byName.get(name);
      if (field == null) {
        throw new IllegalArgumentException('Field not found: ' + name);
      }
      fields.add(field);
    }
    return getChangedRecords(previous, fields);
  }

  /**
   * The records whose value in any of the fields differs from their previous version. A record with
   * no previous version (or no Id) counts as changed, as do all of them when there is no history.
   */
  public List<SObject> getChangedRecords(Map<Id, SObject> previous, Set<SObjectField> fields) {
    if (fields == null || fields.isEmpty()) {
      throw new IllegalArgumentException('Field tokens cannot be null/empty');
    }
    List<SObject> changed = new List<SObject>();
    for (SObject record : records) {
      SObject before = previous == null || record.Id == null ? null : previous.get(record.Id);
      if (before == null || differs(record, before, fields)) {
        changed.add(record);
      }
    }
    return changed;
  }

  private static Boolean differs(SObject now, SObject before, Set<SObjectField> fields) {
    for (SObjectField field : fields) {
      if (now.get(field) != before.get(field)) {
        return true;
      }
    }
    return false;
  }

  /**
   * The records that meet the condition, tested in memory. Fields read through lookups need those
   * related records loaded; an unloaded parent reads as null.
   */
  public List<SObject> filter(ICondition condition) {
    if (condition == null) {
      throw new IllegalArgumentException('Condition cannot be null');
    }
    condition.realize(source().token());
    List<SObject> kept = new List<SObject>();
    for (SObject record : records) {
      Boolean holds = condition.evaluate(record);
      if (holds == true) {
        kept.add(record);
      }
    }
    return kept;
  }

  /** A sorted copy of the records; the domain's own order is unchanged. */
  public List<SObject> sort(IOrdering ordering) {
    List<SObject> sorted = records.clone();
    ordering.apply(sorted);
    return sorted;
  }

  // A route (field name, field, list of fields, or path) as a path from this domain's model.
  private IPath resolvePath(Object route) {
    if (route == null) {
      throw new IllegalArgumentException('Path cannot be null');
    }
    if (route instanceof IPath) {
      return (IPath) route;
    }
    if (route instanceof SObjectField) {
      return source().path((SObjectField) route);
    }
    if (route instanceof String) {
      IPath named = source().path((String) route);
      if (named != null) {
        return named;
      }
      // AggregateResult columns are aliases, not described fields.
      if (source()?.token() == AggregateResult.SObjectType) {
        return new Modeling.StringPath(source(), (String) route);
      }
      throw new IllegalArgumentException('Field not found: ' + route);
    }
    if (route instanceof List<Object>) {
      try {
        return source().path((List<SObjectField>) route);
      } catch (Exception notFields) {
        throw new IllegalArgumentException('Invalid path type: ' + route);
      }
    }
    throw new IllegalArgumentException('Invalid path type: ' + route);
  }

  /** The records grouped by the text of a path's value; null groups under 'null'. */
  public Map<String, List<SObject>> segment(Object path) {
    IPath field = resolvePath(path);
    Map<String, List<SObject>> groups = new Map<String, List<SObject>>();
    for (SObject record : records) {
      Object value = field.getFieldValue(record);
      String key = value == null ? 'null' : String.valueOf(value);
      List<SObject> members = groups.get(key);
      if (members == null) {
        members = new List<SObject>();
        groups.put(key, members);
      }
      members.add(record);
    }
    return groups;
  }

  /** The records grouped by an Id-valued path; records without an Id there are left out. */
  public Map<Id, List<SObject>> segmentId(Object path) {
    IPath field = resolvePath(path);
    Map<Id, List<SObject>> groups = new Map<Id, List<SObject>>();
    for (SObject record : records) {
      Object value = field.getFieldValue(record);
      if (!(value instanceof Id)) {
        continue;
      }
      List<SObject> members = groups.get((Id) value);
      if (members == null) {
        members = new List<SObject>();
        groups.put((Id) value, members);
      }
      members.add(record);
    }
    return groups;
  }

  /** segment(), remembered per path until the records change or forget() is called. */
  public Map<String, List<SObject>> catalog(Object path) {
    IPath field = resolvePath(path);
    if (!catalogs.containsKey(field)) {
      catalogs.put(field, segment(field));
    }
    return catalogs.get(field);
  }

  /** segmentId(), remembered the same way. */
  public Map<Id, List<SObject>> catalogId(Object path) {
    IPath field = resolvePath(path);
    if (!catalogsById.containsKey(field)) {
      catalogsById.put(field, segmentId(field));
    }
    return catalogsById.get(field);
  }

  /** Drops what catalog() and catalogId() remembered for the path; an unknown path is ignored. */
  public void forget(Object path) {
    IPath field;
    try {
      field = resolvePath(path);
    } catch (IllegalArgumentException unknown) {
      return;
    }
    catalogs.remove(field);
    catalogsById.remove(field);
  }

  /** The loaded related records along a lookup path, by Id. */
  public Map<Id, SObject> collectRecords(Object path) {
    IPath field = resolvePath(path);
    if (!(field instanceof ILookupPath)) {
      throw new IllegalArgumentException('Path is not a lookup relationship: ' + path);
    }
    ILookupPath lookup = (ILookupPath) field;
    Map<Id, SObject> related = new Map<Id, SObject>();
    for (SObject record : records) {
      SObject parent = lookup.getRecordValue(record);
      if (parent != null) {
        related.put(parent.Id, parent);
      }
    }
    return related;
  }

  /**
   * An aggregate over the records in memory, like its SOQL counterpart: COUNT (of non-null values,
   * or of records without a field), COUNT_DISTINCT, MIN and MAX (numbers, dates, times, text), and
   * SUM and AVG (numbers). Null values are skipped; MIN, MAX, SUM and AVG of nothing are null.
   */
  public Object aggregate(IAggregateFunction function) {
    if (function == null) {
      throw new IllegalArgumentException('Aggregate function cannot be null');
    }
    String name = function.functionName();
    if (function.field() == null && name == 'COUNT') {
      return records.size();
    }
    IPath field = resolvePath(function.field());
    List<Object> values = new List<Object>();
    for (SObject record : records) {
      Object value = field.getFieldValue(record);
      if (value != null) {
        values.add(value);
      }
    }
    switch on name {
      when 'COUNT' {
        return values.size();
      }
      when 'COUNT_DISTINCT' {
        return new Set<Object>(values).size();
      }
      when 'MIN', 'MAX' {
        Integer wanted = name == 'MIN' ? -1 : 1;
        Object best;
        for (Object value : values) {
          if (best == null || order(value, best) == wanted) {
            best = value;
          }
        }
        return best;
      }
      when 'SUM', 'AVG' {
        if (values.isEmpty()) {
          return null;
        }
        Decimal total = 0;
        for (Object value : values) {
          total += asNumber(value, name);
        }
        return name == 'SUM' ? total : total / values.size();
      }
    }
    throw new IllegalArgumentException('Unsupported aggregate function: ' + name);
  }

  // Orders two non-null values of one kind: -1, 0 or 1. A Date passes as a Datetime here.
  private static Integer order(Object a, Object b) {
    if (a instanceof Datetime) {
      Long gap = ((Datetime) a).getTime() - ((Datetime) b).getTime();
      return gap == 0 ? 0 : (gap > 0 ? 1 : -1);
    }
    if (a instanceof Time) {
      Datetime anyDay = Datetime.newInstanceGmt(2000, 1, 1);
      return order(Datetime.newInstanceGmt(anyDay.dateGmt(), (Time) a), Datetime.newInstanceGmt(anyDay.dateGmt(), (Time) b));
    }
    if (a instanceof String) {
      String x = (String) a;
      String y = (String) b;
      return x == y ? 0 : (x > y ? 1 : -1);
    }
    Decimal x = asNumber(a, 'MIN/MAX');
    Decimal y = asNumber(b, 'MIN/MAX');
    return x == y ? 0 : (x > y ? 1 : -1);
  }

  private static Decimal asNumber(Object value, String functionName) {
    if (value instanceof Integer) {
      return (Integer) value;
    } else if (value instanceof Long) {
      return (Long) value;
    } else if (value instanceof Decimal) {
      return (Decimal) value;
    } else if (value instanceof Double) {
      return Decimal.valueOf((Double) value);
    }
    throw new IllegalArgumentException(functionName + ' requires numeric field');
  }

  public void updateDifferent(SObject template, IWork work) {
    applyTemplate(template, work, false);
  }

  public void updateBlank(SObject template, IWork work) {
    applyTemplate(template, work, true);
  }

  // Copies the template's populated fields onto each record (only into blank fields when asked)
  // and tracks the records that changed.
  private void applyTemplate(SObject template, IWork work, Boolean onlyIntoBlanks) {
    if (records == null || records.isEmpty()) {
      return;
    }
    SObjectType recordType = records[0].getSObjectType();
    if (template == null || template.getSObjectType() != recordType) {
      throw new IllegalArgumentException('Template must be a ' + recordType + ' record');
    }
    Map<String, Object> templateValues = template.getPopulatedFieldsAsMap();
    for (SObject record : records) {
      Boolean changed = false;
      for (String field : templateValues.keySet()) {
        Object incoming = templateValues.get(field);
        Object existing = record.get(field);
        if (existing == incoming || (onlyIntoBlanks && !isBlank(existing))) {
          continue;
        }
        record.put(field, incoming);
        changed = true;
      }
      if (changed && work != null) {
        work.track(record);
      }
    }
  }

  private static Boolean isBlank(Object value) {
    return value == null || (value instanceof String && String.isBlank((String) value));
  }
}
