/**
 * The comparison engine behind field conditions. A Comparison joins a field path, an operator and
 * a right-hand value. It can test a record in memory and render itself as SOQL, and the two agree.
 *
 * The right-hand value is typed up front (SoapyValue). It may be a single value, a list or a set
 * of a primitive type, and its family (text, number, date/time, time of day, true/false) must
 * match the field's. One Evaluator per family does the in-memory work.
 */
public class Typing {
  public class ComparisonException extends Exception {
  }

  public class ValidationException extends Exception {
  }

  // The family a field's values belong to; a right-hand value must be of the same family.
  private static final Map<SoapType, String> FAMILY_BY_FIELD_TYPE = new Map<SoapType, String>{
    SoapType.BOOLEAN => 'boolean',
    SoapType.TIME => 'time',
    SoapType.DATETIME => 'datetime',
    SoapType.DATE => 'datetime',
    SoapType.DOUBLE => 'decimal',
    SoapType.LONG => 'decimal',
    SoapType.INTEGER => 'decimal',
    SoapType.BASE64BINARY => 'string',
    SoapType.ID => 'string',
    SoapType.STRING => 'string'
  };

  // The family of each type name that inference can produce.
  private static final Map<String, String> FAMILY_BY_TYPE_NAME = new Map<String, String>{
    'boolean' => 'boolean',
    'time' => 'time',
    'date' => 'datetime',
    'datetime' => 'datetime',
    'integer' => 'decimal',
    'long' => 'decimal',
    'double' => 'decimal',
    'decimal' => 'decimal',
    'id' => 'string',
    'string' => 'string'
  };

  // The operators that order one value against another.
  private static final Set<Enums.Comparator> ORDERING_COMPARATORS = new Set<Enums.Comparator>{
    Enums.Comparator.LT,
    Enums.Comparator.LE,
    Enums.Comparator.GT,
    Enums.Comparator.GE
  };

  // The operators a date literal goes with: IN and NOT IN take a list of them, the others one.
  private static final Set<Enums.Comparator> RANGE_COMPARATORS = new Set<Enums.Comparator>{
    Enums.Comparator.EQ,
    Enums.Comparator.NE,
    Enums.Comparator.LT,
    Enums.Comparator.LE,
    Enums.Comparator.GT,
    Enums.Comparator.GE,
    Enums.Comparator.IIN,
    Enums.Comparator.NIN
  };

  // Which fields an operator applies to.
  private static final String ANY_FIELD = 'any';
  private static final String NOT_BOOLEAN = 'ordered';
  private static final String TEXT_ONLY = 'text';
  private static final String MULTI_SELECT_ONLY = 'multi';

  // Operators

  public static Map<Enums.Comparator, Operator> operatorByEnum {
    get {
      if (operatorByEnum == null) {
        Map<Enums.Comparator, Operator> registry = new Map<Enums.Comparator, Operator>();
        List<Operator> known = new List<Operator>{
          new OperatorEXC(),
          new OperatorINC(),
          new OperatorNIN(),
          new OperatorIIN(),
          new OperatorLK(),
          new OperatorLT(),
          new OperatorGT(),
          new OperatorLE(),
          new OperatorGE(),
          new OperatorNE(),
          new OperatorEQ()
        };
        for (Operator each : known) {
          registry.put(each.comparator(), each);
        }
        operatorByEnum = registry;
      }
      return operatorByEnum;
    }
    set;
  }

  public static Operator operator(Enums.Comparator kind) {
    return operatorByEnum.get(kind);
  }

  /** A SOQL comparison operator: its keyword, whether it takes a collection, and where it applies. */
  public abstract class Operator {
    private Enums.Comparator kind;
    private String keyword;
    private Boolean plural;
    private String appliesTo;

    protected Operator(Enums.Comparator kind, String keyword, Boolean plural, String appliesTo) {
      this.kind = kind;
      this.keyword = keyword;
      this.plural = plural;
      this.appliesTo = appliesTo;
    }

    public virtual Enums.Comparator comparator() {
      return kind;
    }

    public virtual String toSoql() {
      return keyword;
    }

    public virtual Boolean isPlural() {
      return plural;
    }

    /** INCLUDES and EXCLUDES need literal values; every other operator takes a bind variable. */
    public virtual Boolean supportsBinding() {
      return appliesTo != MULTI_SELECT_ONLY;
    }

    public virtual Boolean supportsField(DescribeFieldResult described) {
      if (appliesTo == NOT_BOOLEAN) {
        return described.getSoapType() != SoapType.BOOLEAN;
      } else if (appliesTo == TEXT_ONLY) {
        return described.getSoapType() == SoapType.STRING;
      } else if (appliesTo == MULTI_SELECT_ONLY) {
        return described.getType() == DisplayType.MULTIPICKLIST;
      }
      return true;
    }
  }

