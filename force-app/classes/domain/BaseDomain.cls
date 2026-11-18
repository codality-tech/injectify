/**
 * Abstract base class for creating extensible Domain implementations.
 *
 * This class implements the Template Method pattern to ensure proper initialization
 * while providing a safe extension point for subscribers across namespace boundaries.
 *
 * Subscribers should extend this class (not Domain directly) and override the
 * onInitialized() method to add custom initialization logic.
 *
 * Example:
 * <pre>
 * global class AccountDomain extends inj.BaseDomain {
 *     global AccountDomain() {
 *         super();
 *     }
 *
 *     protected override void onInitialized(inj.IModel source, List&lt;SObject&gt; records) {
 *         // Base initialization is guaranteed to have completed
 *         // Add your custom initialization here
 *     }
 * }
 * </pre>
 *
 * @see Domain
 * @see IDomain
 */
global abstract class BaseDomain extends DomainRecords implements IDomain {
  /**
   * No-argument constructor for factory usage.
   */
  global BaseDomain() {
    super();
  }

  /**
   * Constructor that initializes with a model and records.
   *
   * Use this when you want to create a domain directly without the factory.
   * The factory can also call init() afterward - it's idempotent for the same model.
   *
   * Example subscriber usage:
   * <pre>
   * public class AccountDomain extends inj.BaseDomain {
   *   public AccountDomain(List<Account> records) {
   *     super(Application.s.model('Account'), records);
   *   }
   * }
   * </pre>
   *
   * @param source The model this domain operates on
   * @param records The records to manage
   */
  global BaseDomain(IModel source, List<SObject> records) {
    super();
    init(source, records);
  }

  /**
   * Initialize this domain with a model and records.
   *
   * This method implements the Template Method pattern:
   * 1. Calls super.init() to ensure base initialization
   * 2. Calls onInitialized() hook for custom initialization (only on first init)
   *
   * Note: This method is not overridable by subscribers in other namespaces.
   * Override onInitialized() instead to add custom initialization logic.
   *
   * @param source The model to initialize this domain with
   * @param records The records to manage
   */
  global override void init(IModel source, List<SObject> records) {
    // Check if already initialized before calling super.init()
    Boolean wasInitialized = this.isInitialized();
    super.init(source, records);
    // Only call onInitialized if this was the first initialization
    if (!wasInitialized) {
      onInitialized(source, records);
    }
  }

  /**
   * Hook method called after base initialization is complete.
   *
   * Override this method to add custom initialization logic. When this method
   * is called, the domain has already been fully initialized by the base class,
   * so all domain methods (source(), records(), base(), etc()) are safe to use.
   *
   * Default implementation does nothing.
   *
   * Note: This is declared as global virtual (not protected) to ensure visibility
   * across namespace boundaries for subscriber extension.
   *
   * Example:
   * <pre>
   * global override void onInitialized(inj.IModel source, List&lt;SObject&gt; records) {
   *     // Access Domain methods via the base() method for cross-namespace access
   *     List&lt;SObject&gt; filtered = this.base().filter(
   *         Application.s.eq(Account.IsActive__c, true)
   *     );
   * }
   * </pre>
   *
   * @param source The model this domain was initialized with
   * @param records The records being managed
   */
  global virtual void onInitialized(IModel source, List<SObject> records) {
    // Default implementation: do nothing
    // Subclasses override to add custom initialization
  }

  /**
   * Trigger hook called before insert or update operations (consolidated).
   *
   * This is the primary extension point for BEFORE trigger logic. Override this method
   * to add custom logic that runs before records are inserted OR updated.
   *
   * Check if oldMap is null to determine operation type:
   * - oldMap == null: INSERT operation (new records, no prior state)
   * - oldMap != null: UPDATE operation (modified records, compare with oldMap)
   *
   * Most domain logic should be the same for both insert and update (validation,
   * defaulting, etc.) and can ignore the operation type.
   *
   * Note: This is declared as global virtual override to ensure visibility
   * across namespace boundaries for subscriber extension.
   *
   * @param oldMap Map of record values before the operation (null for inserts, prior state for updates)
   * @see Domain
   */
  global virtual override void onBeforeUpsert(Map<Id, SObject> oldMap) {
    // Default implementation: no-op
    // Subclasses override to add custom insert/update logic
  }

  /**
   * Trigger hook called after insert or update operations (consolidated).
   *
   * This is the primary extension point for AFTER trigger logic. Override this method
   * to add custom logic that runs after records are inserted OR updated.
   *
   * Check if oldMap is null to determine operation type:
   * - oldMap == null: INSERT operation (newly created records)
   * - oldMap != null: UPDATE operation (modified records, compare with oldMap)
   *
   * Note: This is declared as global virtual override to ensure visibility
   * across namespace boundaries for subscriber extension.
   *
   * @param oldMap Map of record values before the operation (null for inserts, prior state for updates)
   * @see Domain
   */
  global virtual override void onAfterUpsert(Map<Id, SObject> oldMap) {
    // Default implementation: no-op
    // Subclasses override to add custom insert/update logic
  }

  /**
   * Trigger hook called before delete operations.
   *
   * Override this method to add custom logic that runs before records are deleted.
   * This method is called by the trigger framework during BEFORE_DELETE operations.
   *
   * The records being deleted are available via this.records.
   * Use this.toMap() if you need them as a Map<Id,SObject>.
   *
   * @see Domain
   */
  global virtual override void onBeforeDelete() {
    // Default implementation: no-op
    // Subclasses override to add custom logic
  }

  /**
   * Trigger hook called after delete operations.
   *
   * Override this method to add custom logic that runs after records are deleted.
   * This method is called by the trigger framework during AFTER_DELETE operations.
   *
   * The deleted records are available via this.records.
   * Use this.toMap() if you need them as a Map<Id,SObject>.
   *
   * @see Domain
   */
  global virtual override void onAfterDelete() {
    // Default implementation: no-op
    // Subclasses override to add custom logic
  }

  /**
   * Trigger hook called after undelete operations.
   *
   * Override this method to add custom logic that runs after records are undeleted.
   * This method is called by the trigger framework during AFTER_UNDELETE operations.
   *
   * @see Domain
   */
  global virtual override void onAfterUndelete() {
    // Default implementation: no-op
    // Subclasses override to add custom logic
  }

  /**
   * Get this domain instance as an IDomain interface for cross-namespace access.
   *
   * Since Domain is public (not global), this method provides access to all
   * Domain functionality across namespace boundaries by returning the global
   * IDomain interface.
   *
   * Example:
   * <pre>
   * protected override void onInitialized(inj.IModel source, List&lt;SObject&gt; records) {
   *     // Access Domain methods via base()
   *     List&lt;SObject&gt; filtered = this.base().filter(someCondition);
   *     Map&lt;String, List&lt;SObject&gt;&gt; segments = this.base().segment('Industry');
   * }
   * </pre>
   *
   * @return This domain instance cast to IDomain interface
   */
  global IDomain base() {
    return (IDomain) this;
  }

  global virtual override Boolean shouldRecycleInstance() {
    return true;
  }

  global virtual override Boolean shouldEnforceSecurity() {
    return super.shouldEnforceSecurity();
  }
}
