/** Enumerations shared across the framework. No code depends on the order of their values. */
global class Enums {
  /** Which fields a SOSL search looks in. */
  global enum SearchScope {
    ALL, // ALL FIELDS
    NAME, // NAME FIELDS
    EMAIL, // EMAIL FIELDS
    PHONE // PHONE FIELDS
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