  public class OperatorEQ extends Operator {
    public OperatorEQ() {
      super(Enums.Comparator.EQ, '=', false, ANY_FIELD);
    }
  }

  public class OperatorNE extends Operator {
    public OperatorNE() {
      super(Enums.Comparator.NE, '!=', false, ANY_FIELD);
    }
  }

  public class OperatorGE extends Operator {
    public OperatorGE() {
      super(Enums.Comparator.GE, '>=', false, NOT_BOOLEAN);
    }
  }

  public class OperatorLE extends Operator {
    public OperatorLE() {
      super(Enums.Comparator.LE, '<=', false, NOT_BOOLEAN);
    }
  }

  public class OperatorGT extends Operator {
    public OperatorGT() {
      super(Enums.Comparator.GT, '>', false, NOT_BOOLEAN);
    }
  }

  public class OperatorLT extends Operator {
    public OperatorLT() {
      super(Enums.Comparator.LT, '<', false, NOT_BOOLEAN);
    }
  }

  public class OperatorLK extends Operator {
    public OperatorLK() {
      super(Enums.Comparator.LK, 'LIKE', false, TEXT_ONLY);
    }
  }

  public class OperatorIIN extends Operator {
    public OperatorIIN() {
      super(Enums.Comparator.IIN, 'IN', true, ANY_FIELD);
    }
  }

  public class OperatorNIN extends Operator {
    public OperatorNIN() {
      super(Enums.Comparator.NIN, 'NOT IN', true, ANY_FIELD);
    }
  }

  public class OperatorINC extends Operator {
    public OperatorINC() {
      super(Enums.Comparator.INC, 'INCLUDES', true, MULTI_SELECT_ONLY);
    }
  }

  public class OperatorEXC extends Operator {
    public OperatorEXC() {
      super(Enums.Comparator.EXC, 'EXCLUDES', true, MULTI_SELECT_ONLY);
    }
  }

  /**
   * Whether a condition's value goes into the SOQL as a bind variable. INCLUDES and EXCLUDES take
   * literals only, a date literal is written as it is, and IN with no collection at all is
   * written as a constant test.
   */
  public static Boolean bindable(Enums.Comparator kind, Object value) {
    Operator op = operator(kind);
    return op.supportsBinding() && !DateLiteral.isLiteral(value) && !(op.isPlural() && value == null);
  }

  // Comparisons

  /** Throws if the value does not suit the operator or the field. */
  public static Comparison comparison(IPath fieldPath, Enums.Comparator kind, Object operand) {
    return new Comparison(fieldPath, kind, operand);
  }

  public class Comparison {
    private IPath fieldPath;
    private Operator op;
    private Object value;
    private SoapyValue operand;
    // A date literal (TODAY, LAST_N_DAYS:30), or the list of them that IN and NOT IN take. It is a
    // range of days, not a value, so it is neither typed as one nor handed to an Evaluator.
    private List<DateLiteral.Value> ranges;
    // Left behind when the comparison is stored with a job, and described again when it is needed.
    private transient DescribeFieldResult field {
      get {
        if (field == null) {
          field = fieldPath.describe();
        }
        return field;
      }
      set;
    }
    private Evaluator evaluator {
      get {
        if (evaluator == null) {
          evaluator = operand.getEvaluator();
        }
        return evaluator;
      }
      set;
    }

    private Comparison(IPath fieldPath, Enums.Comparator kind, Object value) {
      if (fieldPath == null) {
        throw new ComparisonException('A comparison needs a field path');
      }
      Operator chosen = operator(kind);
      if (chosen == null) {
        throw new ComparisonException('A comparison needs an operator');
      }
      this.fieldPath = fieldPath;
      op = chosen;
      if (DateLiteral.isLiteral(value)) {
        holdRanges(value);
        return;
      }
      this.value = field.getSoapType() == SoapType.INTEGER ? asIntegers(value) : value;
      operand = getSoapyValue(this.value, field.getSoapType());
      check();
    }

    // A date literal, or a list of them, each held as one of the framework's own.
    private void holdRanges(Object given) {
      Boolean listed = given instanceof List<IDateLiteral>;
      List<IDateLiteral> literals = listed
        ? (List<IDateLiteral>) given
        : new List<IDateLiteral>{ (IDateLiteral) given };
      value = given;
      ranges = new List<DateLiteral.Value>();
      for (IDateLiteral each : literals) {
        ranges.add(DateLiteral.checked(each));
      }
      checkRanges(listed);
    }

