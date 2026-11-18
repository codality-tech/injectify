/**
 * The schema layer. A Model wraps one SObjectType (fields, record types, child relationships)
 * and turns routes into paths. A Path is one field reached from a model, directly or across
 * lookups (Contact, then Account, then Owner, then Name). A lookup with a single target
 * (MonoPath) is also a reference that longer paths can start from; one with several targets
 * (PolyPath) is not. Orderings and aggregate functions live here too, as both are built on paths.
 */
public class Modeling {
  public IScheme scheme;
  private Core core;
  // One model per object, shared by everything this modeling hands out.
  private Map<SObjectType, Model> models = new Map<SObjectType, Model>();
  private static final Integer SHORTEST_RELATIONSHIP_NAME = 3;

  public class ReferenceException extends Exception {
  }

  public class OrderingRealizeException extends Exception {
    public OrderingRealizeException(SObjectType offered, SObjectType bound) {
      this('Upstream SObjectType ' + offered + ' does not match current SObjectType ' + bound);
    }
  }

  public class ModelException extends Exception {
  }

  /** A null scheme falls back to SchemeDefault. */
  public Modeling(IScheme scheme, Core core) {
    this.core = core;
    this.scheme = scheme ?? new SchemeDefault();
  }

  /** Replaces the core, and forgets the models built with the old one. */
  public void setCore(Core core) {
    models.clear();
    this.core = core;
  }

  public IScheme scheme() {
    return scheme;
  }

  public Core core() {
    return core;
  }

  /** The model for a type, built once and then shared; null for null. */
  public Model model(SObjectType objectType) {
    Model known = objectType == null ? null : models.get(objectType);
    if (known == null && objectType != null) {
      known = new Model(objectType, scheme, this, core);
      models.put(objectType, known);
    }
    return known;
  }

  /** By API name; null when the name is null or not an object. */
  public Model model(String sobjectName) {
    SObjectType named = sobjectName == null ? null : scheme.getSObjectType(sobjectName);
    return model(named);
  }

  // The model a field sequence starts from: the object of its first field.
  private Model model(List<SObjectField> fieldSequence) {
    SObjectField first = fieldSequence == null || fieldSequence.isEmpty() ? null : fieldSequence[0];
    if (first == null) {
      throw new ReferenceException('A field path needs at least one field');
    }
    return model(scheme.getFieldDescribe(first).getSObjectType());
  }

  // In a dotted path, a part before the last names a relationship; this is its lookup field:
  // Account becomes AccountId and Owner__r becomes Owner__c. Names already ending in Id or __c
  // are kept. Too short to be either gives null.
  private static String lookupFieldName(String part) {
    Integer length = part == null ? 0 : part.length();
    if (length < SHORTEST_RELATIONSHIP_NAME) {
      return null;
    }
    if (part.endsWithIgnoreCase('__r')) {
      return part.left(part.length() - 3) + '__c';
    }
    if (part.endsWithIgnoreCase('__c') || part.endsWithIgnoreCase('id')) {
      return part;
    }
    return part + 'Id';
  }

  private static Path pathFrom(IReference start, Object via, Boolean strictType, Boolean strictNull) {
    Destination found = new Destination(start, via);
    return (Path) found.checked(found.path, strictType, strictNull);
  }

  private static IReference referenceFrom(IReference start, Object route) {
    Destination found = new Destination(start, route);
    return (IReference) found.checked(found.reference, null, null);
  }

  /*
   * Where a route leads from a starting reference (a model, or a single-target lookup). A route
   * is a dotted name, a field, a list of fields, a Path, or a Model naming the start itself
   * (as does a blank name). The result is a path, and a reference when it leads to one object.
   */
  private class Destination {
    private IReference start;
    private Object route;
    private Boolean recognized = true;
    private Path path;
    private IReference reference;

