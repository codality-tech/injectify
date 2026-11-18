/**
 * Represents an aggregate function (COUNT, SUM, AVG, MIN, MAX, COUNT_DISTINCT)
 * that can be used in SELECT and HAVING clauses of aggregate queries.
 *
 * Examples:
 *   COUNT(Id)
 *   SUM(Amount)
 *   AVG(Amount)
 *   MIN(CloseDate)
 *   MAX(Amount)
 *   COUNT_DISTINCT(AccountId)
 *
 * Usage in conditions:
 *   Application.s.gt(Application.s.count(Opportunity.Id), 5)
 *   Application.s.ge(Application.s.sum(Opportunity.Amount), 100000)
 */
global interface IAggregateFunction {
  /**
   * The aggregate function name (COUNT, SUM, AVG, MIN, MAX, COUNT_DISTINCT)
   */
  String functionName();

  /**
   * The field being aggregated (SObjectField, IPath, or null for COUNT())
   */
  Object field();

  /**
   * Generates SOQL representation without alias
   * Examples: COUNT(Id), SUM(Amount), COUNT()
   */
  String toSoql();

  /**
   * Compares this aggregate function to another object for equality.
   * Two aggregate functions are equal if they have the same function name
   * and operate on the same field.
   */
  Boolean equals(Object other);

  /**
   * Returns hash code for this aggregate function.
   * Required for use in Maps and Sets.
   */
  Integer hashCode();

  /**
   * Returns the alias for this aggregate function in SOQL SELECT clause.
   * If an alias was explicitly set via setAlias(), returns that value.
   * Otherwise, returns an auto-generated alias based on the pattern:
   *   - {fieldname}_{suffix} (e.g., Amount_sum, Id_cnt)
   *   - Suffixes: cnt, sum, avg, min, max, dis
   *   - No-field COUNT() becomes 'cnt'
   */
  String getAlias();

  /**
   * Sets a custom alias for this aggregate function, overriding auto-generation.
   * Returns this instance for fluent chaining.
   *
   * Example:
   *   Application.s.sum(Opportunity.Amount).setAlias('total_revenue')
   */
  IAggregateFunction setAlias(String alias);

  /**
   * Returns string representation (SOQL without alias).
   * Examples: COUNT(Id), SUM(Amount), COUNT()
   */
  String toString();
}