    // The platform takes a date literal on date and date-time fields only: one with =, !=, <, <=,
    // > and >=, and a list of them with IN and NOT IN.
    private void checkRanges(Boolean listed) {
      String opName = String.valueOf(op.comparator());
      SoapType held = field.getSoapType();
      if (held != SoapType.DATE && held != SoapType.DATETIME) {
        throw new ValidationException(
          fieldPath.name() + ' holds ' + (FAMILY_BY_FIELD_TYPE.get(held) ?? String.valueOf(held)) +
          ' values, so it cannot be compared with a date literal'
        );
      }
      if (!RANGE_COMPARATORS.contains(op.comparator())) {
        throw new ValidationException(opName + ' does not apply to a date literal');
      }
      if (listed != op.isPlural()) {
        throw new ValidationException(
          opName + (listed ? ' takes one date literal, not a list of them' : ' takes a list of date literals, not one')
        );
      }
    }

    public IPath path() {
      return fieldPath;
    }

    /**
     * The right-hand value as given, but for one case: whole numbers compared with an integer
     * field are held as Integers, which is the one form the platform takes there.
     */
    public Object value() {
      return value;
    }

    /** Swaps the operator without checking it again. */
    public void setOperator(Operator replacement) {
      op = replacement;
    }

    private void check() {
      String opName = String.valueOf(op.comparator());
      if (operand == null) {
        throw new ValidationException(fieldPath.name() + ' cannot be compared with a value of that type');
      }
      if (operand.wasNull != true && op.isPlural() != operand.isPlural()) {
        throw new ValidationException(
          opName + (op.isPlural() ? ' takes a list or set, not ' : ' takes one value, not ') + operand.typeName()
        );
      }
      if (!op.supportsField(field)) {
        throw new ValidationException(opName + ' does not apply to ' + fieldPath.name());
      }
      String fieldFamily = FAMILY_BY_FIELD_TYPE.get(field.getSoapType());
      if (fieldFamily == null || fieldFamily != operand.castName) {
        throw new ValidationException(
          fieldPath.name() + ' holds ' + (fieldFamily ?? String.valueOf(field.getSoapType())) +
          ' values, so it cannot be compared with ' + operand.typeName()
        );
      }
    }

    /**
     * Tests the record. Null means SOQL leaves the row out whether or not the condition is
     * negated, as it does for an empty field compared with a date literal.
     */
    public Boolean evaluate(SObject record) {
      Object held = fieldPath.getFieldValue(record);
      return ranges == null ? evaluator.apply(op, field, held) : inRanges(held);
    }

    // IN holds when the day is in one of the ranges and NOT IN when it is in none; an empty field
    // is in none, and SOQL answers NOT IN with it, but not IN, nor NOT (... IN ...).
    private Boolean inRanges(Object held) {
      Enums.Comparator kind = op.comparator();
      IScheme scheme = fieldPath.source().scheme();
      if (!op.isPlural()) {
        return ranges[0].test(kind, held, scheme);
      }
      if (ranges.isEmpty()) {
        return kind == Enums.Comparator.NIN; // written as a constant test, which has an answer for every row
      }
      Boolean among = false;
      for (DateLiteral.Value range : ranges) {
        among = among || range.test(Enums.Comparator.EQ, held, scheme) == true;
      }
      if (held == null) {
        return kind == Enums.Comparator.NIN ? true : null;
      }
      return (kind == Enums.Comparator.IIN) == among;
    }

    /** The condition with its value written inline. An empty collection becomes a constant test. */
    public String toSoql() {
      if (ranges != null) {
        List<String> written = new List<String>();
        for (DateLiteral.Value range : ranges) {
          written.add(range.toSoql());
        }
        if (!op.isPlural()) {
          return toSoql(written[0]);
        }
        return written.isEmpty() ? emptyListSoql() : toSoql('(' + String.join(written, ', ') + ')');
      }
      List<String> literals = evaluator.itemsToSoql();
      if (op.comparator() == Enums.Comparator.LK && evaluator instanceof StringEvaluator) {
        literals = new List<String>();
        for (Object raw : evaluator.operands) {
          literals.add(quote((String) raw, true));
        }
      } else if (evaluator instanceof DatetimeEvaluator) {
        literals = ((DatetimeEvaluator) evaluator).itemsToSoql(field.getSoapType() == SoapType.DATETIME);
      }
      if (literals.isEmpty()) {
        return op.isPlural() ? emptyListSoql() : toSoql('null');
      }
      String joined = String.join(literals, ', ');
      return toSoql(op.isPlural() ? '(' + joined + ')' : joined);
    }

    /** The condition with the given text, such as a bind variable, as its value. */
    public String toSoql(String literal) {
      checkWritable();
      return fieldPath.name() + ' ' + op.toSoql() + ' ' + literal;
    }

    // IN or INCLUDES with nothing to match is never true; NOT IN or EXCLUDES with nothing to rule
    // out always is.
    private String emptyListSoql() {
      Enums.Comparator kind = op.comparator();
      return constantSoql(fieldPath.source(), kind == Enums.Comparator.NIN || kind == Enums.Comparator.EXC, false);
    }