    private Destination(IReference start, Object route) {
      this.start = start;
      this.route = route;
      Boolean toStart = false;
      Boolean deadEnd = false;
      List<SObjectField> steps;
      if (route instanceof Model) {
        toStart = (Model) route == start.target();
      } else if (route instanceof Path) {
        Path given = (Path) route;
        steps = given.fieldSequence();
        Boolean sameStart = start instanceof Model && given.source() == start.source();
        path = sameStart ? given : null;
      } else if (route instanceof String) {
        String dotted = (String) route;
        toStart = String.isBlank(dotted);
        steps = ((Model) start.target()).surmiseTokenSequence(dotted);
        // A name that does not resolve leads nowhere, rather than back to where it started.
        deadEnd = steps == null && !toStart;
      } else if (route instanceof List<SObjectField>) {
        steps = ((List<SObjectField>) route).clone();
      } else if (route instanceof SObjectField) {
        steps = new List<SObjectField>();
        steps.add((SObjectField) route);
      } else {
        recognized = false;
      }
      Boolean unresolved = path == null && !deadEnd;
      if (unresolved) {
        List<SObjectField> walked = start instanceof Path ? ((Path) start).fieldSequence() : new List<SObjectField>();
        walked.addAll(steps ?? new List<SObjectField>());
        path = ((Model) start.source()).doGetPath(walked);
      }
      if (toStart) {
        reference = start;
      } else if (path instanceof IReference) {
        reference = (IReference) path;
      }
    }

    // Nothing found throws when the route was of an unsupported kind (unless requireValidType
    // is false), or for any route when requireNotNull is true.
    private Object checked(Object found, Boolean requireValidType, Boolean requireNotNull) {
      if (found == null && requireValidType != false && !recognized) {
        throw new PathException('Cannot follow ' + route + ' from ' + start + ': unsupported route type');
      }
      if (found == null && requireNotNull == true) {
        throw new PathException('Cannot follow ' + route + ' from ' + start + ': it leads nowhere');
      }
      return found;
    }
  }
  private static void need(Object given, String what) {
    if (given == null) {
      throw new ModelException(what + ' must not be null');
    }
  }

  /**
   * One object's schema, read through the scheme and remembered: fields, field sets, the name
   * field, record types and child relationships. It is also the reference that every path from
   * the object starts at, which is why it answers the IReference questions with "here".
   */
  public class Model implements IModel, IReference {
    private SObjectType objectType;
    private IScheme scheme;
    private Modeling modeling;
    private Core core;

    private String apiName;
    private Map<String, SObjectField> fieldsByName;
    private Set<SObjectField> ownFields;
    private Map<String, FieldSet> fieldSets;
    private SObjectField titleField;
    private Boolean titleFieldSought = false;
    private Map<String, Id> recordTypeIds;
    private Map<Id, String> recordTypeNames;
    private Map<String, ChildRelationship> childrenByName;
    private Map<SObjectField, ChildRelationship> childrenByLookup;
    // Every path resolved from this model, by its field sequence; null marks a sequence that
    // leads nowhere. Paths hold no changing state, so one instance can be shared.
    private Map<List<SObjectField>, Path> pathByFields = new Map<List<SObjectField>, Path>();

    // The core may be null while a Core is still being constructed; setCore() follows.
    private Model(SObjectType token, IScheme scheme, Modeling modeling, Core core) {
      need(token, 'token (SObjectType)');
      need(scheme, 'scheme');
      need(modeling, 'modeling');
      objectType = token;
      this.scheme = scheme;
      this.modeling = modeling;
      this.core = core;
    }

    // Identity

    public SObjectType token() {
      return objectType;
    }

    /** The API name, e.g. Account or Invoice__c. */
    public String name() {
      if (apiName == null) {
        apiName = String.valueOf(objectType);
      }
      return apiName;
    }

    public override String toString() {
      return name();
    }

    /** Models of the same object are equal, whichever core made them. */
    public Boolean equals(Object other) {
      return other instanceof Model && ((Model) other).objectType == objectType;
    }

    public Integer hashCode() {
      return name().hashCode();
    }

    public IScheme scheme() {
      return scheme;
    }

    public Core core() {
      return core;
    }

    public Modeling modeler() {
      return modeling;
    }

    // Describe

    public DescribeSObjectResult describe() {
      return scheme.getDescribe(objectType);
    }

    public Map<String, SObjectField> fieldMap() {
      if (fieldsByName == null) {
        fieldsByName = scheme.getFieldMap(objectType);
      }
      return fieldsByName;
    }

