/**
 * SOQL date literals: TODAY, THIS_WEEK, LAST_N_DAYS:30, NEXT_FISCAL_QUARTER and the rest. A date
 * literal is a range of whole days relative to today, and is the value of a condition on a date
 * or date-time field:
 *
 *   Application.s.ge(Opportunity.CloseDate, DateLiteral.lastNDays(30))   // CloseDate >= LAST_N_DAYS:30
 *   Application.s.eq(Task.ActivityDate, DateLiteral.of('THIS_WEEK'))     // ActivityDate = THIS_WEEK
 *
 * In SOQL it is written as it is, never bound. In memory it means what SOQL means by it:
 *
 *   =   the value falls inside the range        !=  outside it (or the field is empty)
 *   <   before the range starts                 <=  before it ends
 *   >   after the range ends                    >=  from its start on
 *
 * "Today" is today for the running user: a date-time is read as a day in the user's time zone,
 * and a week starts on the first day of the week of the user's locale. A range counted in weeks,
 * months, quarters or years (LAST_N_WEEKS:2) leaves the current one out; LAST_N_DAYS and
 * LAST_90_DAYS include today, and NEXT_N_DAYS and NEXT_90_DAYS start tomorrow.
 *
 * Fiscal literals follow the organization's fiscal year. In memory they are worked out for a
 * standard fiscal year from the start month set in Setup. Two queries read it, once per
 * transaction, through the scheme of the object the condition is on: one to see that the
 * organization has no custom fiscal years, one for the start month. An organization with custom
 * fiscal years gets a ConditionException instead, since only the database knows its periods.
 *
 * A count may be as large as the platform takes: 365000, for every unit. In memory a larger one
 * is refused with a ConditionException; the platform answers it with Date formula too large.
 * Text that is no date literal, and a count below zero, throw an IllegalArgumentException.
 */