    // What builds and can be tested in memory, but is not SOQL. Nothing is above, below or like
    // null: written inline the platform refuses it, and bound it gives answers that follow no
    // rule. And LIKE does not read a multi-select picklist.
    private void checkWritable() {
      Enums.Comparator kind = op.comparator();
      Boolean matching = kind == Enums.Comparator.LK;
      if (operand?.wasNull == true && (matching || ORDERING_COMPARATORS.contains(kind))) {
        throw new ValidationException(
          'Cannot compare ' + fieldPath.name() + ' with null by ' + kind + ': null goes with EQ and NE'
        );
      }
      if (matching && field.getType() == DisplayType.MULTIPICKLIST) {
        throw new ValidationException(
          'Cannot write ' + kind + ' on ' + fieldPath.name() + ': a multi-select picklist takes INC and EXC'
        );
      }
    }
  }

  /**
   * A test that always holds, or never does. SOQL has no literal for either, so it tests one
   * field against null both ways: the object's Id, or COUNT(Id) when `counted`, since HAVING
   * takes no bare field.
   */
  public static String constantSoql(IModel source, Boolean always, Boolean counted) {
    SObjectField anchor = source.token() == ContentDocumentLink.SObjectType
      ? ContentDocumentLink.LinkedEntityId
      : source.fieldMap().get('Id');
    if (anchor == null) {
      anchor = source.fieldMap().values()[0];
    }
    String name = counted == true ? 'COUNT(' + anchor + ')' : String.valueOf(anchor);
    return '(' + name + ' = null ' + (always == true ? 'OR ' : 'AND ') + name + ' != null)';
  }

  // Typed values

  /**
   * Types a right-hand value. A null value becomes an empty list of the field type's family (or
   * an untyped value without a field type); a value of an unsupported type gives null.
   */
  public static SoapyValue getSoapyValue(Object operand, SoapType fieldType) {
    if (operand == null) {
      return fieldType == null ? new SoapyValue(null, null, null) : new SoapyValue(fieldType);
    }
    String name = singleTypeName(operand);
    if (name != null) {
      return new SoapyValue(Enums.Collective.SINGLE, name, operand);
    }
    name = listTypeName(operand);
    if (name != null) {
      return new SoapyValue(Enums.Collective.ALIST, name, operand);
    }
    name = setTypeName(operand);
    return name == null ? null : new SoapyValue(Enums.Collective.ASET, name, operand);
  }

  // The checks run narrowest first: an Id also passes as a String, a Date as a Datetime, and every
  // number as a Double (so a Decimal is reported as 'double').
  private static String singleTypeName(Object operand) {
    if (operand instanceof Id) {
      return 'id';
    } else if (operand instanceof String) {
      return 'string';
    } else if (operand instanceof Integer) {
      return 'integer';
    } else if (operand instanceof Long) {
      return 'long';
    } else if (operand instanceof Double) {
      return 'double';
    } else if (operand instanceof Date) {
      return 'date';
    } else if (operand instanceof Datetime) {
      return 'datetime';
    } else if (operand instanceof Boolean) {
      return 'boolean';
    } else if (operand instanceof Time) {
      return 'time';
    }
    return null;
  }

  // A list of Ids is a List<String> to instanceof, so the first element decides.
  private static String listTypeName(Object operand) {
    if (operand instanceof List<String>) {
      List<String> texts = (List<String>) operand;
      return !texts.isEmpty() && texts[0] instanceof Id ? 'id' : 'string';
    } else if (operand instanceof List<Integer>) {
      return 'integer';
    } else if (operand instanceof List<Long>) {
      return 'long';
    } else if (operand instanceof List<Double>) {
      return 'double';
    } else if (operand instanceof List<Date>) {
      return 'date';
    } else if (operand instanceof List<Datetime>) {
      return 'datetime';
    } else if (operand instanceof List<Boolean>) {
      return 'boolean';
    } else if (operand instanceof List<Time>) {
      return 'time';
    }
    return null;
  }

  // Sets are matched on their exact element type.
  private static String setTypeName(Object operand) {
    if (operand instanceof Set<String>) {
      return 'string';
    } else if (operand instanceof Set<Id>) {
      return 'id';
    } else if (operand instanceof Set<Date>) {
      return 'date';
    } else if (operand instanceof Set<Datetime>) {
      return 'datetime';
    } else if (operand instanceof Set<Decimal>) {
      return 'decimal';
    } else if (operand instanceof Set<Integer>) {
      return 'integer';
    } else if (operand instanceof Set<Long>) {
      return 'long';
    } else if (operand instanceof Set<Double>) {
      return 'double';
    } else if (operand instanceof Set<Boolean>) {
      return 'boolean';
    } else if (operand instanceof Set<Time>) {
      return 'time';
    }
    return null;
  }