    public Map<String, FieldSet> fieldSetMap() {
      if (fieldSets == null) {
        fieldSets = scheme.getFieldsetMap(objectType);
      }
      return fieldSets;
    }

    /** The field shown as the record's name; null for the few objects without one. */
    public SObjectField nameField() {
      if (!titleFieldSought) {
        titleFieldSought = true;
        for (SObjectField candidate : fieldMap().values()) {
          if (scheme.getFieldDescribe(candidate).isNameField()) {
            titleField = candidate;
            break;
          }
        }
      }
      return titleField;
    }

    // Whether the field belongs to this object: a set lookup rather than a scan of the field map.
    private Boolean owns(SObjectField field) {
      if (ownFields == null) {
        ownFields = new Set<SObjectField>(fieldMap().values());
      }
      return ownFields.contains(field);
    }

    // Record types, by developer name

    private void loadRecordTypes() {
      if (recordTypeIds != null) {
        return;
      }
      recordTypeIds = new Map<String, Id>();
      recordTypeNames = new Map<Id, String>();
      for (Schema.RecordTypeInfo info : describe().getRecordTypeInfosByDeveloperName().values()) {
        recordTypeIds.put(info.getDeveloperName(), info.getRecordTypeId());
        recordTypeNames.put(info.getRecordTypeId(), info.getDeveloperName());
      }
    }

    public Map<String, Id> recordTypeIdByName() {
      loadRecordTypes();
      return recordTypeIds;
    }

    /** Throws when the object has no record type with that developer name. */
    public Id recordTypeId(String developerName) {
      Id found = recordTypeIdByName().get(developerName);
      if (found == null) {
        throw new ModelException(name() + ' has no record type named ' + developerName);
      }
      return found;
    }

    /** The developer name; throws when the Id is not one of this object's record types. */
    public String recordTypeName(Id recordTypeId) {
      loadRecordTypes();
      String found = recordTypeNames.get(recordTypeId);
      if (found == null) {
        throw new ModelException(name() + ' has no record type with Id ' + recordTypeId);
      }
      return found;
    }

    /** RecordTypeId IN the named record types; an unknown name throws. */
    public ICondition condRtdn(Set<String> wanted) {
      Set<Id> ids = new Set<Id>();
      for (String developerName : wanted) {
        ids.add(recordTypeId(developerName));
      }
      ICondition inThose = core.iin('RecordTypeId', ids);
      inThose.realize(objectType);
      return inThose;
    }

    // Child relationships, for subqueries

    private void loadChildRelationships() {
      if (childrenByName != null) {
        return;
      }
      childrenByName = new Map<String, ChildRelationship>();
      childrenByLookup = new Map<SObjectField, ChildRelationship>();
      for (ChildRelationship link : describe().getChildRelationships()) {
        if (String.isNotBlank(link.getRelationshipName())) {
          childrenByName.put(link.getRelationshipName().toLowerCase(), link);
        }
        if (link.getField() != null) {
          childrenByLookup.put(link.getField(), link);
        }
      }
    }

    /** By relationship name (Contacts), in any case. */
    public ChildRelationship getChildRelationship(String relationshipName) {
      loadChildRelationships();
      return childrenByName.get(relationshipName.toLowerCase());
    }

    /** By the lookup field on the child (Contact.AccountId). */
    public ChildRelationship getChildRelationship(SObjectField lookupOnChild) {
      loadChildRelationships();
      return childrenByLookup.get(lookupOnChild);
    }

    // Records

    /** A record of this object from field values, typed as the object (not a bare SObject). */
    public SObject spawnRecord(Map<String, Object> valuesByField) {
      Type recordClass = core.injector().getType(name());
      return (SObject) JSON.deserialize(JSON.serialize(valuesByField), recordClass);
    }

    /** An empty list typed for this object, e.g. List<Account>. */
    public List<SObject> spawnRecordList() {
      return (List<SObject>) core.injector().newInstance('List<' + name() + '>');
    }

    public IDomain domain(List<SObject> rows) {
      Domain plain = new Domain();
      plain.init(this, rows);
      return plain;
    }

    // Paths

