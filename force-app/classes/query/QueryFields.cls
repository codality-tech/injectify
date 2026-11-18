/**
 * The SELECT list of a query. Fields come from the source object, from objects reached through
 * lookups (Account.Owner.Name), and from the possible targets of polymorphic lookups, which are
 * written as TYPEOF clauses. The source's Id is always selected.
 */
public without sharing class QueryFields implements IQueryFields {
  private class GeneralException extends Exception {
  }

  private IModel source;
  private PathFields pathFields;
  private TypeofFields typeofFields;

  public QueryFields(SObjectType sobjectToken) {
    this(Application.s.model(sobjectToken));
  }

  public QueryFields(IModel source) {
    if (source == null) {
      throw new GeneralException('QueryFields needs a model: source must not be null');
    }
    this.source = source;
  }

  public static IQueryFields newInstance(SObjectType token) {
    return new QueryFields(token);
  }

  public static IQueryFields newInstance(String sobjectName) {
    return new QueryFields(new Core().model(sobjectName).token());
  }

  public IModel source() {
    return source;
  }

  private PathFields pathFields() {
    if (pathFields == null) {
      pathFields = new PathFields(source);
    }
    return pathFields;
  }

  private TypeofFields typeofFields() {
    if (typeofFields == null) {
      typeofFields = new TypeofFields(source);
    }
    return typeofFields;
  }

  public String toSoql() {
    List<String> sections = new List<String>();
    for (String section : new List<String>{ pathFields().toSoql(), typeofFields().toSoql() }) {
      if (String.isNotBlank(section)) {
        sections.add(section);
      }
    }
    return sections.isEmpty() ? 'Id' : String.join(sections, ', ');
  }

  /** The SELECT list without the given fields of the source object. Id always stays. */
  public String toSoqlWithout(Set<SObjectField> leftOut) {
    List<String> sections = new List<String>();
    for (String section : new List<String>{ pathFields().render(leftOut), typeofFields().toSoql() }) {
      if (String.isNotBlank(section)) {
        sections.add(section);
      }
    }
    return String.join(sections, ', ');
  }

  public IQueryFields clearFields() {
    pathFields = null;
    typeofFields = null;
    return this;
  }

  /** The lookup paths that fields were added through, polymorphic ones included. */
  public Set<IPath> getRoutes() {
    Set<IPath> routes = new Set<IPath>();
    for (IReference via : pathFields().selections.keySet()) {
      if (via instanceof IPath) {
        routes.add((IPath) via);
      }
    }
    routes.addAll(typeofFields().byPath.keySet());
    return routes;
  }

  public Map<IReference, Set<SObjectField>> getFieldsByReference() {
    return pathFields().fieldsByReference();
  }

  private IPath resolve(Object route) {
    return source.path(route, true, true);
  }

  // The object types a lookup can point at; a path that is not a lookup throws.
  private static List<SObjectType> targetsOf(IPath lookupPath) {
    List<SObjectType> targets = lookupPath.describe().getReferenceTo();
    if (targets == null || targets.isEmpty()) {
      throw new GeneralException(lookupPath + ' is not a foreign key');
    }
    return targets;
  }

  // A selection of the model's fields, checked to belong to it.
  private static ModelFields checked(IModel model, Set<SObjectField> fields) {
    ModelFields selection = new ModelFields(model);
    selection.addFields(fields, false);
    return selection;
  }

  private static ModelFields everything(IModel model) {
    ModelFields selection = new ModelFields(model);
    selection.addAllFields();
    return selection;
  }

  // Field tokens

  public IQueryFields add(Set<SObjectField> fields) {
    return addTokens(null, fields);
  }

  /** Fields of the object(s) the route leads to; for a polymorphic lookup, of any of its targets. */
  public IQueryFields add(Object route, Set<SObjectField> fields) {
    return addTokens(resolve(route), fields);
  }

  private IQueryFields addTokens(IPath via, Set<SObjectField> fields) {
    if (fields == null || fields.isEmpty()) {
      return this;
    }
    if (via == null) {
      pathFields().take(source, checked(source, fields));
      return this;
    }
    List<SObjectType> targets = targetsOf(via);
    if (targets.size() == 1) {
      IReference ref = via.toReference();
      pathFields().take(ref, checked(ref.target(), fields));
      return this;
    }
    // Only the targets that received a field get a WHEN branch.
    Map<SObjectType, ModelFields> byTarget = ModelFields.siftFieldsIntoAnchors(fields, new Set<SObjectType>(targets));
    for (ModelFields bucket : byTarget.values()) {
      if (!bucket.getFields().isEmpty()) {
        typeofFields().take(via, bucket);
      }
    }
    return this;
  }

  // Other QueryFields

  public IQueryFields add(IQueryFields fields) {
    return graft(null, fields);
  }

  /** Another selection, made from the object the route leads to, moved under the route. */
  public IQueryFields add(Object route, IQueryFields fields) {
    return graft(resolve(route), fields);
  }

  private IQueryFields graft(IPath via, IQueryFields incoming) {
    QueryFields other = (QueryFields) incoming;
    if (via == null) {
      pathFields().absorb(source, other.pathFields());
    } else if (targetsOf(via).size() == 1) {
      pathFields().absorb(via.toReference(), other.pathFields());
    } else {
      ModelFields ownFields = other.pathFields().selections.get(other.source);
      if (ownFields != null) {
        typeofFields().take(via, ownFields);
      }
    }
    return this;
  }

  // Fields grouped by reference

  public IQueryFields add(Map<IReference, Set<SObjectField>> fieldsByReference) {
    return addByReference(source, fieldsByReference);
  }

  public IQueryFields add(Object route, Map<IReference, Set<SObjectField>> fieldsByReference) {
    return addByReference(resolve(route).toReference(), fieldsByReference);
  }

  private IQueryFields addByReference(IReference via, Map<IReference, Set<SObjectField>> fieldsByReference) {
    if (via == null) {
      throw new GeneralException('A reference is required');
    }
    if (via.source() != source) {
      throw new GeneralException(via + ' does not start from ' + source);
    }
    if (fieldsByReference != null && !fieldsByReference.isEmpty()) {
      pathFields().absorb(via, new PathFields(fieldsByReference));
    }
    return this;
  }

  // Field names and paths

  public IQueryFields add(Set<String> fieldNames) {
    return doAdd(null, fieldNames);
  }

  public IQueryFields add(Object route, Set<String> fieldNames) {
    return doAdd(resolve(route), fieldNames);
  }

  /**
   * Field names or dotted paths, from the source or from where `via` leads. Unknown names are
   * skipped. A polymorphic lookup needs field tokens instead, since a name could fit any target.
   */
  public IQueryFields doAdd(IPath via, Set<String> fieldNames) {
    if (via == null) {
      pathFields().takeNames(fieldNames);
      return this;
    }
    if (targetsOf(via).size() > 1) {
      throw new GeneralException(via + ' polymorphic foreign key unsupported');
    }
    QueryFields across = new QueryFields(via.toReference().target());
    across.pathFields().takeNames(fieldNames);
    return graft(via, across);
  }

  public IQueryFields add(Set<IPath> fieldPaths) {
    pathFields().takePaths(fieldPaths);
    return this;
  }

  // Field scopes and everything

  public IQueryFields add(IFieldScope scope) {
    return addScope(null, scope);
  }

  public IQueryFields add(Object route, IFieldScope scope) {
    return addScope(resolve(route), scope);
  }

  private IQueryFields addScope(IPath via, IFieldScope scope) {
    if (scope == null) {
      return this;
    }
    IModel scoped = via == null ? source : via.toReference().target();
    return addTokens(via, scope.apply(scoped));
  }

  public IQueryFields addAll() {
    return addEvery(null);
  }

  public IQueryFields addAll(Object route) {
    return addEvery(resolve(route));
  }

  private IQueryFields addEvery(IPath via) {
    if (via == null) {
      pathFields().take(source, everything(source));
      return this;
    }
    List<SObjectType> targets = targetsOf(via);
    if (targets.size() == 1) {
      IReference ref = via.toReference();
      pathFields().take(ref, everything(ref.target()));
      return this;
    }
    for (IModel target : ((ILookupPath) via).targets()) {
      typeofFields().take(via, everything(target));
    }
    return this;
  }

  private static Map<IReference, Set<SObjectField>> groupByReference(Set<IPath> fieldPaths) {
    Map<IReference, Set<SObjectField>> grouped = new Map<IReference, Set<SObjectField>>();
    for (IPath fieldPath : fieldPaths) {
      IReference via = fieldPath.reference();
      if (!grouped.containsKey(via)) {
        grouped.put(via, new Set<SObjectField>());
      }
      grouped.get(via).add(fieldPath.terminus());
    }
    return grouped;
  }

  /*
   * Fields of the source and of objects reached through single-target lookups, keyed by the
   * reference that reaches them (the source model itself for its own fields). Written as Field
   * and Lookup__r.Field; the SOQL is kept until the selection changes.
   */
  private class PathFields {
    private IModel source;
    private Map<IReference, ModelFields> selections = new Map<IReference, ModelFields>();
    private String soql;

    private PathFields(IModel source) {
      this.source = source;
    }

    // From fields grouped by reference; every reference must start from the same object.
    private PathFields(Map<IReference, Set<SObjectField>> fieldsByReference) {
      if (fieldsByReference.isEmpty()) {
        throw new GeneralException('No fields were given');
      }
      for (IReference via : fieldsByReference.keySet()) {
        ModelFields incoming = checked(via.target(), fieldsByReference.get(via));
        if (source == null) {
          source = via.source();
        } else if (source != via.source()) {
          throw new GeneralException(via + ' does not start from ' + source);
        }
        take(via, incoming);
      }
    }

    private ModelFields selectionFor(IReference via) {
      ModelFields existing = selections.get(via);
      if (existing == null) {
        existing = new ModelFields(via.target());
        selections.put(via, existing);
      }
      return existing;
    }

    private void take(IReference via, ModelFields incoming) {
      if (selectionFor(via).addFields(incoming.getFields(), true)) {
        soql = null;
      }
    }

    // Another selection, starting where `via` ends, moved under `via`.
    private void absorb(IReference via, PathFields other) {
      if (via.source() != source) {
        throw new GeneralException(via + ' does not start from ' + source);
      }
      if (via.target() != other.source) {
        throw new GeneralException(via + ' does not lead to ' + other.source);
      }
      for (IReference tail : other.selections.keySet()) {
        take(via.getReference(tail), other.selections.get(tail));
      }
    }

    private void takeNames(Set<String> fieldNames) {
      Set<IPath> found = new Set<IPath>();
      for (String name : fieldNames) {
        IPath fieldPath = source.path(name);
        if (fieldPath != null) {
          found.add(fieldPath);
        }
      }
      takePaths(found);
    }

    private void takePaths(Set<IPath> fieldPaths) {
      Map<IReference, Set<SObjectField>> grouped = groupByReference(fieldPaths);
      if (!grouped.isEmpty()) {
        absorb(source, new PathFields(grouped));
      }
    }

    private Map<IReference, Set<SObjectField>> fieldsByReference() {
      Map<IReference, Set<SObjectField>> copy = new Map<IReference, Set<SObjectField>>();
      for (IReference via : selections.keySet()) {
        copy.put(via, selections.get(via).getFields());
      }
      return copy;
    }

    private String toSoql() {
      if (soql == null) {
        soql = render(null);
      }
      return soql;
    }

    // The source's Id comes first and is not repeated. `leftOut` names fields of the source
    // itself to skip; the same field reached through a lookup is another object's and stays.
    private String render(Set<SObjectField> leftOut) {
      SObjectField idField = source.fieldMap().get('Id');
      List<String> columns = new List<String>{ source.toSoql(idField) };
      for (IReference via : selections.keySet()) {
        for (SObjectField field : selections.get(via).getFields()) {
          Boolean ownField = via == source;
          if (ownField && (field == idField || (leftOut != null && leftOut.contains(field)))) {
            continue;
          }
          columns.add(via.toSoql(field));
        }
      }
      return String.join(columns, ', ');
    }
  }

  /*
   * Fields per target type of polymorphic lookups, written as
   * TYPEOF What WHEN Account THEN Id, Name WHEN Opportunity THEN Id, Amount END.
   */
  private class TypeofFields {
    private IModel source;
    private Map<IPath, Map<IModel, ModelFields>> byPath = new Map<IPath, Map<IModel, ModelFields>>();
    private String soql;

    private TypeofFields(IModel source) {
      this.source = source;
    }

    private void take(IPath lookupPath, ModelFields incoming) {
      if (lookupPath == null) {
        throw new GeneralException('A polymorphic lookup path is required');
      }
      if (lookupPath.reference().source() != source) {
        throw new GeneralException(lookupPath + ' does not start from ' + source);
      }
      if (incoming == null) {
        return;
      }
      if (lookupPath instanceof IReference || !(lookupPath instanceof ILookupPath)) {
        throw new GeneralException(lookupPath + ' is not a polymorphic lookup');
      }
      IModel target = incoming.source();
      if (!((ILookupPath) lookupPath).targets().contains(target)) {
        throw new GeneralException(lookupPath + ' cannot point at ' + target);
      }
      Map<IModel, ModelFields> byTarget = byPath.get(lookupPath);
      if (byTarget == null) {
        byTarget = new Map<IModel, ModelFields>();
        byPath.put(lookupPath, byTarget);
      }
      ModelFields current = byTarget.get(target);
      if (current == null) {
        current = new ModelFields(target);
        byTarget.put(target, current);
      }
      if (current.addFields(incoming.getFields(), true)) {
        soql = null;
      }
    }

    private String toSoql() {
      if (soql == null && !byPath.isEmpty()) {
        soql = render();
      }
      return soql;
    }

    // Each target's Id comes first and is not repeated.
    private String render() {
      List<String> clauses = new List<String>();
      for (IPath lookupPath : byPath.keySet()) {
        String whens = '';
        Map<IModel, ModelFields> byTarget = byPath.get(lookupPath);
        for (IModel target : byTarget.keySet()) {
          SObjectField idField = target.fieldMap().get('Id');
          List<String> names = new List<String>();
          if (idField != null) {
            names.add(String.valueOf(idField));
          }
          for (SObjectField field : byTarget.get(target).getFields()) {
            if (field != idField) {
              names.add(String.valueOf(field));
            }
          }
          if (!names.isEmpty()) {
            whens += ' WHEN ' + target + ' THEN ' + String.join(names, ', ');
          }
        }
        clauses.add('TYPEOF ' + lookupPath.describe().getRelationshipName() + whens + ' END');
      }
      return String.join(clauses, ', ');
    }
  }
}