  // On an integer field the platform takes whole numbers as Integers only: it refuses a Decimal
  // 5.0, bound or written. A whole Decimal, Double or Long, or a list or set of them, is therefore
  // given back as Integers. Anything else comes back as it is, for the platform to judge.
  private static Object asIntegers(Object operand) {
    SoapyValue typed = getSoapyValue(operand, null);
    if (typed?.castName != 'decimal' || typed.atomicName == 'integer') {
      return operand;
    }
    List<Integer> whole = new List<Integer>();
    for (Object item : typed.items()) {
      Decimal amount = (Decimal) item;
      Boolean fits = amount == null || (amount >= -2147483647 && amount <= 2147483647 && amount == amount.intValue());
      if (!fits) {
        return operand;
      }
      whole.add(amount?.intValue());
    }
    if (typed.coll == Enums.Collective.SINGLE) {
      return whole[0];
    }
    return typed.coll == Enums.Collective.ASET ? (Object) new Set<Integer>(whole) : whole;
  }

  /** A right-hand value with its inferred shape (single, list or set) and element type. */
  public class SoapyValue {
    private Enums.Collective coll;
    private String atomicName;
    private String castName;
    private Object value;
    private Boolean wasNull = false;

    private SoapyValue(Enums.Collective coll, String atomicName, Object value) {
      this.coll = coll;
      this.atomicName = atomicName;
      this.value = value;
      castName = FAMILY_BY_TYPE_NAME.get(atomicName);
    }

    // A null value: an empty list of the field type's family.
    private SoapyValue(SoapType fieldType) {
      castName = FAMILY_BY_FIELD_TYPE.get(fieldType);
      atomicName = castName;
      coll = Enums.Collective.ALIST;
      value = castName == null ? new List<Object>() : Type.forName('List<' + castName + '>').newInstance();
      wasNull = true;
    }

    /** For example 'string', 'list<id>' or 'set<date>'. */
    public String typeName() {
      if (coll == Enums.Collective.ALIST) {
        return 'list<' + atomicName + '>';
      } else if (coll == Enums.Collective.ASET) {
        return 'set<' + atomicName + '>';
      }
      return atomicName;
    }

    public Boolean isPlural() {
      return coll != Enums.Collective.SINGLE;
    }

    // The value as a list: a list itself, the members of a set, or the one value.
    private List<Object> items() {
      if (coll == Enums.Collective.ALIST) {
        return (List<Object>) value;
      } else if (coll == Enums.Collective.ASET) {
        Type listOfElements = Type.forName('List<' + atomicName + '>');
        return (List<Object>) JSON.deserialize(JSON.serialize(value), listOfElements);
      }
      // A Date added to a List<Datetime> would become a Datetime, so it gets a List<Date>.
      String elementType = atomicName == 'date' ? 'date' : castName;
      List<Object> single = (List<Object>) Type.forName('List<' + elementType + '>').newInstance();
      single.add(value);
      return single;
    }

    /** The evaluator for the value's family, or null for an untyped value. */
    public Evaluator getEvaluator() {
      if (castName == null) {
        return null;
      }
      List<Object> operands = items();
      if (castName == 'string') {
        return new StringEvaluator((List<String>) operands);
      } else if (castName == 'decimal') {
        return new DecimalEvaluator((List<Decimal>) operands);
      } else if (castName == 'datetime') {
        return new DatetimeEvaluator((List<Datetime>) operands);
      } else if (castName == 'time') {
        return new TimeEvaluator((List<Time>) operands);
      }
      return new BooleanEvaluator((List<Boolean>) operands);
    }
  }

  // Evaluators

  /** Applies operators for one family of values; the right-hand side is always held as a list. */
  public abstract class Evaluator {
    private List<Object> operands;

    public Evaluator(List<Object> operands) {
      this.operands = operands;
    }

    public abstract Boolean apply(Operator op, DescribeFieldResult described, Object left);

    /** Each right-hand value as a SOQL literal. */
    public abstract List<String> itemsToSoql();
  }

  // The operators every family shares, settled from three facts: whether the left value is among
  // the right ones, whether it equals the first, and how it orders against the first. Others give
  // null.
  //
  // `order` is null when either side is null. SOQL cannot order an empty number, date or time
  // against a value, nor a value against null, and leaves the row out even when the condition is
  // negated: the answer is then null (unknown), not false. Equality and membership always have
  // an answer.
  private static Boolean decide(Enums.Comparator kind, Boolean among, Boolean same, Integer order) {
    if (order == null && ORDERING_COMPARATORS.contains(kind)) {
      return null;
    }
    switch on kind {
      when IIN {
        return among;
      }
      when NIN {
        return !among;
      }
      when EQ {
        return same;
      }
      when NE {
        return !same;
      }
      when GT {
        return order == 1;
      }
      when LT {
        return order == -1;
      }
      when GE {
        return order == 0 || order == 1;
      }
      when LE {
        return order == 0 || order == -1;
      }
    }
    return null;
  }