    public Path path(Object via) {
      return pathFrom(this, via, null, null);
    }

    public Path path(Object via, Boolean strictType, Boolean strictNull) {
      return pathFrom(this, via, strictType, strictNull);
    }

    public IReference getReference(Object via) {
      return referenceFrom(this, via);
    }

    /*
     * The fields a dotted name walks, or null if it does not resolve. Each part is a field name;
     * a part that is not one is tried as the relationship of a lookup (Account for AccountId,
     * Owner__r for Owner__c). Every part but the last must be a lookup to a single object.
     * A blank name gives null.
     */
    public List<SObjectField> surmiseTokenSequence(String dottedName) {
      if (String.isBlank(dottedName)) {
        return null;
      }
      List<String> parts = dottedName.split('\\.');
      List<SObjectField> walked = new List<SObjectField>();
      Model here = this;
      for (Integer at = 0; at < parts.size(); at++) {
        Map<String, SObjectField> known = here.fieldMap();
        SObjectField step = known.get(parts[at]);
        if (step == null) {
          step = known.get(lookupFieldName(parts[at]));
        }
        if (step == null) {
          return null;
        }
        if (at < parts.size() - 1) {
          List<SObjectType> pointsAt = scheme.getFieldDescribe(step).getReferenceTo();
          if (pointsAt.size() != 1) {
            return null;
          }
          here = modeling.model(pointsAt[0]);
        }
        walked.add(step);
      }
      return walked;
    }

    // The path along the fields from this model, or null if they do not form one. Every step but
    // the last must be a single-target lookup. Results, including null, are cached.
    private Path doGetPath(List<SObjectField> fieldSequence) {
      if (fieldSequence == null || fieldSequence.isEmpty()) {
        return null;
      }
      if (pathByFields.containsKey(fieldSequence)) {
        return pathByFields.get(fieldSequence);
      }
      Path resolved = resolvePath(fieldSequence);
      pathByFields.put(fieldSequence.clone(), resolved);
      return resolved;
    }

    private Path resolvePath(List<SObjectField> fieldSequence) {
      Integer last = fieldSequence.size() - 1;
      Model stepModel = this;
      List<SObjectType> targets;
      for (Integer at = 0; at <= last; at++) {
        SObjectField step = fieldSequence[at];
        if (step == null || !stepModel.owns(step)) {
          return null;
        }
        targets = scheme.getFieldDescribe(step).getReferenceTo();
        if (at < last) {
          if (targets.size() != 1) {
            return null;
          }
          stepModel = modeling.model(targets[0]);
        }
      }
      List<SObjectField> lead = new List<SObjectField>();
      for (Integer at = 0; at < last; at++) {
        lead.add(fieldSequence[at]);
      }
      IReference via = lead.isEmpty() ? (IReference) this : (IReference) doGetPath(lead);
      SObjectField terminus = fieldSequence[last];
      if (targets.isEmpty()) {
        return new Path(via, terminus, modeling);
      }
      return targets.size() == 1 ? (Path) new MonoPath(via, terminus, modeling) : new PolyPath(via, terminus, modeling);
    }

    // Conditions and queries

    /** Compiles against the condition's own object when it has one, else this object. */
    public IConditionCompilation compileCondition(ICondition root) {
      SObjectType against = root?.source()?.token() ?? objectType;
      return new Filtering.ConditionCompilation(against, root, core.filtering());
    }

    /** A condition from text such as: Industry = 'Energy' AND AnnualRevenue > 1000000 */
    public ICondition parseCondition(String expression) {
      ConditionParser parser = new ConditionParser();
      ICondition parsed = parser.toCondition(parser.parse(expression), core.filtering(), core);
      parsed.realize(objectType);
      return parsed;
    }

    public IQuery query() {
      return new Query(this);
    }

    public IQuery query(List<ICondition> conditions) {
      Query filtered = new Query(this);
      filtered.filters().addAll(conditions);
      return filtered;
    }

    public IAggregateQuery aggregateQuery() {
      return new AggregateQuery(this);
    }

    // As a reference: a model is where its paths begin, so it leads to itself over no fields.

    public Model source() {
      return this;
    }

