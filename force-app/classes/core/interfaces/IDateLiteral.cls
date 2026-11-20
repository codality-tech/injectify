/**
 * A SOQL date literal, such as TODAY or LAST_N_DAYS:30: a range of days relative to today, used as
 * the value of a condition on a date or date-time field. DateLiteral makes them.
 */
global interface IDateLiteral {
  /** The literal as SOQL writes it, for example LAST_N_DAYS:30. */
  String toSoql();
}