  /**
   * Text, Ids and picklists. Matching ignores case unless the field is both case-sensitive and
   * unique, or holds Ids. INCLUDES and EXCLUDES split the field's value on semicolons, and so does
   * equality on a multi-select picklist, where the order of the choices does not matter.
   */
  public class StringEvaluator extends Evaluator {
    private List<String> texts {
      get {
        return (List<String>) operands;
      }
    }

    // Worked out on the first record and reused: an evaluator serves one field. The folded set is
    // rebuilt if the right-hand list changes size (a caller's list is shared, not copied).
    private Boolean exact;
    private Set<String> folded;
    private Integer foldedSize;
    // Whether the field holds Ids. An Id matches in its exact case, as it does in SOQL, and its
    // 15-character form matches its 18-character form.
    private Boolean ofIds = false;
    // Whether the field is a multi-select picklist. SOQL takes A;B and B;A for the same value.
    private Boolean ofChoices = false;

    public StringEvaluator(List<String> texts) {
      super(texts);
    }

    // The form in which a value of the field is compared.
    private String normal(String text) {
      if (ofIds) {
        return whole(text);
      }
      return ofChoices ? ordered(text) : text;
    }

    private Boolean exactFor(DescribeFieldResult described) {
      if (exact == null) {
        ofIds = described != null && described.getSoapType() == SoapType.ID;
        ofChoices = described != null && described.getType() == DisplayType.MULTIPICKLIST;
        exact = ofIds ||
          (described != null &&
          described.getSoapType() == SoapType.STRING &&
          described.isCaseSensitive() &&
          described.isUnique());
      }
      return exact;
    }

    private Set<String> foldedTexts() {
      if (folded == null || foldedSize != texts.size()) {
        folded = new Set<String>();
        for (String text : texts) {
          folded.add(fold(normal(text), exact));
        }
        foldedSize = texts.size();
      }
      return folded;
    }

    public override Boolean apply(Operator op, DescribeFieldResult described, Object left) {
      String subject = (String) left;
      String first = texts.isEmpty() ? null : texts[0];
      Enums.Comparator kind = op.comparator();
      // Nothing is above, below or like null, so there is no answer. (Empty text is not null.)
      if (texts.isEmpty() && (kind == Enums.Comparator.LK || ORDERING_COMPARATORS.contains(kind))) {
        return null;
      }
      switch on kind {
        when GT {
          return subject > first;
        }
        when LT {
          return subject < first;
        }
        when GE {
          return subject >= first;
        }
        when LE {
          return subject <= first;
        }
        when LK {
          // SOQL matches an empty field with no pattern, not even %. (An empty pattern is not
          // SOQL at all; bound, it matches the empty fields, and so does this.)
          return subject == null && String.isNotEmpty(first) ? false : doEvaluateLike(subject, first);
        }
      }
      Boolean caseKept = exactFor(described);
      if (kind == Enums.Comparator.INC || kind == Enums.Comparator.EXC) {
        // Whether an empty field includes a value SOQL cannot say, and it leaves the row out under
        // NOT as well. That the field excludes the value it does say.
        if (kind == Enums.Comparator.INC && subject == null && !texts.isEmpty()) {
          return null;
        }
        // The values on the right are alternatives. One value may name several choices (A;B), and
        // then the field must have them all.
        Set<String> chosen = new Set<String>();
        for (String piece : (subject ?? '').split(';')) {
          chosen.add(fold(piece, caseKept));
        }
        Boolean selected = false;
        for (String alternative : texts) {
          Boolean hasAll = true;
          for (String choice : (alternative ?? '').split(';')) {
            hasAll = hasAll && chosen.contains(fold(choice, caseKept));
          }
          selected = selected || hasAll;
        }
        return (kind == Enums.Comparator.INC) == selected;
      }
      Set<String> wanted = foldedTexts();
      String key = fold(normal(subject), caseKept);
      String firstKey = fold(normal(first), caseKept);
      return decide(kind, wanted.contains(key), key.equals(firstKey), null);
    }

    public override List<String> itemsToSoql() {
      List<String> literals = new List<String>();
      for (String text : texts) {
        literals.add(quote(text, false));
      }
      return literals;
    }
  }

  public class DecimalEvaluator extends Evaluator {
    private List<Decimal> numbers {
      get {
        return (List<Decimal>) operands;
      }
    }

    public DecimalEvaluator(List<Decimal> numbers) {
      super(numbers);
    }