    public Integer size() {
      return 0;
    }

    public List<SObjectField> fieldSequence() {
      return new List<SObjectField>();
    }

    public Model target() {
      return this;
    }

    /** A field of this object needs no prefix. */
    public String toSoql(SObjectField field) {
      return scheme.getFieldDescribe(field).getName();
    }

    public IPath toPath() {
      return null;
    }

    public SObject getRecordValue(SObject row) {
      return row;
    }
  }

  public class PathException extends Exception {
  }

  /** The path to one field of its own object. */
  public Path path(SObjectField field) {
    List<SObjectField> single = new List<SObjectField>();
    single.add(field);
    return path(single);
  }

  /** The path along the fields, from the object of the first one. */
  public Path path(List<SObjectField> steps) {
    Model start = model(steps);
    return start.doGetPath(steps);
  }

  public class FieldException extends Exception {
  }

  /**
   * One field reached from a model, directly or across single-target lookups. name() is the SOQL
   * form (Account.Owner.Name); label() joins the field labels with dots.
   */
  public virtual class Path implements IPath {
    private IReference origin;
    private SObjectField endField;
    private Modeling modeling;
    private List<SObjectField> steps;
    private String soqlName;
    private String dottedLabel;
    private String qualifiedName;

    private Path(IReference origin, SObjectField endField, Modeling modeling) {
      if (origin == null || endField == null || modeling == null) {
        throw new PathException('A path needs a reference, a field and the modeling that made them');
      }
      IModel holder = origin.target();
      Boolean belongs = holder instanceof Model
        ? ((Model) holder).owns(endField)
        : holder.fieldMap().values().contains(endField);
      if (!belongs) {
        throw new FieldException(endField + ' is not a field of ' + holder.name());
      }
      this.origin = origin;
      this.endField = endField;
      this.modeling = modeling;
    }

    public IReference reference() {
      return origin;
    }

    public SObjectField terminus() {
      return endField;
    }

    public Model source() {
      return (Model) origin.source();
    }

    public DescribeFieldResult describe() {
      return modeling.scheme.getFieldDescribe(endField);
    }

    /** The fields walked, ending with the terminus. */
    public List<SObjectField> fieldSequence() {
      return steps().clone();
    }

    public Integer size() {
      return steps().size();
    }

    private List<SObjectField> steps() {
      if (steps == null) {
        steps = origin instanceof Path ? ((Path) origin).fieldSequence() : new List<SObjectField>();
        steps.add(endField);
      }
      return steps;
    }

    public String name() {
      if (soqlName == null) {
        soqlName = origin.toSoql(endField);
      }
      return soqlName;
    }

    public String label() {
      if (dottedLabel == null) {
        String own = describe().getLabel();
        dottedLabel = origin instanceof MonoPath ? ((MonoPath) origin).label() + '.' + own : own;
      }
      return dottedLabel;
    }

    public virtual String relationshipName() {
      throw new PathException(name() + ' is not a lookup, so it has no relationship name');
    }

    public virtual IReference toReference() {
      throw new ReferenceException(name() + ' does not lead to a single related object');
    }

    public Object getFieldValue(SObject record) {
      SObject holder = origin.getRecordValue(record);
      return holder == null ? null : holder.get(endField);
    }

    // Equal when they start from the same model and read the same field the same way.
    public Boolean equals(Object other) {
      if (other instanceof Path) {
        Path that = (Path) other;
        return that.source() == source() && that.name() == name();
      }
      return false;
    }

    public Integer hashCode() {
      return toString().hashCode();
    }

    /** Object and path, e.g. Contact:Account.Name. */
    public override String toString() {
      if (qualifiedName == null) {
        qualifiedName = source().name() + ':' + name();
      }
      return qualifiedName;
    }
  }

  /** A path ending in a lookup field; getRecordValue follows it to the related record. */
  public abstract class LookupPath extends Path implements ILookupPath {
    private String relationshipPath;
    private List<Model> targetModels;

    private LookupPath(IReference origin, SObjectField endField, Modeling modeling) {
      super(origin, endField, modeling);
    }

