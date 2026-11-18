/**
 * A unit of work: collects records to insert, update, upsert and delete, emails to send and
 * platform events to publish. apply() then performs them in dependency order.
 *
 *   - track(record) inserts a record that has no Id and updates one that has.
 *   - track(child, lookupField, parent) tracks both and fills the lookup once the parent has an
 *     Id, so records that do not exist yet can be related to each other.
 *   - track(records, externalIdField) upserts by an external Id.
 *   - Tracking the same Id from two instances gives one update. A different set of populated
 *     fields is merged onto the first instance; the same set replaces it.
 *   - purge() deletes. Types are ordered by the lookups populated on the records being
 *     deleted (children first), unless setOrder() names the order.
 *   - A platform event passed to track() is published instead of saved.
 *   - Work of each kind is grouped by SObjectType: one statement per type, and for inserts
 *     one per type per level of dependency.
 *
 * ACCESS: DML runs in system mode (stated explicitly), as Apex does by default, and the class
 * inherits the caller's sharing. withSharing(true) runs every insert, update, upsert and delete
 * in user mode instead: the running user's object permissions, field permissions and sharing
 * apply, and the platform refuses a statement that breaks them. Emails and events are unaffected.
 *
 * PARTIAL SUCCESS: with options().optAllOrNone = false the records the platform refuses are
 * left out and the rest are saved. failures() then lists every record that was not saved and
 * why, and failureOf(record) answers for one. A record that depends on a new record which
 * failed is held back with it: a child is not inserted without its parent, and an existing
 * record that was to be related to it is not updated at all.
 *
 * LIMITS: types that refer to each other in both directions cannot be ordered for a purge;
 * the cycle is skipped and the delete may then fail, so name the order with setOrder().
 * New records that depend on each other in a cycle are refused with a WorkException.
 *
 * The order of operations, partial success and the errors are described, with examples that
 * run as subscriber tests, in docs/documentation/work-guide.md.
 */
