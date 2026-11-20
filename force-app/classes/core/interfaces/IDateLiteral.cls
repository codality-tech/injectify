/**
 * A SOQL date literal, such as TODAY or LAST_N_DAYS:30: a range of days relative to today, used as
 * the value of a condition on a date or date-time field. DateLiteral makes them.
 */
global interface IDateLiteral {
  /** The literal as SOQL writes it, for example LAST_N_DAYS:30. */
  String toSoql();

  /**
   * The first day of the range, for the running user today: THIS_FISCAL_QUARTER.startDate() is the
   * day the current fiscal quarter began. A fiscal literal reads the organization's fiscal year
   * (two queries, once per transaction) and throws for custom fiscal years; so does a count over
   * 365000.
   */
  Date startDate();

  /**
   * The last day of the range, inclusive: THIS_MONTH.endDate() is the last day of this month. A
   * range of no days (LAST_N_WEEKS:0) ends the day before it starts.
   */
  Date endDate();
}