    /** Dotted from the source, e.g. Account.Owner. */
    public override String relationshipName() {
      if (relationshipPath == null) {
        String own = describe().getRelationshipName();
        relationshipPath = origin instanceof MonoPath ? ((MonoPath) origin).relationshipName() + '.' + own : own;
      }
      return relationshipPath;
    }

    /** Every object the lookup can point at. */
    public List<Model> targets() {
      if (targetModels == null) {
        targetModels = new List<Model>();
        for (SObjectType pointedAt : describe().getReferenceTo()) {
          targetModels.add(modeling.model(pointedAt));
        }
      }
      return targetModels.clone();
    }

    public SObject getRecordValue(SObject record) {
      SObject holder = origin.getRecordValue(record);
      return holder == null ? null : holder.getSObject(endField);
    }
  }

  /** A lookup with one target: also a reference that longer paths start from. */
  public class MonoPath extends LookupPath implements IReference {
    private MonoPath(IReference origin, SObjectField endField, Modeling modeling) {
      super(origin, endField, modeling);
    }

    public Model target() {
      return targets()[0];
    }

    public Path toPath() {
      return this;
    }

    public override IReference toReference() {
      return this;
    }

    public IReference getReference(Object via) {
      return referenceFrom(this, via);
    }

    public Path path(Object via, Boolean strictType, Boolean strictNull) {
      return pathFrom(this, via, strictType, strictNull);
    }

    public Path path(Object via) {
      return pathFrom(this, via, null, null);
    }

    /** A field of the target, written through this lookup: Account.Owner.Name. */
    public String toSoql(SObjectField field) {
      return relationshipName() + '.' + field;
    }
  }

  /** A lookup with several possible targets, such as WhatId; fields beyond it need TYPEOF. */
  public class PolyPath extends LookupPath {
    private PolyPath(IReference origin, SObjectField endField, Modeling modeling) {
      super(origin, endField, modeling);
    }
  }

  // # Ordering

  public IOrdering ordering(
    Object route,
    Boolean isAscending,
    Boolean nullsLast
  ) {
    return new Ordering(route, isAscending, nullsLast, this);
  }

  public IOrdering ordering(Object route, Boolean isAscending) {
    return ordering(route, isAscending, false);
  }

  public IOrdering ordering(Object route) {
    return ordering(route, true, false);
  }

  /**
   * A sort key: where to read the value, which direction, and where nulls go. It renders as an
   * ORDER BY term and sorts record lists in memory the same way. A route given as a name is
   * resolved once the object is known (realize).
   */
  public class Ordering implements IOrdering {
    private Modeling modeling;
    private Object route;
    private IModel source;
    private IPath path;
    private Boolean ascending;
    private Boolean nullsAtEnd;

    /** Ascending with nulls first unless told otherwise. */
    public Ordering(Object route, Boolean isAscending, Boolean nullsLast, Modeling modeling) {
      this.modeling = modeling;
      this.route = route;
      ascending = isAscending != false;
      nullsAtEnd = nullsLast == true;

      IPath known;
      if (route instanceof IPath) {
        known = (IPath) route;
      } else if (route instanceof List<SObjectField>) {
        known = modeling.path((List<SObjectField>) route);
      } else if (route instanceof SObjectField) {
        known = modeling.path((SObjectField) route);
      }
      if (known != null) {
        path = known;
        source = known.source();
      }
    }

    public Boolean isAscending() {
      return ascending;
    }

    public Boolean nullsLast() {
      return nullsAtEnd;
    }

    public IPath path() {
      return path;
    }

    public IModel source() {
      return source;
    }

    /** Binds the ordering to an object, resolving a route that was given by name. */
    public void realize(SObjectType objectType) {
      if (objectType == null) {
        throw new OrderingRealizeException('SObjectType argument must not be null');
      }
      if (source == null) {
        source = modeling.model(objectType);
      } else if (source.token() != objectType) {
        throw new OrderingRealizeException(objectType, source.token());
      }
      if (path == null && route != null) {
        path = source.path(route, true, true);
      }
    }

    public String toSoql() {
      if (path == null) {
        throw new OrderingRealizeException('Ordering must be realized before generating SOQL');
      }
      List<String> words = new List<String>{ path.name(), ascending ? 'ASC' : 'DESC', 'NULLS', nullsAtEnd ? 'LAST' : 'FIRST' };
      return String.join(words, ' ');
    }

