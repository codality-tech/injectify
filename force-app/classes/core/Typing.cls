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

  // Comparisons

  /** Throws if the value does not suit the operator or the field. */
  public static Comparison comparison(IPath fieldPath, Enums.Comparator kind, Object operand) {
    return new Comparison(fieldPath, kind, operand);
  }

  public class Comparison {
    private IPath fieldPath;
    private Operator op;
    private SoapyValue operand;
    private transient DescribeFieldResult field;
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
      field = fieldPath.describe();
      operand = getSoapyValue(value, field.getSoapType());
      check();
    }

    public IPath path() {
      return fieldPath;
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

    public Boolean evaluate(SObject record) {
      return evaluator.apply(op, field, fieldPath.getFieldValue(record));
    }

    /** The condition with its value written inline. An empty collection becomes a constant test. */
    public String toSoql() {
      List<String> literals = evaluator.itemsToSoql();
      if (op.comparator() == Enums.Comparator.LK && evaluator instanceof StringEvaluator) {
        literals = new List<String>();
        for (Object raw : evaluator.operands) {
          literals.add(quote((String) raw, true));
        }
      }
      if (literals.isEmpty()) {
        return op.isPlural() ? constantSoql() : toSoql('null');
      }
      String joined = String.join(literals, ', ');
      return toSoql(op.isPlural() ? '(' + joined + ')' : joined);
    }

    /** The condition with the given text, such as a bind variable, as its value. */
    public String toSoql(String literal) {
      return fieldPath.name() + ' ' + op.toSoql() + ' ' + literal;
    }

    // IN or INCLUDES with nothing to match is never true; NOT IN or EXCLUDES with nothing to rule
    // out always is. SOQL has no literal for either, so it tests a field against null both ways.
    private String constantSoql() {
      Enums.Comparator kind = op.comparator();
      Boolean always = kind == Enums.Comparator.NIN || kind == Enums.Comparator.EXC;
      IModel source = fieldPath.source();
      SObjectField anchor = source.token() == ContentDocumentLink.SObjectType
        ? ContentDocumentLink.LinkedEntityId
        : source.fieldMap().get('Id');
      if (anchor == null) {
        anchor = source.fieldMap().values()[0];
      }
      String name = String.valueOf(anchor);
      return '(' + name + ' = null ' + (always ? 'OR ' : 'AND ') + name + ' != null)';
    }
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

    /** The evaluator for the value's family, or null for an untyped value. */
    public Evaluator getEvaluator() {
      if (castName == null) {
        return null;
      }
      List<Object> operands;
      if (coll == Enums.Collective.ALIST) {
        operands = (List<Object>) value;
      } else if (coll == Enums.Collective.ASET) {
        Type listOfElements = Type.forName('List<' + atomicName + '>');
        operands = (List<Object>) JSON.deserialize(JSON.serialize(value), listOfElements);
      } else {
        // A Date added to a List<Datetime> would become a Datetime, so it gets a List<Date>.
        String elementType = atomicName == 'date' ? 'date' : castName;
        operands = (List<Object>) Type.forName('List<' + elementType + '>').newInstance();
        operands.add(value);
      }
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
  // the right ones, whether it equals the first, and how it orders against the first. `order` is
  // null when either side is null, and then no ordering operator holds. Others give null.
  private static Boolean decide(Enums.Comparator kind, Boolean among, Boolean same, Integer order) {
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
   * unique. INCLUDES and EXCLUDES split the field's value on semicolons.
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

    public StringEvaluator(List<String> texts) {
      super(texts);
    }

    private Boolean exactFor(DescribeFieldResult described) {
      if (exact == null) {
        exact = described != null &&
          described.getSoapType() == SoapType.STRING &&
          described.isCaseSensitive() &&
          described.isUnique();
      }
      return exact;
    }

    private Set<String> foldedTexts() {
      if (folded == null || foldedSize != texts.size()) {
        folded = new Set<String>();
        for (String text : texts) {
          folded.add(fold(text, exact));
        }
        foldedSize = texts.size();
      }
      return folded;
    }

    public override Boolean apply(Operator op, DescribeFieldResult described, Object left) {
      String subject = (String) left;
      String first = texts.isEmpty() ? null : texts[0];
      Enums.Comparator kind = op.comparator();
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
          return doEvaluateLike(subject, first);
        }
      }
      Boolean caseKept = exactFor(described);
      Set<String> wanted = foldedTexts();
      if (kind == Enums.Comparator.INC || kind == Enums.Comparator.EXC) {
        Boolean selected = false;
        for (String piece : (subject ?? '').split(';')) {
          selected = selected || wanted.contains(fold(piece, caseKept));
        }
        return (kind == Enums.Comparator.INC) == selected;
      }
      String key = fold(subject, caseKept);
      return decide(kind, wanted.contains(key), key.equals(fold(first, caseKept)), null);
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

    public override List<String> itemsToSoql() {
      List<String> literals = new List<String>();
      for (Object amount : operands) {
        literals.add(String.valueOf(amount));
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
      List<String> literals = new List<String>();
      for (Object moment : operands) {
        if (moment == null) {
          literals.add('null');
        } else if (moment instanceof Date) {
          Datetime midnight = Datetime.newInstanceGmt((Date) moment, Time.newInstance(0, 0, 0, 0));
          literals.add(midnight.formatGmt('yyyy-MM-dd'));
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

  /** Checkboxes: only equality and membership apply. */
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
      Boolean subject = (Boolean) left;
      Boolean first = flags.isEmpty() ? null : flags[0];
      Boolean among = false;
      for (Boolean candidate : flags) {
        among = among || candidate == subject;
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

  /** Tests one value against another without a Comparison; null when the value cannot be typed. */
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