global inherited sharing class DateLiteral {
  private enum Unit {
    DAY,
    WEEK,
    MONTH,
    QUARTER,
    YEAR,
    FISCAL_QUARTER,
    FISCAL_YEAR
  }

  // How a literal picks its units: the current one, the one before or after it, the n before or
  // after it, or the single one n back.
  private enum Shape {
    CURRENT,
    PREVIOUS,
    FOLLOWING,
    PREVIOUS_N,
    FOLLOWING_N,
    N_AGO
  }

  private static final Pattern TEXT_FORM = Pattern.compile('([A-Z0-9_]+)(?:\\s*:\\s*(\\d+))?');
  private static final Integer MONTHS_IN_QUARTER = 3;
  private static final Integer DAYS_IN_WEEK = 7;
  // The largest count the platform takes, whatever the unit.
  private static final Integer MAX_COUNT = 365000;
  // More digits than these may not fit an Integer.
  private static final Integer MAX_DIGITS = 9;

  // Today for the running user, unless a test fixes the day.
  @TestVisible
  private static Date fixedToday;
  // The month a standard fiscal year starts in, read once per transaction.
  @TestVisible
  private static Integer fiscalStartMonth;
  // Whether the organization has custom fiscal years; a test sets it to stand in for one that has.
  @TestVisible
  private static Boolean customFiscalYears;
  // One entry per keyword, built on first use.
  private static Map<String, Spec> registry;

  // Days

  global static IDateLiteral yesterday() {
    return fixed('YESTERDAY');
  }

  global static IDateLiteral today() {
    return fixed('TODAY');
  }

  global static IDateLiteral tomorrow() {
    return fixed('TOMORROW');
  }

  /** The 90 days before today, and today. */
  global static IDateLiteral last90Days() {
    return fixed('LAST_90_DAYS');
  }

  /** The 90 days after today. */
  global static IDateLiteral next90Days() {
    return fixed('NEXT_90_DAYS');
  }

  /** The n days before today, and today. */
  global static IDateLiteral lastNDays(Integer n) {
    return counted('LAST_N_DAYS', n);
  }

  /** The n days after today. */
  global static IDateLiteral nextNDays(Integer n) {
    return counted('NEXT_N_DAYS', n);
  }

  /** The one day n days before today. */
  global static IDateLiteral nDaysAgo(Integer n) {
    return counted('N_DAYS_AGO', n);
  }

  // Weeks

  global static IDateLiteral lastWeek() {
    return fixed('LAST_WEEK');
  }

  global static IDateLiteral thisWeek() {
    return fixed('THIS_WEEK');
  }

  global static IDateLiteral nextWeek() {
    return fixed('NEXT_WEEK');
  }

  /** The n weeks before this week. */
  global static IDateLiteral lastNWeeks(Integer n) {
    return counted('LAST_N_WEEKS', n);
  }

  /** The n weeks after this week. */
  global static IDateLiteral nextNWeeks(Integer n) {
    return counted('NEXT_N_WEEKS', n);
  }

  /** The one week n weeks before this week. */
  global static IDateLiteral nWeeksAgo(Integer n) {
    return counted('N_WEEKS_AGO', n);
  }

  // Months

  global static IDateLiteral lastMonth() {
    return fixed('LAST_MONTH');
  }

  global static IDateLiteral thisMonth() {
    return fixed('THIS_MONTH');
  }

  global static IDateLiteral nextMonth() {
    return fixed('NEXT_MONTH');
  }

  /** The n months before this month. */
  global static IDateLiteral lastNMonths(Integer n) {
    return counted('LAST_N_MONTHS', n);
  }

  /** The n months after this month. */
  global static IDateLiteral nextNMonths(Integer n) {
    return counted('NEXT_N_MONTHS', n);
  }

  /** The one month n months before this month. */
  global static IDateLiteral nMonthsAgo(Integer n) {
    return counted('N_MONTHS_AGO', n);
  }

  // Calendar quarters

  global static IDateLiteral lastQuarter() {
    return fixed('LAST_QUARTER');
  }

  global static IDateLiteral thisQuarter() {
    return fixed('THIS_QUARTER');
  }

  global static IDateLiteral nextQuarter() {
    return fixed('NEXT_QUARTER');
  }

  /** The n quarters before this quarter. */
  global static IDateLiteral lastNQuarters(Integer n) {
    return counted('LAST_N_QUARTERS', n);
  }

  /** The n quarters after this quarter. */
  global static IDateLiteral nextNQuarters(Integer n) {
    return counted('NEXT_N_QUARTERS', n);
  }

  /** The one quarter n quarters before this quarter. */
  global static IDateLiteral nQuartersAgo(Integer n) {
    return counted('N_QUARTERS_AGO', n);
  }

  // Calendar years

  global static IDateLiteral lastYear() {
    return fixed('LAST_YEAR');
  }

  global static IDateLiteral thisYear() {
    return fixed('THIS_YEAR');
  }

  global static IDateLiteral nextYear() {
    return fixed('NEXT_YEAR');
  }

  /** The n years before this year. */
  global static IDateLiteral lastNYears(Integer n) {
    return counted('LAST_N_YEARS', n);
  }

  /** The n years after this year. */
  global static IDateLiteral nextNYears(Integer n) {
    return counted('NEXT_N_YEARS', n);
  }

  /** The one year n years before this year. */
  global static IDateLiteral nYearsAgo(Integer n) {
    return counted('N_YEARS_AGO', n);
  }

  // Fiscal quarters

  global static IDateLiteral lastFiscalQuarter() {
    return fixed('LAST_FISCAL_QUARTER');
  }

  global static IDateLiteral thisFiscalQuarter() {
    return fixed('THIS_FISCAL_QUARTER');
  }

  global static IDateLiteral nextFiscalQuarter() {
    return fixed('NEXT_FISCAL_QUARTER');
  }

  /** The n fiscal quarters before this one. */
  global static IDateLiteral lastNFiscalQuarters(Integer n) {
    return counted('LAST_N_FISCAL_QUARTERS', n);
  }

  /** The n fiscal quarters after this one. */
  global static IDateLiteral nextNFiscalQuarters(Integer n) {
    return counted('NEXT_N_FISCAL_QUARTERS', n);
  }

  /** The one fiscal quarter n fiscal quarters before this one. */
  global static IDateLiteral nFiscalQuartersAgo(Integer n) {
    return counted('N_FISCAL_QUARTERS_AGO', n);
  }

  // Fiscal years

  global static IDateLiteral lastFiscalYear() {
    return fixed('LAST_FISCAL_YEAR');
  }

  global static IDateLiteral thisFiscalYear() {
    return fixed('THIS_FISCAL_YEAR');
  }

  global static IDateLiteral nextFiscalYear() {
    return fixed('NEXT_FISCAL_YEAR');
  }

  /** The n fiscal years before this one. */
  global static IDateLiteral lastNFiscalYears(Integer n) {
    return counted('LAST_N_FISCAL_YEARS', n);
  }

  /** The n fiscal years after this one. */
  global static IDateLiteral nextNFiscalYears(Integer n) {
    return counted('NEXT_N_FISCAL_YEARS', n);
  }

  /** The one fiscal year n fiscal years before this one. */
  global static IDateLiteral nFiscalYearsAgo(Integer n) {
    return counted('N_FISCAL_YEARS_AGO', n);
  }

  /**
   * The literal written as SOQL writes it: 'TODAY', 'last_n_days:30', 'NEXT_N_FISCAL_QUARTERS:2'.
   * Case and the spaces around the colon do not matter. Text that is not a date literal, a number
   * where the literal takes none, or none where it needs one, throws an IllegalArgumentException.
   */
  global static IDateLiteral of(String text) {
    return read(text, true);
  }

  /** Whether the text is a date literal that of() would take. */
  public static Boolean isLiteralText(String text) {
    return read(text, false) != null;
  }

  // The literal the text names. Text that names none gives null, or throws when `strict`.
  private static Value read(String text, Boolean strict) {
    Matcher parts = TEXT_FORM.matcher((text ?? '').trim().toUpperCase());
    Spec spec = parts.matches() ? specs().get(parts.group(1)) : null;
    String digits = spec == null ? null : parts.group(2);
    String refusal;
    if (spec == null) {
      refusal = 'Not a SOQL date literal: ' + text;
    } else if (spec.takesCount && digits == null) {
      refusal = spec.keyword + ' needs a number, as in ' + spec.keyword + ':7, not ' + text;
    } else if (!spec.takesCount && digits != null) {
      refusal = spec.keyword + ' takes no number: ' + text;
    } else if (digits != null && digits.length() > MAX_DIGITS) {
      refusal = 'The number in ' + text + ' is too large';
    }
    if (refusal != null && strict) {
      throw new IllegalArgumentException(refusal);
    }
    return refusal == null ? new Value(spec, digits == null ? null : Integer.valueOf(digits)) : null;
  }

  /** Whether a condition's value is a date literal, or a list of them (for IN and NOT IN). */
  public static Boolean isLiteral(Object value) {
    return value instanceof IDateLiteral || value instanceof List<IDateLiteral>;
  }

  /**
   * The literal as one of this class's own. A literal of another class is read from its SOQL, so
   * only the text of a date literal passes: what it writes cannot be trusted to be one.
   */
  public static Value checked(IDateLiteral literal) {
    if (literal == null) {
      throw new IllegalArgumentException('A date literal is required');
    }
    return literal instanceof Value ? (Value) literal : read(literal.toSoql(), true);
  }

  private static IDateLiteral fixed(String keyword) {
    return new Value(specs().get(keyword), null);
  }

  private static IDateLiteral counted(String keyword, Integer n) {
    if (n == null || n < 0) {
      throw new IllegalArgumentException(keyword + ' needs a number that is zero or more, not ' + n);
    }
    return new Value(specs().get(keyword), n);
  }

  // The singular and plural unit names give every regular literal (LAST_WEEK, NEXT_N_WEEKS,
  // N_WEEKS_AGO); the five day literals with names of their own follow.
  private static Map<String, Spec> specs() {
    if (registry != null) {
      return registry;
    }
    registry = new Map<String, Spec>();
    Map<Unit, String> singular = new Map<Unit, String>{
      Unit.WEEK => 'WEEK',
      Unit.MONTH => 'MONTH',
      Unit.QUARTER => 'QUARTER',
      Unit.YEAR => 'YEAR',
      Unit.FISCAL_QUARTER => 'FISCAL_QUARTER',
      Unit.FISCAL_YEAR => 'FISCAL_YEAR'
    };
    for (Unit each : singular.keySet()) {
      String name = singular.get(each);
      register(new Spec('LAST_' + name, each, Shape.PREVIOUS, null));
      register(new Spec('THIS_' + name, each, Shape.CURRENT, null));
      register(new Spec('NEXT_' + name, each, Shape.FOLLOWING, null));
    }
    Map<Unit, String> plural = new Map<Unit, String>{
      Unit.DAY => 'DAYS',
      Unit.WEEK => 'WEEKS',
      Unit.MONTH => 'MONTHS',
      Unit.QUARTER => 'QUARTERS',
      Unit.YEAR => 'YEARS',
      Unit.FISCAL_QUARTER => 'FISCAL_QUARTERS',
      Unit.FISCAL_YEAR => 'FISCAL_YEARS'
    };
    for (Unit each : plural.keySet()) {
      String name = plural.get(each);
      register(new Spec('LAST_N_' + name, each, Shape.PREVIOUS_N, null));
      register(new Spec('NEXT_N_' + name, each, Shape.FOLLOWING_N, null));
      register(new Spec('N_' + name + '_AGO', each, Shape.N_AGO, null));
    }
    register(new Spec('YESTERDAY', Unit.DAY, Shape.PREVIOUS, null));
    register(new Spec('TODAY', Unit.DAY, Shape.CURRENT, null));
    register(new Spec('TOMORROW', Unit.DAY, Shape.FOLLOWING, null));
    register(new Spec('LAST_90_DAYS', Unit.DAY, Shape.PREVIOUS_N, 90));
    register(new Spec('NEXT_90_DAYS', Unit.DAY, Shape.FOLLOWING_N, 90));
    return registry;
  }

  private static void register(Spec spec) {
    registry.put(spec.keyword, spec);
  }

  /** Every keyword, for tests and messages. */
  @TestVisible
  private static Set<String> keywords() {
    return specs().keySet().clone();
  }

  private class Spec {
    private String keyword;
    private Unit unit;
    private Shape shape;
    private Integer builtInCount; // LAST_90_DAYS carries its own number
    private Boolean takesCount; // whether the literal is written with :n

    private Spec(String keyword, Unit unit, Shape shape, Integer builtInCount) {
      this.keyword = keyword;
      this.unit = unit;
      this.shape = shape;
      this.builtInCount = builtInCount;
      Boolean plural = shape == DateLiteral.Shape.PREVIOUS_N ||
        shape == DateLiteral.Shape.FOLLOWING_N ||
        shape == DateLiteral.Shape.N_AGO;
      takesCount = plural && builtInCount == null;
    }
  }

  /**
   * One date literal. It is public so that conditions can ask for its range; make one through the
   * factories. A fiscal range is read through the scheme given; null means the default scheme.
   */
  public class Value implements IDateLiteral {
    private Spec spec;
    private Integer count;

    private Value(Spec spec, Integer count) {
      this.spec = spec;
      this.count = count ?? spec.builtInCount;
    }

    public String toSoql() {
      return spec.takesCount ? spec.keyword + ':' + count : spec.keyword;
    }

    public override String toString() {
      return toSoql();
    }

    public Boolean equals(Object other) {
      return other instanceof Value && ((Value) other).toSoql() == toSoql();
    }

    public Integer hashCode() {
      return toSoql().hashCode();
    }

    public Boolean isFiscal() {
      return spec.unit == Unit.FISCAL_QUARTER || spec.unit == Unit.FISCAL_YEAR;
    }

    /** The first day of the range, for the running user today. */
    public Date startDate(IScheme scheme) {
      return unitStart(spec.unit, span()[0], scheme);
    }

    /**
     * The day after the last day of the range. An empty range, such as LAST_N_WEEKS:0, starts and
     * ends on the same day.
     */
    public Date endDate(IScheme scheme) {
      return unitStart(spec.unit, span()[1], scheme);
    }

    // The range in units from the current one: from the start of the first, to the start of the second.
    private List<Integer> span() {
      if (count != null && count > MAX_COUNT) {
        throw new Filtering.ConditionException(
          'Cannot evaluate ' + toSoql() + ' in memory: the count is over ' + MAX_COUNT
        );
      }
      switch on spec.shape {
        when CURRENT {
          return new List<Integer>{ 0, 1 };
        }
        when PREVIOUS {
          return new List<Integer>{ -1, 0 };
        }
        when FOLLOWING {
          return new List<Integer>{ 1, 2 };
        }
        when N_AGO {
          return new List<Integer>{ -count, 1 - count };
        }
        when PREVIOUS_N {
          // Days alone include the current one: LAST_N_DAYS:1 is yesterday and today.
          return new List<Integer>{ -count, spec.unit == Unit.DAY ? 1 : 0 };
        }
        when else {
          return new List<Integer>{ 1, count + 1 };
        }
      }
    }

    /**
     * The comparison SOQL makes between a date or date-time and this literal. Null means SOQL
     * leaves the row out whether or not the condition is negated: an empty field matches != alone.
     */
    public Boolean test(Enums.Comparator kind, Object fieldValue, IScheme scheme) {
      Date first = startDate(scheme);
      Date after = endDate(scheme);
      if (fieldValue == null) {
        return kind == Enums.Comparator.NE ? true : null;
      }
      Date day = dayOf(fieldValue);
      switch on kind {
        when EQ {
          return day >= first && day < after;
        }
        when NE {
          return day < first || day >= after;
        }
        when LT {
          return day < first;
        }
        when LE {
          return day < after;
        }
        when GT {
          return day >= after;
        }
        when GE {
          return day >= first;
        }
      }
      throw new Filtering.ConditionException(kind + ' cannot compare a field with the date literal ' + toSoql());
    }
  }

  // A date is itself; a date-time is the day it falls on in the running user's time zone.
  private static Date dayOf(Object fieldValue) {
    if (fieldValue instanceof Date) {
      return (Date) fieldValue;
    }
    if (fieldValue instanceof Datetime) {
      return ((Datetime) fieldValue).date();
    }
    throw new Filtering.ConditionException('A date literal compares dates and date-times, not ' + fieldValue);
  }

  // The first day of the unit that lies `offset` units from the current one.
  private static Date unitStart(Unit unit, Integer offset, IScheme scheme) {
    Date now = fixedToday ?? Date.today();
    switch on unit {
      when DAY {
        return now.addDays(offset);
      }
      when WEEK {
        return now.toStartOfWeek().addDays(DAYS_IN_WEEK * offset);
      }
      when MONTH {
        return now.toStartOfMonth().addMonths(offset);
      }
      when QUARTER {
        return quarterStart(now, 1).addMonths(MONTHS_IN_QUARTER * offset);
      }
      when YEAR {
        return Date.newInstance(now.year() + offset, 1, 1);
      }
      when FISCAL_QUARTER {
        return quarterStart(now, standardFiscalStartMonth(scheme)).addMonths(MONTHS_IN_QUARTER * offset);
      }
      when else {
        return yearStart(now, standardFiscalStartMonth(scheme)).addYears(offset);
      }
    }
  }

  // The first day of the year the day falls in, for a year that starts in the given month.
  private static Date yearStart(Date day, Integer startMonth) {
    Date thisYears = Date.newInstance(day.year(), startMonth, 1);
    return thisYears > day ? thisYears.addYears(-1) : thisYears;
  }

  // The first day of the quarter the day falls in, for a year that starts in the given month.
  private static Date quarterStart(Date day, Integer startMonth) {
    Date ofYear = yearStart(day, startMonth);
    Integer monthsIn = ofYear.monthsBetween(day.toStartOfMonth());
    return ofYear.addMonths(monthsIn - Math.mod(monthsIn, MONTHS_IN_QUARTER));
  }

  // A standard fiscal year is twelve calendar months from the first day of the start month, in
  // quarters of three months. Custom fiscal years are periods only the database holds. Both
  // answers are asked of the scheme once, and kept for the transaction.
  private static Integer standardFiscalStartMonth(IScheme scheme) {
    if (fiscalStartMonth != null) {
      return fiscalStartMonth;
    }
    IScheme asked = scheme ?? new SchemeDefault();
    Map<String, Object> noBinds = new Map<String, Object>();
    if (customFiscalYears == null) {
      String customYears = 'SELECT COUNT() FROM FiscalYearSettings WHERE IsStandardYear = false LIMIT 1';
      customFiscalYears = asked.countQueryWithBinds(customYears, noBinds, AccessLevel.SYSTEM_MODE) > 0;
    }
    if (customFiscalYears) {
      throw new Filtering.ConditionException(
        'Cannot evaluate a fiscal date literal in memory: the organization has custom fiscal years'
      );
    }
    String startMonth = 'SELECT FiscalYearStartMonth FROM Organization LIMIT 1';
    for (SObject own : asked.queryWithBinds(startMonth, noBinds, AccessLevel.SYSTEM_MODE)) {
      fiscalStartMonth = (Integer) own.get('FiscalYearStartMonth');
    }
    if (fiscalStartMonth == null) {
      throw new Filtering.ConditionException(
        'Cannot evaluate a fiscal date literal in memory: no Organization row gives the start month'
      );
    }
    return fiscalStartMonth;
  }
}