    /** Sorts the list in place. Records with equal values keep their order. */
    public void apply(List<SObject> rows) {
      if (rows == null || rows.isEmpty()) {
        return;
      }
      if (source == null || path == null) {
        realize(rows[0].getSObjectType());
      }

      // Each value is read once; the sort then compares those values, not the records.
      Integer count = rows.size();
      List<Object> keys = new List<Object>();
      List<Integer> positions = new List<Integer>();
      for (Integer at = 0; at < count; at++) {
        positions.add(at);
        keys.add(path.getFieldValue(rows[at]));
      }
      positions.sort(new RecordComparator(keys, path.describe().getSoapType(), ascending, nullsAtEnd));
      List<SObject> unsorted = rows.clone();
      for (Integer at = 0; at < count; at++) {
        rows[at] = unsorted[positions[at]];
      }
    }
  }

  /**
   * Orders record positions by values read beforehand, for Ordering.apply. Nulls go first or last
   * whatever the direction, as SOQL's NULLS FIRST / NULLS LAST do; equal values keep their order.
   */
  private class RecordComparator implements System.Comparator<Integer> {
    private List<Object> keys;
    private Schema.SoapType valueType;
    private Integer direction;
    private Integer nullPlacement;

    private RecordComparator(List<Object> keys, Schema.SoapType valueType, Boolean ascending, Boolean nullsAtEnd) {
      this.keys = keys;
      this.valueType = valueType;
      direction = ascending == false ? -1 : 1;
      nullPlacement = nullsAtEnd == true ? 1 : -1;
    }

    public Integer compare(Integer left, Integer right) {
      Object a = keys[left];
      Object b = keys[right];
      Integer verdict;
      if (a == null || b == null) {
        verdict = a == b ? 0 : (a == null ? nullPlacement : -nullPlacement);
      } else {
        verdict = direction * compareValues(a, b);
      }
      return verdict == 0 ? left - right : verdict;
    }

    private Integer compareValues(Object a, Object b) {
      switch on valueType {
        when BOOLEAN {
          return rank(a == b, (Boolean) a);
        }
        when INTEGER {
          return rank((Integer) a == (Integer) b, (Integer) a > (Integer) b);
        }
        when LONG {
          return rank((Long) a == (Long) b, (Long) a > (Long) b);
        }
        when DOUBLE {
          return rank((Decimal) a == (Decimal) b, (Decimal) a > (Decimal) b);
        }
        when DATE {
          return rank((Date) a == (Date) b, (Date) a > (Date) b);
        }
        when DATETIME {
          return rank((Datetime) a == (Datetime) b, (Datetime) a > (Datetime) b);
        }
        when TIME {
          Integer x = millisOfDay((Time) a);
          Integer y = millisOfDay((Time) b);
          return rank(x == y, x > y);
        }
        when else {
          String x = String.valueOf(a);
          String y = String.valueOf(b);
          return rank(x == y, x > y);
        }
      }
    }

    private Integer rank(Boolean isEqual, Boolean isGreater) {
      return isEqual ? 0 : (isGreater ? 1 : -1);
    }

    private Integer millisOfDay(Time value) {
      return ((value.hour() * 60 + value.minute()) * 60 + value.second()) *
        1000 + value.millisecond();
    }
  }

  /**
   * Represents an aggregate function for use in aggregate queries
   */
  public class AggregateFunction implements IAggregateFunction {
    private String funcName;
    private Object fieldRef;
    private String alias;

    public AggregateFunction(String funcName, Object fieldRef) {
      this.funcName = funcName;
      this.fieldRef = fieldRef;
    }

    public String functionName() {
      return this.funcName;
    }

    public Object field() {
      return this.fieldRef;
    }