public inherited sharing class Work implements IWork {
  public static Work make() {
    return new Work(new SchemeDefault());
  }

  public class WorkException extends Exception {
  }

  //* State
  private IScheme scheme;
  private Database.DmlOptions dmlOptions;
  private Boolean userMode = false;
  private List<SObjectType> purgeOrder;
  private Map<SObjectType, List<SObject>> newRecords = new Map<SObjectType, List<SObject>>();
  private Map<SObjectType, List<SObject>> dirtyRecords = new Map<SObjectType, List<SObject>>();
  private Map<SObjectType, List<SObject>> purgeRecords = new Map<SObjectType, List<SObject>>();
  private Map<SObjectType, Map<SObjectField, List<SObject>>> upsertRecords = new Map<SObjectType, Map<SObjectField, List<SObject>>>();
  private Map<SObjectType, List<IRelationship>> relationships = new Map<SObjectType, List<IRelationship>>();
  private List<Messaging.Email> emails = new List<Messaging.Email>();
  private List<SObject> events = new List<SObject>();
  private List<IWorkFailure> failed = new List<IWorkFailure>();
  // The failures by how their record looks, built when first asked for; see failureOf().
  private Map<Integer, List<IWorkFailure>> failedByLook;

  //* Constructors
  public Work(IScheme scheme) {
    this.scheme = scheme != null ? scheme : new SchemeDefault();
    this.dmlOptions = new Database.DmlOptions();
    this.dmlOptions.optAllOrNone = true; // Default Salesforce behavior
  }

  public Work() {
    this(null); // Use default scheme
  }

  //* Interface Implementation

  public IWork track(SObject record) {
    if (record == null)
      return this;

    // A platform event is published, not saved
    if (isEvent(record.getSObjectType())) {
      events.add(record);
      return this;
    }

    // Determine DML operation based on record state
    if (record.Id == null) {
      // New record - insert
      registerForInsert(record);
    } else {
      // Existing record - update
      registerForUpdate(record);
    }
    return this;
  }

  // Whether each object type met so far is a platform event, so the describe is asked for once
  // per type and not once per record.
  private Map<SObjectType, Boolean> eventTypes = new Map<SObjectType, Boolean>();

  private Boolean isEvent(SObjectType kind) {
    Boolean known = eventTypes.get(kind);
    if (known == null) {
      Schema.DescribeSObjectResult shape = scheme.getDescribe(kind);
      known = shape.isCustom() && shape.getName().endsWith('__e');
      eventTypes.put(kind, known);
    }
    return known;
  }

  public IWork track(List<SObject> records) {
    if (records == null)
      return this;
    for (SObject record : records) {
      track(record);
    }
    return this;
  }

  public IWork track(
    SObject record,
    SObjectField relatedToField,
    SObject relatedTo
  ) {
    track(record);
    track(relatedTo);
    relate(record, relatedToField, relatedTo);
    return this;
  }

  public IWork track(
    SObject record,
    SObjectField relatedToField,
    SObjectField externalIdField,
    String externalId
  ) {
    track(record);
    relate(record, relatedToField, externalIdField, externalId);
    return this;
  }

  public IWork track(List<SObject> records, SObjectField externalIdField) {
    if (records == null || records.isEmpty())
      return this;
    if (externalIdField == null) {
      throw new WorkException('externalIdField cannot be null');
    }
    if (!scheme.getFieldDescribe(externalIdField).isExternalId()) {
      throw new WorkException('externalIdField must be marked as External ID');
    }
    registerForUpsert(records, externalIdField);
    return this;
  }

  public IWork purge(SObject record) {
    if (record == null)
      return this;
    registerForPurge(record);
    return this;
  }

  public IWork purge(List<SObject> records) {
    if (records == null)
      return this;
    for (SObject record : records) {
      purge(record);
    }
    return this;
  }

  //* Non-DML Work

  public IWork track(Messaging.Email email) {
    if (email != null) {
      emails.add(email);
    }
    return this;
  }

  public IWork track(List<Messaging.Email> emails) {
    if (emails != null) {
      this.emails.addAll(emails);
    }
    return this;
  }

  //* Configuration

  public Database.DmlOptions options() {
    return this.dmlOptions;
  }

  /** True runs the DML in user mode; false or null puts it back in system mode. */
  public IWork withSharing(Boolean enforce) {
    userMode = enforce == true;
    return this;
  }

  private System.AccessLevel accessLevel() {
    return userMode ? System.AccessLevel.USER_MODE : System.AccessLevel.SYSTEM_MODE;
  }

  public IWork setOrder(List<SObjectType> purgeOrder) {
    this.purgeOrder = purgeOrder;
    return this;
  }

  public void apply() {
    if (!hasWork()) {
      return;
    }

    Boolean success = false;
    try {
      // Execute DML operations in order: purge, insert, resolve relationships, update, upsert
      executePurges();
      executeInserts();
      resolveRelationships();
      executeUpdates();
      executeUpserts();

      // Execute non-DML work
      sendEmails();

      // Publish events last - respects event configuration (immediate vs transaction-bound)
      // Events with publishImmediately=true will send even on rollback (fire-and-forget)
      // Events with default behavior only send if transaction commits
      publishEvents();

      success = true;
    } catch (Exception e) {
      // No explicit rollback needed - Salesforce automatically rolls back on exception
      throw e;
    }
  }

  public Boolean hasWork() {
    return hasNewRecords() ||
      hasDirtyRecords() ||
      hasPurgeRecords() ||
      hasUpsertRecords() ||
      !emails.isEmpty() ||
      !events.isEmpty();
  }

  //* Partial success

  public List<IWorkFailure> failures() {
    return new List<IWorkFailure>(failed);
  }

  /**
   * Records compare by their field values, so the failures are looked up by how the record looks
   * and then matched by instance. Ask before changing the record again.
   */
  public IWorkFailure failureOf(SObject record) {
    if (record == null || failed.isEmpty()) {
      return null;
    }
    if (failedByLook == null) {
      failedByLook = new Map<Integer, List<IWorkFailure>>();
      for (IWorkFailure failure : failed) {
        Integer look = System.hashCode(failure.getRecord());
        if (!failedByLook.containsKey(look)) {
          failedByLook.put(look, new List<IWorkFailure>());
        }
        failedByLook.get(look).add(failure);
      }
    }
    List<IWorkFailure> alike = failedByLook.get(System.hashCode(record));
    for (IWorkFailure failure : alike ?? new List<IWorkFailure>()) {
      if (failure.getRecord() === record) {
        return failure;
      }
    }
    return null;
  }

  private void fail(SObject record, List<Database.Error> errors, String reason) {
    failed.add(new Failure(record, errors, reason));
    failedByLook = null;
  }

  // The record was not saved because one it depends on was not.
  private void holdBack(SObject record, SObject unsaved) {
    String parent = scheme.getDescribe(unsaved.getSObjectType()).getLabel();
    fail(record, null, 'Not saved: the ' + parent + ' it is related to was not saved');
  }

  private void note(List<SObject> records, List<Database.SaveResult> outcomes) {
    for (Integer at = 0; at < outcomes.size(); at++) {
      if (!outcomes[at].isSuccess()) {
        fail(records[at], outcomes[at].getErrors(), null);
      }
    }
  }

  private void note(List<SObject> records, List<Database.UpsertResult> outcomes) {
    for (Integer at = 0; at < outcomes.size(); at++) {
      if (!outcomes[at].isSuccess()) {
        fail(records[at], outcomes[at].getErrors(), null);
      }
    }
  }

  private void note(List<SObject> records, List<Database.DeleteResult> outcomes) {
    for (Integer at = 0; at < outcomes.size(); at++) {
      if (!outcomes[at].isSuccess()) {
        fail(records[at], outcomes[at].getErrors(), null);
      }
    }
  }

  //* Private helper methods

  // New records grouped by how they look (their value hash), so tracking the same instance twice
  // (say, a parent shared by several track calls) can be caught with an identity check. Two
  // records that merely look alike are still two records.
  private Map<Integer, List<SObject>> newByLook = new Map<Integer, List<SObject>>();

  private void registerForInsert(SObject record) {
    Integer look = System.hashCode(record);
    List<SObject> alike = newByLook.get(look);
    if (alike == null) {
      alike = new List<SObject>();
      newByLook.put(look, alike);
    }
    for (SObject seen : alike) {
      if (seen === record) {
        return;
      }
    }
    alike.add(record);
    SObjectType sObjectType = record.getSObjectType();
    if (!newRecords.containsKey(sObjectType)) {
      newRecords.put(sObjectType, new List<SObject>());
    }
    newRecords.get(sObjectType).add(record);
  }

  // Where each existing record sits in its type's list of updates, by Id.
  private Map<Id, Integer> dirtyPlaces = new Map<Id, Integer>();
  // Existing records left out of the updates because a new record they depend on was not saved.
  private List<SObject> withheld = new List<SObject>();

  private void registerForUpdate(SObject record) {
    SObjectType sObjectType = record.getSObjectType();
    if (!dirtyRecords.containsKey(sObjectType)) {
      dirtyRecords.put(sObjectType, new List<SObject>());
    }
    List<SObject> records = dirtyRecords.get(sObjectType);

    // The first time an Id is tracked it takes the next place in its type's list. The place is
    // remembered by Id, so tracking many records does not search the list for each one.
    Id incomingId = record.Id;
    Integer place = dirtyPlaces.get(incomingId);
    if (place == null) {
      dirtyPlaces.put(incomingId, records.size());
      records.add(record);
      return;
    }

    // Tracked before: merge onto the entry that is there.
    SObject current = records[place];
    if (current == record) {
      return;
    }
    Map<String, Object> inc = new Map<String, Object>(record.getPopulatedFieldsAsMap());
    Map<String, Object> cur = new Map<String, Object>(current.getPopulatedFieldsAsMap());
    inc.remove('Id');
    cur.remove('Id');
    if (inc.keySet().equals(cur.keySet())) {
      // The same set of fields: the later instance replaces the earlier
      records[place] = record;
    } else {
      // A different set: the later instance's fields are copied onto the earlier
      for (String key : inc.keySet()) {
        current.put(key, inc.get(key));
      }
    }
  }

  private void registerForPurge(SObject record) {
    if (record.Id == null) {
      throw new WorkException('New records cannot be registered for purge');
    }

    SObjectType sObjectType = record.getSObjectType();
    if (!purgeRecords.containsKey(sObjectType)) {
      purgeRecords.put(sObjectType, new List<SObject>());
    }
    purgeRecords.get(sObjectType).add(record);
  }

  private void registerForUpsert(
    List<SObject> records,
    SObjectField externalIdField
  ) {
    if (records == null || records.isEmpty())
      return;

    SObjectType sObjectType = records[0].getSObjectType();
    if (!upsertRecords.containsKey(sObjectType)) {
      upsertRecords.put(sObjectType, new Map<SObjectField, List<SObject>>());
    }
    Map<SObjectField, List<SObject>> fieldMap = upsertRecords.get(sObjectType);
    if (!fieldMap.containsKey(externalIdField)) {
      fieldMap.put(externalIdField, new List<SObject>());
    }
    fieldMap.get(externalIdField).addAll(records);
  }

  private void relate(
    SObject record,
    SObjectField relatedToField,
    SObject relatedTo
  ) {
    if (relatedToField == null) {
      throw new WorkException('relatedToField cannot be null');
    }

    SObjectType sObjectType = record.getSObjectType();
    if (!relationships.containsKey(sObjectType)) {
      relationships.put(sObjectType, new List<IRelationship>());
    }

    Relationship rel = new Relationship();
    rel.record = record;
    rel.relatedToField = relatedToField;
    rel.relatedTo = relatedTo;

    relationships.get(sObjectType).add(rel);
  }

  private void relate(
    SObject record,
    SObjectField relatedToField,
    SObjectField externalIdField,
    String externalId
  ) {
    if (relatedToField == null) {
      throw new WorkException('relatedToField cannot be null');
    }

    if (externalIdField == null) {
      throw new WorkException('externalIdField cannot be null');
    }

    if (!scheme.getFieldDescribe(externalIdField).isExternalId()) {
      throw new WorkException('externalIdField must be marked as External ID');
    }

    SObjectType sObjectType = record.getSObjectType();
    if (!relationships.containsKey(sObjectType)) {
      relationships.put(sObjectType, new List<IRelationship>());
    }

    RelationshipByExternalId rel = new RelationshipByExternalId(scheme);
    rel.record = record;
    rel.relatedToField = relatedToField;
    rel.externalIdField = externalIdField;
    rel.externalId = externalId;

    relationships.get(sObjectType).add(rel);
  }

  private Boolean hasNewRecords() {
    for (List<SObject> records : newRecords.values()) {
      if (!records.isEmpty()) {
        return true;
      }
    }
    return false;
  }

  private Boolean hasDirtyRecords() {
    for (List<SObject> records : dirtyRecords.values()) {
      if (!records.isEmpty()) {
        return true;
      }
    }
    return false;
  }

  private Boolean hasPurgeRecords() {
    for (List<SObject> records : purgeRecords.values()) {
      if (!records.isEmpty()) {
        return true;
      }
    }
    return false;
  }

  private Boolean hasUpsertRecords() {
    for (Map<SObjectField, List<SObject>> fieldMap : upsertRecords.values()) {
      for (List<SObject> records : fieldMap.values()) {
        if (!records.isEmpty()) {
          return true;
        }
      }
    }
    return false;
  }

  // One DML statement per object type (and per insert level): the loop is bounded by the number
  // of types tracked, not by the number of records.
  @SuppressWarnings('PMD.OperationWithLimitsInLoop')
  private void executePurges() {
    List<SObjectType> sortedTypes;

    // Use manual order if set (trust the developer), otherwise use automatic ordering
    if (purgeOrder != null && !purgeOrder.isEmpty()) {
      // Validate that manual order includes all SObjectTypes being purged
      Set<SObjectType> orderedTypes = new Set<SObjectType>(purgeOrder);
      Set<SObjectType> actualTypes = purgeRecords.keySet();

      if (
        orderedTypes.size() != actualTypes.size() ||
        !orderedTypes.containsAll(actualTypes)
      ) {
        // Find missing types
        Set<SObjectType> missingTypes = new Set<SObjectType>(actualTypes);
        missingTypes.removeAll(orderedTypes);

        String missingTypeNames = String.join(
          new List<String>(getTypeNames(missingTypes)),
          ', '
        );

        throw new WorkException(
          'Purge order is incomplete. Missing SObjectTypes: ' + missingTypeNames
        );
      }

      sortedTypes = purgeOrder;
    } else {
      sortedTypes = sortPurgeRecordsByDependency();
    }

    // Delete in dependency order (children before parents)
    for (SObjectType sObjectType : sortedTypes) {
      List<SObject> records = purgeRecords.get(sObjectType);
      if (records != null && !records.isEmpty()) {
        note(records, Database.delete(records, dmlOptions.optAllOrNone, accessLevel()));
      }
    }
  }

  // Helper method to get type names from Set<SObjectType>
  private Set<String> getTypeNames(Set<SObjectType> types) {
    Set<String> names = new Set<String>();
    for (SObjectType t : types) {
      names.add(t.getDescribe().getName());
    }
    return names;
  }

  /*
   * Automatic Dependency-Based Purge Ordering
   *
   * PROBLEM: Deleting records in wrong order causes FK constraint violations.
   * Example: Deleting Account before Contact fails because Contact.AccountId references it.
   *
   * SOLUTION: Topological sort based on POPULATED FK relationships in actual records.
   *
   * ALGORITHM:
   *   1. Build dependency graph: For each record being purged, analyze ONLY populated
   *      reference fields to see if they point to other records also being purged
   *   2. Use depth-first topological sort to determine ordering
   *   3. Reverse result (children before parents for deletion)
   *
   * DESIGN DECISIONS:
   *   - Analyzes ONLY populated reference fields, not all schema fields
   *     Rationale: Prevents false dependencies (e.g., Contact has unused Product lookup)
   *   - Instance-based (not schema-based): Uses actual FK values from records
   *   - Handles circular dependencies gracefully (detects via "visiting" set, continues)
   *     Impact: May fail at runtime if both sides of circular FK populated (platform limitation)
   *
   * EXAMPLE:
   *   Records: Contact[AccountId=001...], Opportunity[AccountId=001...], Account[Id=001...]
   *   Populated FKs: Contact.AccountId → 001, Opportunity.AccountId → 001
   *   Result order: [Contact, Opportunity, Account] (children first)
   *
   * PERFORMANCE:
   *   - Time Complexity: O(R * F) where R = # records, F = avg # populated fields per record
   *   - Space Complexity: O(T^2) for dependency map (T = # SObjectTypes)
   *   - Much faster than schema-based approach (no field metadata lookups)
   *
   * @return List of SObjectTypes in safe deletion order (children before parents)
   */
  private List<SObjectType> sortPurgeRecordsByDependency() {
    // Build a map of all record IDs being purged, grouped by SObjectType
    // This allows fast lookup: "Is this FK value pointing to a record we're deleting?"
    Map<Id, SObjectType> purgeIdToType = new Map<Id, SObjectType>();
    Set<SObjectType> allTypes = purgeRecords.keySet();

    for (SObjectType sObjectType : allTypes) {
      List<SObject> records = purgeRecords.get(sObjectType);
      if (records != null) {
        for (SObject record : records) {
          if (record.Id != null) {
            purgeIdToType.put(record.Id, sObjectType);
          }
        }
      }
    }

    // Build dependency graph: SObjectType -> Set of SObjectTypes it depends on
    Map<SObjectType, Set<SObjectType>> dependencies = new Map<SObjectType, Set<SObjectType>>();
    for (SObjectType sObjectType : allTypes) {
      dependencies.put(sObjectType, new Set<SObjectType>());
    }

    // Analyze populated FK fields in actual records
    for (SObjectType sObjectType : allTypes) {
      List<SObject> records = purgeRecords.get(sObjectType);
      if (records == null)
        continue;

      // Get field metadata for this SObjectType (cached by platform)
      Map<String, Schema.SObjectField> fieldMap = scheme.getFieldMap(
        sObjectType
      );

      for (SObject record : records) {
        // Only analyze populated fields (reduces unnecessary work)
        Map<String, Object> populatedFields = record.getPopulatedFieldsAsMap();

        for (String fieldName : populatedFields.keySet()) {
          // Skip Id field (not a FK)
          if (fieldName == 'Id')
            continue;

          Schema.SObjectField field = fieldMap.get(fieldName);
          if (field == null)
            continue;

          // Check if this is a reference field
          Schema.DescribeFieldResult fieldDescribe = scheme.getFieldDescribe(
            field
          );
          if (fieldDescribe.getType() != Schema.DisplayType.REFERENCE) {
            continue;
          }

          // Get the FK value
          Object fkValue = record.get(field);
          if (fkValue == null)
            continue;

          Id referencedId = (Id) fkValue;

          // Check if the referenced record is ALSO being purged
          SObjectType referencedType = purgeIdToType.get(referencedId);
          if (referencedType != null) {
            // This record depends on the referenced record
            // (must delete this BEFORE the referenced record)
            dependencies.get(sObjectType).add(referencedType);
          }
        }
      }
    }

    // Topological sort to determine deletion order
    List<SObjectType> sorted = new List<SObjectType>();
    Set<SObjectType> visited = new Set<SObjectType>();
    Set<SObjectType> visiting = new Set<SObjectType>();

    for (SObjectType sObjectType : allTypes) {
      if (!visited.contains(sObjectType)) {
        topologicalSortVisit(
          sObjectType,
          dependencies,
          visited,
          visiting,
          sorted
        );
      }
    }

    // Reverse the list for deletion order (children before parents)
    List<SObjectType> deletionOrder = new List<SObjectType>();
    for (Integer i = sorted.size() - 1; i >= 0; i--) {
      deletionOrder.add(sorted[i]);
    }

    return deletionOrder;
  }

  /*
   * Depth-First Topological Sort (Recursive)
   *
   * ALGORITHM: Post-order depth-first traversal
   *   1. Mark current node as "visiting" (cycle detection)
   *   2. Recursively visit all dependencies (parents)
   *   3. Mark current as "visited"
   *   4. Add current to sorted list (post-order ensures parents added after children)
   *
   * CIRCULAR DEPENDENCY HANDLING:
   *   - If node is in "visiting" set → cycle detected → skip and continue
   *   - Rationale: Salesforce allows circular references (e.g., Account.ParentId → Account)
   *   - Impact: Some deletions may fail at runtime if circular FK populated, but won't infinite loop
   *
   * STACK DEPTH LIMITS:
   *   - Recursive depth = max FK chain depth in schema
   *   - Typical Salesforce schemas: < 10 levels deep
   *   - Apex stack limit: ~1000 frames (far exceeds typical schema depth)
   *   - Edge case: Pathological 50+ level hierarchy could theoretically exhaust stack (unlikely)
   *
   * VISITED vs VISITING:
   *   - visited: Node fully processed (all descendants explored)
   *   - visiting: Node currently in call stack (used to detect cycles)
   *
   * @param current The SObjectType currently being visited
   * @param dependencies Map of each SObjectType to its parent dependencies
   * @param visited Set of fully processed nodes
   * @param visiting Set of nodes in current recursion path (cycle detection)
   * @param sorted Output list in topological order (built via post-order traversal)
   */
  private void topologicalSortVisit(
    SObjectType current,
    Map<SObjectType, Set<SObjectType>> dependencies,
    Set<SObjectType> visited,
    Set<SObjectType> visiting,
    List<SObjectType> sorted
  ) {
    if (visiting.contains(current)) {
      // Circular dependency detected - skip this path to avoid infinite recursion
      // Example: Account.ParentId → Account (self-reference)
      return;
    }

    if (visited.contains(current)) {
      // Already processed this node in another path
      return;
    }

    visiting.add(current); // Mark as currently being explored

    Set<SObjectType> deps = dependencies.get(current);
    if (deps != null) {
      // Recursively visit all parent dependencies first (depth-first)
      for (SObjectType dep : deps) {
        topologicalSortVisit(dep, dependencies, visited, visiting, sorted);
      }
    }

    visiting.remove(current); // Remove from active path
    visited.add(current); // Mark as fully processed
    sorted.add(current); // Add to result (post-order = parents added after children)
  }

  /*
   * Inserts the new records in dependency order. Every record is numbered once, before anything
   * changes it, and the plan works by number: SObjects compare and hash by field values, so they
   * cannot key the plan (equal records would merge, and filling a lookup would move a key).
   * A record's level is one more than its deepest new parent's. Before a level is inserted, the
   * lookups of its records are filled from parents that have Ids by then; each level goes in as
   * one insert per object type.
   */
  // One DML statement per object type (and per insert level): the loop is bounded by the number
  // of types tracked, not by the number of records.
  @SuppressWarnings('PMD.OperationWithLimitsInLoop')
  private void executeInserts() {
    List<SObject> pending = new List<SObject>();
    Map<Integer, List<Integer>> positionsByLook = new Map<Integer, List<Integer>>();
    for (List<SObject> ofType : newRecords.values()) {
      for (SObject record : ofType) {
        if (positionOf(record, pending, positionsByLook) == null) {
          Integer look = System.hashCode(record);
          if (!positionsByLook.containsKey(look)) {
            positionsByLook.put(look, new List<Integer>());
          }
          positionsByLook.get(look).add(pending.size());
          pending.add(record);
        }
      }
    }
    if (pending.isEmpty()) {
      return;
    }

    List<Set<Integer>> newParents = new List<Set<Integer>>();
    List<List<Relationship>> lookups = new List<List<Relationship>>();
    for (Integer at = 0; at < pending.size(); at++) {
      newParents.add(new Set<Integer>());
      lookups.add(new List<Relationship>());
    }
    for (List<IRelationship> ofType : relationships.values()) {
      for (IRelationship candidate : ofType) {
        Relationship link = candidate instanceof Relationship ? (Relationship) candidate : null;
        if (link == null || link.relatedTo == null) {
          continue;
        }
        Integer child = positionOf(link.record, pending, positionsByLook);
        if (child == null) {
          continue;
        }
        lookups[child].add(link);
        Integer parent = positionOf(link.relatedTo, pending, positionsByLook);
        if (parent != null) {
          newParents[child].add(parent);
        }
      }
    }

    Integer[] levels = new Integer[pending.size()];
    Integer deepest = 0;
    for (Integer at = 0; at < pending.size(); at++) {
      deepest = Math.max(deepest, levelOf(at, newParents, levels, new Set<Integer>()));
    }

    for (Integer level = 0; level <= deepest; level++) {
      Map<SObjectType, List<SObject>> batches = new Map<SObjectType, List<SObject>>();
      for (Integer at = 0; at < pending.size(); at++) {
        if (levels[at] != level) {
          continue;
        }
        // A new parent sits on a lower level, so by now it has an Id unless it was not saved,
        // which only partial success allows. Its child is then not inserted without it.
        SObject unsaved = null;
        for (Relationship link : lookups[at]) {
          if (link.relatedTo.Id != null) {
            link.resolve();
          } else {
            unsaved = link.relatedTo;
          }
        }
        if (unsaved != null && allowsPartialSuccess()) {
          holdBack(pending[at], unsaved);
          continue;
        }
        SObjectType kind = pending[at].getSObjectType();
        if (!batches.containsKey(kind)) {
          batches.put(kind, new List<SObject>());
        }
        batches.get(kind).add(pending[at]);
      }
      for (List<SObject> batch : batches.values()) {
        note(batch, Database.insert(batch, dmlOptions, accessLevel()));
      }
    }
  }

  // The position of this very instance among the pending records, or null.
  private static Integer positionOf(SObject record, List<SObject> pending, Map<Integer, List<Integer>> positionsByLook) {
    List<Integer> candidates = record == null ? null : positionsByLook.get(System.hashCode(record));
    if (candidates != null) {
      for (Integer at : candidates) {
        if (pending[at] === record) {
          return at;
        }
      }
    }
    return null;
  }

  // One more than the deepest new parent's level; records without new parents are level 0.
  private static Integer levelOf(Integer at, List<Set<Integer>> newParents, Integer[] levels, Set<Integer> onPath) {
    if (levels[at] != null) {
      return levels[at];
    }
    if (!onPath.add(at)) {
      throw new WorkException('New records depend on each other in a cycle, so they cannot be inserted in order');
    }
    Integer level = 0;
    for (Integer parent : newParents[at]) {
      level = Math.max(level, levelOf(parent, newParents, levels, onPath) + 1);
    }
    onPath.remove(at);
    levels[at] = level;
    return level;
  }

  private void resolveRelationships() {
    List<SObject> recordsToUpdate = new List<SObject>();
    Set<Id> seenIds = new Set<Id>();

    for (SObjectType sObjectType : relationships.keySet()) {
      List<IRelationship> rels = relationships.get(sObjectType);
      for (IRelationship rel : rels) {
        // Skip relationships that were already resolved during executeInserts
        // (new-to-new relationships where child was just inserted)
        Boolean alreadyResolved = false;
        if (rel instanceof Relationship) {
          Relationship r = (Relationship) rel;
          // The parent was new and was not saved (partial success). A new child was held back
          // when its level was inserted; an existing record is left as it is, other changes too.
          if (r.relatedTo != null && r.relatedTo.Id == null && allowsPartialSuccess()) {
            if (r.record.Id != null && !isAmong(withheld, r.record)) {
              withheld.add(r.record);
              holdBack(r.record, r.relatedTo);
            }
            continue;
          }
          // If child now has Id and parent has Id, and the FK is already set, skip
          if (
            r.record.Id != null &&
            r.relatedTo.Id != null &&
            r.record.get(r.relatedToField) == r.relatedTo.Id
          ) {
            alreadyResolved = true;
          }
        }

        if (!alreadyResolved) {
          rel.resolve();
        }

        // If the record was newly inserted, we need to update it to persist the relationship
        SObject record = rel.getRecord();
        if (
          !alreadyResolved &&
          record.Id != null &&
          record.getSObjectType() == sObjectType
        ) {
          if (!seenIds.contains((Id) record.get('Id'))) {
            recordsToUpdate.add(record);
            seenIds.add((Id) record.get('Id'));
          }
        }
      }
    }

    // Update records with resolved relationships. One that was withheld after an earlier
    // relationship had queued it is not updated either.
    recordsToUpdate = notWithheld(recordsToUpdate);
    if (!recordsToUpdate.isEmpty()) {
      note(recordsToUpdate, Database.update(recordsToUpdate, dmlOptions, accessLevel()));
    }
  }

  private List<SObject> notWithheld(List<SObject> records) {
    if (withheld.isEmpty()) {
      return records;
    }
    List<SObject> kept = new List<SObject>();
    for (SObject record : records) {
      if (!isAmong(withheld, record)) {
        kept.add(record);
      }
    }
    return kept;
  }

  private Boolean allowsPartialSuccess() {
    return dmlOptions.optAllOrNone == false;
  }

  // Whether this very instance is in the list. List.contains would compare field values.
  private static Boolean isAmong(List<SObject> records, SObject record) {
    for (SObject candidate : records) {
      if (candidate === record) {
        return true;
      }
    }
    return false;
  }

  // One DML statement per object type (and per insert level): the loop is bounded by the number
  // of types tracked, not by the number of records.
  @SuppressWarnings('PMD.OperationWithLimitsInLoop')
  private void executeUpdates() {
    for (SObjectType sObjectType : dirtyRecords.keySet()) {
      List<SObject> records = notWithheld(dirtyRecords.get(sObjectType));
      if (!records.isEmpty()) {
        note(records, Database.update(records, dmlOptions, accessLevel()));
      }
    }
  }

  // One DML statement per object type (and per insert level): the loop is bounded by the number
  // of types tracked, not by the number of records.
  @SuppressWarnings('PMD.OperationWithLimitsInLoop')
  private void executeUpserts() {
    for (SObjectType sObjectType : upsertRecords.keySet()) {
      Map<SObjectField, List<SObject>> fieldMap = upsertRecords.get(
        sObjectType
      );
      for (SObjectField externalIdField : fieldMap.keySet()) {
        List<SObject> records = fieldMap.get(externalIdField);
        if (!records.isEmpty()) {
          refuseUpsertOnUnreachableObject(sObjectType);
          note(records, Database.upsert(records, externalIdField, dmlOptions.optAllOrNone, accessLevel()));
        }
      }
    }
  }

  // An all-or-none upsert on an external Id, in user mode, by a user with no access to the object
  // ends the transaction with an error Apex cannot catch. An insert, update or delete in the same
  // position throws a SecurityException, so this throws that one, worded as the platform words it.
  private void refuseUpsertOnUnreachableObject(SObjectType sObjectType) {
    if (!userMode || dmlOptions.optAllOrNone == false) {
      return;
    }
    DescribeSObjectResult target = scheme.getDescribe(sObjectType);
    if (!target.isAccessible()) {
      throw new System.SecurityException('Access to entity \'' + target.getName() + '\' denied');
    }
  }

  private void sendEmails() {
    if (!emails.isEmpty() && !Test.isRunningTest()) {
      Messaging.sendEmail(emails);
    }
  }

  private void publishEvents() {
    if (!events.isEmpty()) {
      EventBus.publish(events);
    }
  }

  private class Failure implements IWorkFailure {
    private SObject record;
    private List<Database.Error> errors;
    private String reason;

    Failure(SObject record, List<Database.Error> errors, String reason) {
      this.record = record;
      this.errors = errors ?? new List<Database.Error>();
      this.reason = reason;
    }

    public SObject getRecord() {
      return record;
    }

    public List<Database.Error> getErrors() {
      return errors;
    }

    public String getMessage() {
      if (reason != null) {
        return reason;
      }
      List<String> said = new List<String>();
      for (Database.Error each : errors) {
        said.add(each.getMessage());
      }
      return String.join(said, '; ');
    }
  }

  //* Interfaces

  private interface IRelationship {
    void resolve();
    SObject getRecord();
  }

  private class Relationship implements IRelationship {
    public SObject record;
    public SObjectField relatedToField;
    public SObject relatedTo;

    public void resolve() {
      record.put(relatedToField, relatedTo.Id);
    }

    public SObject getRecord() {
      return record;
    }
  }

  private class RelationshipByExternalId implements IRelationship {
    public SObject record;
    public SObjectField relatedToField;
    public SObjectField externalIdField;
    public String externalId;
    private IScheme scheme;

    public RelationshipByExternalId(IScheme scheme) {
      this.scheme = scheme;
    }

    public void resolve() {
      String relationshipName = scheme.getFieldDescribe(relatedToField)
        .getRelationshipName();
      if (String.isNotBlank(relationshipName)) {
        SObject relationshipObject = record.getSObject(relationshipName);
        if (relationshipObject == null) {
          // Create a new relationship object
          List<SObjectType> relatedObjects = scheme.getFieldDescribe(
              relatedToField
            )
            .getReferenceTo();
          if (!relatedObjects.isEmpty()) {
            relationshipObject = relatedObjects[0].newSObject();
          }
        }
        if (relationshipObject != null) {
          relationshipObject.put(
            scheme.getFieldDescribe(externalIdField).getName(),
            externalId
          );
          record.putSObject(relationshipName, relationshipObject);
        }
      }
    }

    public SObject getRecord() {
      return record;
    }
  }
}
