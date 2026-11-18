/**
 * A record a unit of work did not save, when the work allows partial success
 * (options().optAllOrNone = false). See IWork.failures() and IWork.failureOf().
 */
global interface IWorkFailure {
  /** The record as it was tracked or purged: the same instance, so its Id is null if it was new. */
  SObject getRecord();
  /** Why, in one line: the platform's messages joined by '; ', or the work's own reason. */
  String getMessage();
  /** The platform's errors. Empty when the work held the record back because a record it depends on failed. */
  List<Database.Error> getErrors();
}