    public String toSoql() {
      // A bare COUNT() takes no alias and must stand alone, so a row count is COUNT(Id).
      if (fieldRef == null && funcName == 'COUNT') {
        return 'COUNT(Id)';
      }

      String fieldSoql;
      if (fieldRef instanceof SObjectField) {
        fieldSoql = ((SObjectField) fieldRef).getDescribe().getName();
      } else if (fieldRef instanceof IPath) {
        fieldSoql = ((IPath) fieldRef).name();
      } else if (fieldRef instanceof String) {
        fieldSoql = (String) fieldRef;
      } else {
        throw new ModelException(
          'Invalid field type for aggregate function: ' + fieldRef
        );
      }

      return funcName + '(' + fieldSoql + ')';
    }

    public String getAlias() {
      return this.alias != null ? this.alias : generateAutoAlias();
    }

    public IAggregateFunction setAlias(String alias) {
      this.alias = alias;
      return this;
    }

    private String generateAutoAlias() {
      // COUNT() with no field
      if (fieldRef == null && funcName == 'COUNT') {
        return 'cnt';
      }

      // Get field name
      String fieldName;
      if (fieldRef instanceof SObjectField) {
        fieldName = ((SObjectField) fieldRef).getDescribe().getName();
      } else if (fieldRef instanceof IPath) {
        fieldName = ((IPath) fieldRef).name();
      } else if (fieldRef instanceof String) {
        fieldName = (String) fieldRef;
      } else {
        throw new ModelException(
          'Invalid field type for aggregate function: ' + fieldRef
        );
      }

      // Generate alias: {fieldname}_{suffix}
      // Short suffixes: cnt, sum, avg, min, max, dis
      String suffix;
      if (funcName == 'COUNT') {
        suffix = 'cnt';
      } else if (funcName == 'COUNT_DISTINCT') {
        suffix = 'dis';
      } else {
        suffix = funcName.toLowerCase(); // sum, avg, min, max
      }

      return fieldName + '_' + suffix;
    }

    public Boolean equals(Object other) {
      if (other == null) {
        return false;
      }
      if (!(other instanceof IAggregateFunction)) {
        return false;
      }
      IAggregateFunction otherFunc = (IAggregateFunction) other;

      // Compare function names
      if (this.funcName != otherFunc.functionName()) {
        return false;
      }

      // Compare field references - use SOQL string representation for comparison
      String thisFieldSoql = this.toSoql();
      String otherFieldSoql = otherFunc.toSoql();
      if (thisFieldSoql != otherFieldSoql) {
        return false;
      }

      // Compare aliases (including auto-generated ones)
      return this.getAlias() == otherFunc.getAlias();
    }

    public Integer hashCode() {
      // Combine SOQL and alias for consistent hashing
      String combined = this.toSoql() + '|' + this.getAlias();
      return combined.hashCode();
    }

    public override String toString() {
      return this.toSoql();
    }
  }

  /**
   * StringPath - Simple string-based path for use when field describes are unavailable
   * (e.g., AggregateResult sources). Uses direct string field access via SObject.get().
   */
  public class StringPath implements IPath {
    private IModel sourceModel;
    private String fieldName;

    public StringPath(IModel source, String fieldName) {
      this.sourceModel = source;
      this.fieldName = fieldName;
    }

    public IModel source() {
      return sourceModel;
    }

    public List<SObjectField> fieldSequence() {
      return new List<SObjectField>(); // Empty for string-based paths
    }

    public Integer size() {
      return 1;
    }

    public String name() {
      return fieldName;
    }

    public String label() {
      return fieldName; // Fallback to field name when no describe available
    }

    public IReference reference() {
      return sourceModel;
    }

    public SObjectField terminus() {
      return null; // No field token available for string-based paths
    }

    public Object getFieldValue(SObject record) {
      return record?.get(fieldName);
    }

    public IReference toReference() {
      throw new PathException('StringPath cannot be converted to Reference');
    }

    public DescribeFieldResult describe() {
      return null; // No describe available for string-based paths
    }

    public Boolean equals(Object obj) {
      if (!(obj instanceof StringPath))
        return false;
      StringPath other = (StringPath) obj;
      return this.sourceModel == other.sourceModel &&
        this.fieldName == other.fieldName;
    }

    public Integer hashCode() {
      return (sourceModel.name() + ':' + fieldName).hashCode();
    }

    public override String toString() {
      return sourceModel.name() + ':' + fieldName;
    }
  }
}
