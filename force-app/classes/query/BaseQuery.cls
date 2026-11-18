/**
 * Base class for extensible query implementations.
 *
 * This abstract class provides the Template Method pattern for query initialization,
 * ensuring that base initialization always runs before custom initialization logic.
 *
 * Subscribers should extend this class instead of Query directly to create custom
 * query implementations with guaranteed proper initialization.
 *
 * Example:
 * <pre>
 * // App is the subscriber's own class holding its inj.Application
 * global class AccountQuery extends inj.BaseQuery {
 *     global override void onInitialized(inj.IModel source) {
 *         // Base initialization is guaranteed to have completed
 *         // Add your custom initialization here
 *     }
 *
 *     public AccountQuery forHighValue() {
 *         base().addCondition(App.s.gt(Account.AnnualRevenue, 1000000));
 *         return this;
 *     }
 * }
 * </pre>
 *
 * @see Query
 * @see IQuery
 */
global abstract inherited sharing class BaseQuery extends Query implements IQuery {
  /**
   * No-argument constructor for factory usage.
   */
  global BaseQuery() {
    super();
  }

  /**
   * Constructor that initializes with a model.
   *
   * Use this when you want to create a query directly without the factory.
   * The factory can also call init() afterward - it's idempotent for the same model.
   *
   * Example subscriber usage:
   * <pre>
   * global class AccountQuery extends inj.BaseQuery {
   *   global AccountQuery() {
   *     super(App.s.model(Account.SObjectType));
   *   }
   * }
   * </pre>
   *
   * @param model The model to initialize this query with
   */
  global BaseQuery(IModel model) {
    super();
    init(model);
  }

  /**
   * Copy constructor that initializes from another query.
   *
   * @param other Another BaseQuery to copy from
   */
  global BaseQuery(BaseQuery other) {
    super();
    init(other);
  }

  /**
   * Initialize this query with a model.
   *
   * This method implements the Template Method pattern:
   * 1. Calls super.init() to ensure base initialization
   * 2. Calls onInitialized() hook for custom initialization
   *
   * Note: This method is not overridable by subscribers in other namespaces.
   * Override onInitialized() instead to add custom initialization logic.
   *
   * @param source The model to initialize this query with
   */
  global override void init(IModel source) {
    // Check if already initialized to avoid calling onInitialized again
    boolean wasInitialized = this.source() != null;
    super.init(source);
    // Only call onInitialized if this was the first initialization
    if (!wasInitialized) {
      onInitialized(source);
    }
  }

  /**
   * Initialize this query by copying from another query.
   *
   * This is a copy operation that duplicates state from another query instance.
   * Copying binds this query to the other's model first, so onInitialized() does run
   * for the copy. The conditions, orderings, limit and offset it sets are then replaced
   * by the other query's, so nothing it adds is doubled.
   *
   * Subclasses cannot override this method.
   *
   * Note: This method is public (not global) because Query is a public class and
   * global methods cannot have public class parameters. Subscribers should not need
   * to call this directly across package boundaries.
   *
   * @param other Another Query to copy initialization from
   */
  public override void init(Query other) {
    // Query.init(Query) calls init(IModel), which runs onInitialized() once, and then
    // overwrites what the hook set with the other query's state.
    super.init(other);
  }

  /**
   * Hook method called after base initialization is complete.
   *
   * Override this method to add custom initialization logic. When this method
   * is called, the query has already been fully initialized by the base class,
   * so all query methods (fields(), filters(), source(), etc.) are safe to use.
   *
   * Default implementation does nothing.
   *
   * Note: This is declared as global virtual (not protected) to ensure visibility
   * across namespace boundaries for subscriber extension.
   *
   * Example:
   * <pre>
   * global override void onInitialized(inj.IModel source) {
   *     // Access Query methods via the base() method for cross-namespace access
   *     this.base().fields().add(new Set<SObjectField>{ Account.Name, Account.Type });
   *
   *     // Add default conditions
   *     this.base().addCondition(App.s.eq(Account.IsDeleted, false));
   *
   *     // Set default ordering
   *     this.base().orderings().add(App.s.ordering(Account.Name, true, false));
   * }
   * </pre>
   *
   * @param source The model this query was initialized with
   */
  global virtual void onInitialized(IModel source) {
    // Default implementation: do nothing
    // Subclasses override to add custom initialization
  }

  /**
   * Get the default fields for this query.
   *
   * Override this method to specify which fields should be automatically added
   * when this query is created by the QueryFactory. This is particularly useful
   * for defining standard field sets that should always be included.
   *
   * Return values:
   * - Set<SObjectField>: The specific fields to add by default
   * - null: All fields will be added (equivalent to addAll())
   *
   * Note: This method is called by QueryFactory during query instantiation.
   *
   * Example:
   * <pre>
   * global override Set<SObjectField> getDefaultFields() {
   *     return new Set<SObjectField>{ Account.Id, Account.Name, Account.Type };
   * }
   * </pre>
   *
   * @return Set of default fields to add, or null to add all fields
   */
  global virtual override Set<SObjectField> getDefaultFields() {
    return super.getDefaultFields();
  }

  /**
   * Get this query instance as an IQuery interface for cross-namespace access.
   *
   * Since Query is public (not global), subscribers in other namespaces cannot
   * directly access its methods. This global method returns this instance cast
   * to the global IQuery interface, providing access to all Query functionality.
   *
   * Example usage in a subscriber namespace:
   * <pre>
   * global class MyQuery extends inj.BaseQuery {
   *     global override void onInitialized(inj.IModel source) {
   *         // Access Query methods via base()
   *         this.base().setLimit(100);
   *         this.base().addCondition(...);
   *     }
   * }
   * </pre>
   *
   * @return This query instance cast to IQuery
   */
  global IQuery base() {
    return (IQuery) this;
  }

  /**
   * Create a deep clone of this query.
   *
   * Subclasses should override this method to return their own type.
   *
   * @return A deep clone of this query
   */
  public override virtual IQuery deepClone() {
    // Default to base Query behavior
    return super.deepClone();
  }
}
