/** Enumerations shared across the framework. No code depends on the order of their values. */
global class Enums {
  /** Which fields a SOSL search looks in. */
  global enum SearchScope {
    ALL, // ALL FIELDS
    NAME, // NAME FIELDS
    EMAIL, // EMAIL FIELDS
    PHONE // PHONE FIELDS
  }

  /**
   * Which records a SOQL query looks at (USING SCOPE), for IQuery.usingScope(). Not to be confused
   * with SearchScope, which names the fields a SOSL search looks in. An object takes only some of
   * these: the platform ends the transaction for a scope the queried object does not support.
   */
  global enum FilterScope {
    DELEGATED, // delegated: records delegated to another user for action
    EVERYTHING, // everything: all records
    MINE, // mine: records the running user owns
    MINE_AND_MY_GROUPS, // mine_and_my_groups: records assigned to the user and the user's queues
    MY_TERRITORY, // my_territory: records in the user's territory
    MY_TEAM_TERRITORY, // my_team_territory: records in the territory of the user's team
    SCOPING_RULE, // scopingRule: records the object's scoping rule lets through
    TEAM // team: records assigned to a team, such as an account team
  }

  /** The shape of a right-hand value, as inferred by Typing. */
  public enum Collective {
    SINGLE,
    ALIST,
    ASET
  }

  /**
   * Comparison operators for SOQL conditions and in-memory evaluation. The two-letter ones take a
   * single value; the three-letter ones take a list or set.
   */
  global enum Comparator {
    EQ, // =
    NE, // !=
    LT, // <
    GT, // >
    LE, // <=
    GE, // >=
    LK, // LIKE
    NIN, // NOT IN
    IIN, // IN
    EXC, // EXCLUDES
    INC // INCLUDES
  }

  /** Aggregate functions, for ICore.aggregate(), which picks one at run time. */
  global enum Aggregate {
    COUNT,
    COUNT_DISTINCT,
    SUM,
    AVG,
    MIN,
    MAX
  }

  /** What a running job does with a job started inside it; listed in the order they dispatch. */
  global enum CaptureMode {
    SYNCHRONOUS, // run it now, in this transaction
    RELEASE, // start it as a job of its own
    IMMEDIATE, // bundle it into one queueable that starts as soon as possible
    PREPEND, // run it before the rest of the chain
    APPEND, // run it after the rest of the chain (the default)
    IGNORE // drop it
  }
}