    public override Boolean apply(Operator op, DescribeFieldResult described, Object left) {
      Decimal subject = (Decimal) left;
      Decimal first = numbers.isEmpty() ? null : numbers[0];
      Boolean among = false;
      for (Decimal candidate : numbers) {
        among = among || candidate == subject;
      }
      Integer order;
      if (subject != null && first != null) {
        order = subject > first ? 1 : (subject < first ? -1 : 0);
      }
      return decide(op.comparator(), among, subject == first, order);
    }

    /** In plain digits: a Decimal's own text may use an exponent (1.5E+10), which is not SOQL. */
    public override List<String> itemsToSoql() {
      List<String> literals = new List<String>();
      for (Object amount : operands) {
        literals.add(amount == null ? 'null' : ((Decimal) amount).toPlainString());
      }
      return literals;
    }
  }

  /** Dates and date-times; a date field's values arrive as Dates and compare the same way. */
  public class DatetimeEvaluator extends Evaluator {
    private List<Datetime> moments {
      get {
        return (List<Datetime>) operands;
      }
    }

    public DatetimeEvaluator(List<Datetime> moments) {
      super(moments);
    }

    public override Boolean apply(Operator op, DescribeFieldResult described, Object left) {
      Datetime subject = (Datetime) left;
      Datetime first = moments.isEmpty() ? null : moments[0];
      Boolean among = false;
      for (Datetime candidate : moments) {
        among = among || candidate == subject;
      }
      Integer order;
      if (subject != null && first != null) {
        order = subject > first ? 1 : (subject < first ? -1 : 0);
      }
      return decide(op.comparator(), among, subject == first, order);
    }

    /** A Date renders as 2026-01-31 and a Datetime as 2026-01-31T09:30:00.000Z (GMT). */
    public override List<String> itemsToSoql() {
      return itemsToSoql(false);
    }

