/**
 * Field-level helpers for records: multi-select and dependent picklist values, address field
 * groups, splitting long text across numbered fields, CSV export, change detection, grouping,
 * copying or merging fields, and turning text into the value a field takes (fromText).
 */
global class FieldUtil {
  global class GeneralException extends Exception {
  }

  private static final String MULTI_SEPARATOR = ';';
  private static final String BASE64_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  private static final String CSV_DATA_PREFIX = 'data:text/csv;charset=utf-8,';

  // Multi-select picklists

  global static Set<String> getMultipickValues(SObject holder, SObjectField field) {
    if (holder == null || field == null) {
      throw new GeneralException('Both a record and a field are required; got ' + holder + ' and ' + field);
    }
    String joined = (String) holder.get(field);
    return String.isBlank(joined) ? new Set<String>() : new Set<String>(joined.split(MULTI_SEPARATOR));
  }

  /** Adds the non-blank values; true when any was new. */
  global static Boolean pushMultipickValues(SObject holder, SObjectField field, Set<String> additions) {
    return revise(holder, field, additions, true);
  }

  /** Removes the values; true when any was present. */
  global static Boolean clearMultipickValues(SObject holder, SObjectField field, Set<String> removals) {
    return revise(holder, field, removals, false);
  }

  private static Boolean revise(SObject holder, SObjectField field, Set<String> given, Boolean adding) {
    Set<String> selected = getMultipickValues(holder, field);
    Integer sizeBefore = selected.size();
    List<String> meaningful = new List<String>();
    if (given != null) {
      for (String candidate : given) {
        if (String.isNotBlank(candidate)) {
          meaningful.add(candidate);
        }
      }
    }
    if (adding) {
      selected.addAll(meaningful);
    } else {
      selected.removeAll(meaningful);
    }
    holder.put(field, String.join(new List<String>(selected), MULTI_SEPARATOR));
    return selected.size() != sizeBefore;
  }

  /** Drops selections that are not active values of the field; true when any were dropped. */
  global static Boolean clearInvalidMultipickValues(SObject holder, SObjectField field) {
    Set<String> selected = getMultipickValues(holder, field);
    Set<String> valid = new Set<String>();
    for (Schema.PicklistEntry option : field.getDescribe().getPicklistValues()) {
      Boolean keep = option.isActive() && selected.contains(option.getValue());
      if (keep) {
        valid.add(option.getValue());
      }
    }
    holder.put(field, String.join(new List<String>(valid), MULTI_SEPARATOR));
    return !valid.equals(selected);
  }

  global static Set<String> getPicklistValues(SObjectField field) {
    List<String> values = new List<String>();
    for (Schema.PicklistEntry option : field.getDescribe().getPicklistValues()) {
      values.add(option.getValue());
    }
    return new Set<String>(values);
  }

  // Dependent picklists

  /**
   * For each controlling value, the dependent values it allows. Empty when the field has no
   * controlling field. A checkbox controller's values are 'false' and 'true'.
   */
  global static Map<String, Set<String>> getDependentPicklistValues(SObjectField dependentField) {
    Schema.DescribeFieldResult dependent = dependentField.getDescribe();
    SObjectField controllerField = dependent.getController();
    List<String> switches = new List<String>();
    if (controllerField != null) {
      Schema.DescribeFieldResult controller = controllerField.getDescribe();
      if (controller.getType() == Schema.DisplayType.BOOLEAN) {
        switches.addAll(new List<String>{ 'false', 'true' });
      } else {
        for (Schema.PicklistEntry option : controller.getPicklistValues()) {
          switches.add(option.getValue());
        }
      }
    }
    return groupByController(switches, readEntries(dependent.getPicklistValues()));
  }

  // Bit n of an entry's validFor is set when controlling value n allows the entry.
  @TestVisible
  private static Map<String, Set<String>> groupByController(
    List<String> switches,
    List<PicklistEntryWrapper> dependents
  ) {
    Map<String, Set<String>> allowed = new Map<String, Set<String>>();
    for (String switchValue : switches) {
      allowed.put(switchValue, new Set<String>());
    }
    for (PicklistEntryWrapper entry : dependents) {
      String bits = base64ToBits(entry.validFor);
      Integer reach = Math.min(bits.length(), switches.size());
      for (Integer at = 0; at < reach; at++) {
        if (bits.mid(at, 1) == '1') {
          allowed.get(switches[at]).add(entry.value);
        }
      }
    }
    return allowed;
  }

  /** Base 2 without leading zeros: 4 gives '100'. Zero, negatives and null give ''. */
  global static String decimalToBinary(Integer whole) {
    return whole == null ? '' : CharUtil.binary.fromDecimal(whole, 0);
  }

  /** Six bits per base64 character; characters outside the alphabet (such as '=') give zeros. */
  global static String base64ToBits(String encoded) {
    String bits = '';
    for (String symbol : String.isEmpty(encoded) ? new List<String>() : encoded.split('')) {
      Integer digit = Math.max(BASE64_ALPHABET.indexOf(symbol), 0);
      bits += decimalToBinary(digit).leftPad(6, '0');
    }
    return bits;
  }

  // PicklistEntry keeps validFor private but serializes it, so a JSON round trip reads it out.
  @TestVisible
  private static List<PicklistEntryWrapper> readEntries(List<Schema.PicklistEntry> options) {
    String serialized = JSON.serialize(options);
    return (List<PicklistEntryWrapper>) JSON.deserialize(serialized, List<PicklistEntryWrapper>.class);
  }

  global class PicklistEntryWrapper {
    global String validFor;
    global String value;
    global String label;
    global String defaultValue;
    global String active;
  }

  // Addresses

  /** The suffixes of a compound address's parts, e.g. Billing + Street. */
  global static final List<String> addressChunks = 'Street City State PostalCode Country'.split(' ');

  global static Set<String> getAddressFieldNames(String stem) {
    List<String> names = new List<String>();
    for (String part : addressChunks) {
      names.add(stem + part);
    }
    return new Set<String>(names);
  }

  global static void copyAddress(SObject source, String sourceStem, SObject target, String targetStem) {
    for (String part : addressChunks) {
      target.put(targetStem + part, source.get(sourceStem + part));
    }
  }

  global static Boolean addressIsBlank(SObject holder, String stem) {
    return addressIsBlank(holder, stem, null);
  }

  /** With `anyNotAll` true, whether any part is blank; otherwise whether every part is. */
  global static Boolean addressIsBlank(SObject holder, String stem, Boolean anyPart) {
    Integer blankParts = 0;
    for (String part : addressChunks) {
      Object value = holder.get(stem + part);
      blankParts += String.isBlank(String.valueOf(value)) ? 1 : 0;
    }
    return anyPart == true ? blankParts > 0 : blankParts == addressChunks.size();
  }

  // Long text across numbered fields

  /**
   * Splits the text across the fields named <stem>1__c, <stem>2__c and so on, filling each to its
   * length. Fields past the end of the text are cleared; text past the last field is lost.
   */
  global static SObject chunk(SObject target, String stem, String text) {
    Schema.DescribeSObjectResult described = target.getSObjectType().getDescribe();
    Map<String, SObjectField> byName = described.fields.getMap();
    List<SObjectField> numbered = new List<SObjectField>();
    while (byName.containsKey(stem + (numbered.size() + 1) + '__c')) {
      numbered.add(byName.get(stem + (numbered.size() + 1) + '__c'));
    }
    return chunk(target, numbered, text);
  }

  /** As above, across the given text fields in order. Every field is checked before any is set. */
  global static SObject chunk(SObject target, List<SObjectField> parts, String text) {
    for (SObjectField part : parts) {
      Boolean holdsText = part.getDescribe().getSoapType() == Schema.SoapType.STRING;
      if (!holdsText) {
        throw new GeneralException(part + ' is not a text field, so it cannot hold part of a value');
      }
    }
    String rest = text ?? '';
    for (SObjectField part : parts) {
      Integer room = part.getDescribe().getLength();
      target.put(part, rest.length() == 0 ? null : rest.left(room));
      rest = rest.length() > room ? rest.substring(room) : '';
    }
    return target;
  }

  // CSV

  /**
   * CSV text behind a `data:text/csv` prefix, written by CsvUtil (quoted cells, \n between
   * lines). Fields may be paths across lookups; with none given, every populated field is used.
   */
  global static String toCSV(List<SObject> rows, List<String> fields, Boolean withHeader) {
    List<String> columns = fields == null || fields.isEmpty() ? populatedFieldNames(rows) : fields;
    String table = CsvUtil.toCsv(columns, rows);
    if (withHeader == false) {
      table = table.substringAfter('\n');
    }
    return CSV_DATA_PREFIX + table;
  }

  global static String toCSV(List<SObject> rows, Boolean withHeader) {
    return toCSV(rows, null, withHeader);
  }

  global static String toCSV(List<SObject> rows) {
    return toCSV(rows, null, true);
  }

  // Related records are left out: they are not columns.
  private static List<String> populatedFieldNames(List<SObject> rows) {
    Set<String> seen = new Set<String>();
    for (SObject row : rows) {
      Map<String, Object> populated = row.getPopulatedFieldsAsMap();
      for (String name : populated.keySet()) {
        Object value = populated.get(name);
        if (!(value instanceof SObject) && !(value instanceof List<SObject>)) {
          seen.add(name);
        }
      }
    }
    return new List<String>(seen);
  }

  // Comparing and grouping

  /**
   * The records whose value differs from their previous version in any of the fields. A record
   * with no previous version counts as changed.
   */
  global static List<SObject> changed(List<SObject> current, Map<Id, SObject> previous, List<String> fieldNames) {
    List<SObject> differing = new List<SObject>();
    for (SObject now : current) {
      SObject before = previous.get(now.Id);
      if (before == null || differsIn(now, before, fieldNames)) {
        differing.add(now);
      }
    }
    return differing;
  }

  global static List<SObject> changed(List<SObject> current, Map<Id, SObject> previous, List<SObjectField> tokens) {
    List<String> asNames = new List<String>();
    for (SObjectField token : tokens) {
      asNames.add('' + token);
    }
    return changed(current, previous, asNames);
  }

  private static Boolean differsIn(SObject now, SObject before, List<String> fieldNames) {
    Boolean differs = false;
    for (Integer at = 0; at < fieldNames.size() && !differs; at++) {
      differs = now.get(fieldNames[at]) != before.get(fieldNames[at]);
    }
    return differs;
  }

  /** Records grouped by the text of a field's value; null groups under ''. */
  global static Map<String, List<SObject>> catalog(List<SObject> rows, String groupField) {
    Map<String, List<SObject>> groups = new Map<String, List<SObject>>();
    if (rows == null) {
      return groups;
    }
    for (SObject row : rows) {
      String label = String.valueOf(row.get(groupField)) ?? '';
      List<SObject> members = groups.get(label);
      if (members == null) {
        members = new List<SObject>();
        groups.put(label, members);
      }
      members.add(row);
    }
    return groups;
  }

  /** The fields that are null or, for text, blank. */
  global static List<SObjectField> getBlankFields(SObject holder, Set<SObjectField> candidates) {
    List<SObjectField> blank = new List<SObjectField>();
    for (SObjectField candidate : candidates) {
      Object value = holder.get(candidate);
      if (value == null || String.isBlank(String.valueOf(value))) {
        blank.add(candidate);
      }
    }
    return blank;
  }

  // Copying and merging

  /** A new record of the same type holding only the given fields. */
  global static SObject crop(SObject source, Set<SObjectField> keep) {
    SObject kept = source.getSObjectType().newSObject();
    for (SObjectField field : keep) {
      kept.put(field, source.get(field));
    }
    return kept;
  }

  /** As above, by field name; a dotted name such as Account.Name keeps that related field too. */
  global static SObject crop(SObject source, Set<String> keep) {
    SObject kept = source.getSObjectType().newSObject();
    for (String fieldPath : keep) {
      copyAlong(source, kept, fieldPath.split('\\.'), 0);
    }
    return kept;
  }

  private static void copyAlong(SObject source, SObject target, List<String> hops, Integer at) {
    String hop = hops[at];
    if (at == hops.size() - 1) {
      target.put(hop, source.get(hop));
      return;
    }
    SObject related = source.getSObject(hop);
    if (related == null) {
      return;
    }
    SObject relatedCopy = target.getSObject(hop);
    if (relatedCopy == null) {
      relatedCopy = related.getSObjectType().newSObject();
      target.putSObject(hop, relatedCopy);
    }
    copyAlong(related, relatedCopy, hops, at + 1);
  }

  /** The first record, with any null or missing field filled from the second. */
  global static SObject join(SObject dominant, SObject fallback) {
    if (dominant == null || fallback == null) {
      return dominant ?? fallback;
    }
    String combined = JSON.serialize(join(untyped(dominant), untyped(fallback)));
    Type recordType = Type.forName(String.valueOf(dominant.getSObjectType()));
    return (SObject) JSON.deserialize(combined, recordType);
  }

  /** Every key of either map; the first map's value wins unless it is null. */
  global static Map<String, Object> join(Map<String, Object> dominant, Map<String, Object> fallback) {
    Map<String, Object> merged = new Map<String, Object>();
    if (dominant != null) {
      merged.putAll(dominant);
    }
    for (String key : fallback == null ? new Set<String>() : fallback.keySet()) {
      if (merged.get(key) == null) {
        merged.put(key, fallback.get(key));
      }
    }
    return merged;
  }

  private static Map<String, Object> untyped(SObject record) {
    Object tree = JSON.deserializeUntyped(JSON.serialize(record));
    return (Map<String, Object>) tree;
  }

  // Text to values

  private static final Set<String> YES = new Set<String>{ 'true', 'yes', 'y', '1' };
  private static final Set<String> NO = new Set<String>{ 'false', 'no', 'n', '0' };
  private static final Pattern PLAIN_NUMBER = Pattern.compile('[+-]?(\\d+(\\.\\d+)?|\\.\\d+)');
  private static final Pattern GROUPED_NUMBER = Pattern.compile('[+-]?\\d{1,3}(,\\d{3})+(\\.\\d+)?');
  private static final Pattern ISO_DATE = Pattern.compile('\\d{4}-\\d{2}-\\d{2}');
  private static final Pattern LOCAL_STAMP = Pattern.compile('\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}(:\\d{2})?');
  private static final Pattern CLOCK = Pattern.compile('(\\d{1,2}):(\\d{2})(:(\\d{2}))?');
  private static final Set<DisplayType> NOT_TEXT = new Set<DisplayType>{
    DisplayType.ADDRESS,
    DisplayType.LOCATION,
    DisplayType.BASE64,
    DisplayType.ANYTYPE,
    DisplayType.COMPLEXVALUE
  };

  /** Whether a field of this kind can be given a value from text at all: not an address, a location or a file. */
  global static Boolean takesText(Schema.DescribeFieldResult shape) {
    return !NOT_TEXT.contains(shape.getType());
  }

  /** As fromText(DescribeFieldResult, String), for a field token. */
  global static Object fromText(SObjectField field, String text) {
    return fromText(field.getDescribe(), text);
  }

  /**
   * Text, as a person would type it into a file or a form, turned into the value the field takes.
   * Blank text is null. Text the field cannot take throws a GeneralException whose message quotes
   * the text and says what was expected, e.g. "soon" is not a date; write it like 2026-01-31.
   *
   * | Field | Text it reads |
   * | --- | --- |
   * | Checkbox | true, yes, y, 1, false, no, n, 0, in any case |
   * | Number, currency, percent | 1234.5, -1234.5, 1,234.5; a percent may end in % |
   * | Date | 2026-01-31, or the way the running user's locale writes a date |
   * | Date and time | 2026-01-31T14:30:00Z, 2026-01-31 14:30 in the user's time zone, a date alone, or their locale's way |
   * | Time | 14:30 or 14:30:15 |
   * | Lookup | An Id of an object the field can point at |
   * | Picklist | A value or its label, in any case; anything else is passed on as written |
   * | Any other | The text, trimmed |
   *
   * A comma is taken as a thousands separator only where it sits like one, so 1,5 is refused and
   * not read as 15.
   */
  global static Object fromText(Schema.DescribeFieldResult shape, String text) {
    if (String.isBlank(text)) {
      return null;
    }
    String trimmed = text.trim();
    switch on shape.getSoapType() {
      when BOOLEAN {
        return yesOrNo(trimmed);
      }
      when INTEGER {
        return wholeNumber(trimmed);
      }
      when DOUBLE {
        return numberIn(shape.getType() == DisplayType.PERCENT ? trimmed.removeEnd('%').trim() : trimmed);
      }
      when DATE {
        return day(trimmed);
      }
      when DATETIME {
        return moment(trimmed);
      }
      when TIME {
        return timeOfDay(trimmed);
      }
      when ID {
        return recordId(shape, trimmed);
      }
      when else {
        return shape.getType() == DisplayType.PICKLIST ? listed(shape, trimmed) : trimmed;
      }
    }
  }

  private static GeneralException unreadable(String text, String why) {
    return new GeneralException('"' + text.abbreviate(40) + '" ' + why);
  }

  private static Boolean yesOrNo(String text) {
    String lower = text.toLowerCase();
    if (!YES.contains(lower) && !NO.contains(lower)) {
      throw unreadable(text, 'is not yes or no');
    }
    return YES.contains(lower);
  }

  private static Decimal numberIn(String text) {
    String digits = GROUPED_NUMBER.matcher(text).matches() ? text.remove(',') : text;
    if (!PLAIN_NUMBER.matcher(digits).matches()) {
      throw unreadable(text, 'is not a number');
    }
    return Decimal.valueOf(digits.removeStart('+'));
  }

  private static Integer wholeNumber(String text) {
    Decimal read = numberIn(text);
    if (read != read.setScale(0) || read.abs() > 2147483647) {
      throw unreadable(text, 'is not a whole number this field can hold');
    }
    return read.intValue();
  }

  private static Date day(String text) {
    try {
      return ISO_DATE.matcher(text).matches() ? Date.valueOf(text) : Date.parse(text);
    } catch (Exception refused) {
      throw unreadable(text, 'is not a date; write it like 2026-01-31');
    }
  }

  private static Datetime moment(String text) {
    try {
      if (ISO_DATE.matcher(text).matches()) {
        return Datetime.newInstance(Date.valueOf(text), Time.newInstance(0, 0, 0, 0));
      }
      if (LOCAL_STAMP.matcher(text).matches()) {
        return Datetime.valueOf(text.length() == 16 ? text + ':00' : text);
      }
      if (text.contains('T')) {
        return (Datetime) JSON.deserialize(JSON.serialize(text), Datetime.class);
      }
      return Datetime.parse(text);
    } catch (Exception refused) {
      throw unreadable(text, 'is not a date and time; write it like 2026-01-31 14:30');
    }
  }

  private static Time timeOfDay(String text) {
    Matcher clock = CLOCK.matcher(text);
    if (clock.matches()) {
      Integer hour = Integer.valueOf(clock.group(1));
      Integer minute = Integer.valueOf(clock.group(2));
      Integer second = clock.group(4) == null ? 0 : Integer.valueOf(clock.group(4));
      if (hour < 24 && minute < 60 && second < 60) {
        return Time.newInstance(hour, minute, second, 0);
      }
    }
    throw unreadable(text, 'is not a time; write it like 14:30');
  }

  private static Id recordId(Schema.DescribeFieldResult shape, String text) {
    if (!(text instanceof Id)) {
      throw unreadable(text, 'is not an Id');
    }
    Id given = (Id) text;
    List<SObjectType> targets = shape.getReferenceTo();
    if (!targets.isEmpty() && !targets.contains(given.getSobjectType())) {
      throw unreadable(text, 'is the Id of a ' + given.getSobjectType().getDescribe().getLabel() + ', which ' + shape.getLabel() + ' cannot point at');
    }
    return given;
  }

  // A picklist's value as the field holds it, found by value or by label whatever the case.
  private static String listed(Schema.DescribeFieldResult shape, String text) {
    for (PicklistEntry option : shape.getPicklistValues()) {
      if (option.getValue().equalsIgnoreCase(text) || option.getLabel().equalsIgnoreCase(text)) {
        return option.getValue();
      }
    }
    return text;
  }
}