    /**
     * With `momentsOnly`, for a date-time field, a Date is written as midnight GMT, which is what
     * the platform makes of a Date bound to such a field. It takes no bare date there.
     */
    public List<String> itemsToSoql(Boolean momentsOnly) {
      List<String> literals = new List<String>();
      for (Object moment : operands) {
        if (moment == null) {
          literals.add('null');
        } else if (moment instanceof Date && !momentsOnly) {
          Datetime midnight = Datetime.newInstanceGmt((Date) moment, Time.newInstance(0, 0, 0, 0));
          literals.add(midnight.formatGmt('yyyy-MM-dd'));
        } else if (moment instanceof Date) {
          Datetime midnight = Datetime.newInstanceGmt((Date) moment, Time.newInstance(0, 0, 0, 0));
          literals.add(midnight.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
        } else {
          literals.add(((Datetime) moment).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
        }
      }
      return literals;
    }
  }

  public class TimeEvaluator extends Evaluator {
    private List<Time> clockTimes {
      get {
        return (List<Time>) operands;
      }
    }

    public TimeEvaluator(List<Time> clockTimes) {
      super(clockTimes);
    }

    public override Boolean apply(Operator op, DescribeFieldResult described, Object left) {
      Time subject = (Time) left;
      Time first = clockTimes.isEmpty() ? null : clockTimes[0];
      Boolean among = false;
      for (Time candidate : clockTimes) {
        among = among || candidate == subject;
      }
      Integer order;
      if (subject != null && first != null) {
        order = subject > first ? 1 : (subject < first ? -1 : 0);
      }
      return decide(op.comparator(), among, subject == first, order);
    }

    /** For example 09:30:00.000Z. */
    public override List<String> itemsToSoql() {
      List<String> literals = new List<String>();
      Date anyDay = Date.newInstance(2000, 1, 1);
      for (Time clockTime : clockTimes) {
        String rendered = clockTime == null
          ? 'null'
          : Datetime.newInstanceGmt(anyDay, clockTime).formatGmt('HH:mm:ss.SSS') + 'Z';
        literals.add(rendered);
      }
      return literals;
    }
  }

  /**
   * Checkboxes: only equality and membership apply. A checkbox is never empty, and SOQL reads a
   * null on the right as false: IsActive = null matches the unchecked rows.
   */
  public class BooleanEvaluator extends Evaluator {
    private List<Boolean> flags {
      get {
        return (List<Boolean>) operands;
      }
    }

    public BooleanEvaluator(List<Boolean> flags) {
      super(flags);
    }

    public override Boolean apply(Operator op, DescribeFieldResult described, Object left) {
      Boolean subject = (Boolean) left == true;
      Boolean first = !flags.isEmpty() && flags[0] == true;
      Boolean among = false;
      for (Boolean candidate : flags) {
        among = among || (candidate == true) == subject;
      }
      Enums.Comparator kind = op.comparator();
      Boolean applies = kind == Enums.Comparator.EQ ||
        kind == Enums.Comparator.NE ||
        kind == Enums.Comparator.IIN ||
        kind == Enums.Comparator.NIN;
      return applies ? decide(kind, among, subject == first, null) : null;
    }

    public override List<String> itemsToSoql() {
      List<String> literals = new List<String>();
      for (Boolean flag : flags) {
        literals.add(String.valueOf(flag));
      }
      return literals;
    }
  }

  // A SOQL string literal. Quotes and backslashes are escaped so the value cannot close the literal
  // early. In a LIKE pattern, \% and \_ are kept as they are: there they mark a literal % or _.
  private static String quote(String text, Boolean likePattern) {
    if (text == null) {
      return 'null';
    }
    String escaped = String.escapeSingleQuotes(text);
    if (likePattern) {
      escaped = escaped.replace('\\\\%', '\\%').replace('\\\\_', '\\_');
    }
    return '\'' + escaped + '\'';
  }

  // Static helpers

  /**
   * Tests one value against another without a Comparison. Null when the value cannot be typed,
   * and when SOQL has no answer: an empty number, date or time on the left of <, <=, > or >=.
   */
  public static Boolean doEvaluate(Enums.Comparator kind, DescribeFieldResult described, Object left, Object right) {
    SoapyValue typed = getSoapyValue(right, described.getSoapType());
    Evaluator evaluator = typed?.getEvaluator();
    return evaluator == null ? null : evaluator.apply(operator(kind), described, left);
  }

  /**
   * SOQL LIKE in memory: % matches any run of characters and _ exactly one, \% and \_ match the
   * characters themselves, and case is ignored. Null on either side counts as ''.
   */
  public static Boolean doEvaluateLike(String text, String likeExpression) {
    String source = likeExpression ?? '';
    Pattern compiled = likePatterns.get(source);
    if (compiled == null) {
      compiled = Pattern.compile('(?is)' + likeRegex(source));
      likePatterns.put(source, compiled);
    }
    return compiled.matcher(text ?? '').matches();
  }

  // Compiled LIKE patterns, kept for the transaction: each one is compiled once, not per record.
  private static Map<String, Pattern> likePatterns = new Map<String, Pattern>();

  private static String likeRegex(String source) {
    String regex = '';
    String literal = '';
    Integer at = 0;
    while (at < source.length()) {
      String symbol = source.mid(at, 1);
      String following = source.mid(at + 1, 1);
      if (symbol == '\\' && (following == '%' || following == '_')) {
        literal += following;
        at += 2;
        continue;
      }
      if (symbol == '%' || symbol == '_') {
        regex += (literal == '' ? '' : Pattern.quote(literal)) + (symbol == '%' ? '.*' : '.');
        literal = '';
      } else {
        literal += symbol;
      }
      at++;
    }
    regex += literal == '' ? '' : Pattern.quote(literal);
    return regex;
  }

  // An Id in its 18-character form; text that is not a 15-character Id is returned as it is.
  private static String whole(String text) {
    if (text == null || text.length() != 15) {
      return text;
    }
    try {
      return String.valueOf(Id.valueOf(text));
    } catch (Exception notAnId) {
      return text;
    }
  }

  // The choices of a multi-select value in one fixed order, in lower case: A;b and B;a are the same.
  private static String ordered(String text) {
    if (text == null || !text.contains(';')) {
      return text;
    }
    List<String> choices = text.toLowerCase().split(';');
    choices.sort();
    return String.join(choices, ';');
  }

  // Null counts as ''; unless case is kept, text compares in lower case.
  private static String fold(String text, Boolean caseKept) {
    if (text == null) {
      return '';
    }
    return caseKept == true ? text : text.toLowerCase();
  }

  /**
   * Deprecated. Merges same-typed sets (a union) or lists (end to end); null for anything else. A
   * list result is typed by family, so lists of Ids come back as List<String>.
   */
  public static Object combine(List<Object> parts) {
    if (parts == null || parts.isEmpty()) {
      return null;
    }
    SoapyValue sample = getSoapyValue(parts[0], null);
    if (sample?.coll == Enums.Collective.ALIST) {
      List<Object> joined = (List<Object>) Type.forName('List<' + sample.castName + '>').newInstance();
      for (Object part : parts) {
        joined.addAll((List<Object>) part);
      }
      return joined;
    }
    if (sample?.coll == Enums.Collective.ASET) {
      List<Object> members = new List<Object>();
      for (Object part : parts) {
        members.addAll((List<Object>) JSON.deserializeUntyped(JSON.serialize(part)));
      }
      return JSON.deserialize(JSON.serialize(members), Type.forName('Set<' + sample.atomicName + '>'));
    }
    return null;
  }
}
