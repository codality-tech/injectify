/**
 * The fields selected from one object (its model), or all of them. Each add reports whether the
 * selection grew, so QueryFields knows when its SOQL has to be rebuilt.
 */
public class ModelFields {
  private class GeneralException extends Exception {
  }

  private Set<SObjectField> modelFieldSet;
  private Set<SObjectField> chosen = new Set<SObjectField>();
  private Boolean everyField = false;
  private IModel source;

  public ModelFields(SObjectType token) {
    this(Application.s.model(token));
  }

  public ModelFields(IModel model) {
    source = model;
  }

  public static ModelFields newInstance(SObjectType token) {
    return new ModelFields(token);
  }

  public Boolean isAllFields() {
    return everyField;
  }

  public IModel source() {
    IModel model = source;
    return model;
  }

  // Every field of the model, gathered on first use.
  private Set<SObjectField> fieldsOfModel() {
    if (modelFieldSet == null) {
      List<SObjectField> described = source?.fieldMap()?.values();
      modelFieldSet = new Set<SObjectField>(described ?? new List<SObjectField>());
    }
    return modelFieldSet;
  }

  /** The selected fields, or every field of the model once addAllFields has been called. */
  public Set<SObjectField> getFields() {
    return everyField ? fieldsOfModel() : chosen;
  }

  /** Selects every field from now on; true the first time. */
  public Boolean addAllFields() {
    Boolean changed = !everyField;
    everyField = true;
    return changed;
  }

  /**
   * True when the selection grew. Unless `trusted` is true, every field must belong to the model.
   * Does nothing once every field is selected.
   */
  public Boolean addFields(Set<SObjectField> additions, Boolean trusted) {
    if (everyField || additions == null) {
      return false;
    }
    if (trusted != true) {
      Set<SObjectField> foreign = additions.clone();
      foreign.removeAll(fieldsOfModel());
      if (!foreign.isEmpty()) {
        throw new GeneralException('Not fields of ' + source + ': ' + foreign);
      }
    }
    Integer sizeBefore = chosen.size();
    chosen.addAll(additions);
    return chosen.size() > sizeBefore;
  }

  public Boolean addFields(Set<SObjectField> additions) {
    return addFields(additions, false);
  }

  /** By API name; names that are not fields of the model are skipped. */
  public Boolean addFields(Set<String> names) {
    Map<String, SObjectField> byName = source.fieldMap();
    List<SObjectField> known = new List<SObjectField>();
    for (String name : names) {
      if (byName.containsKey(name)) {
        known.add(byName.get(name));
      }
    }
    return addFields(new Set<SObjectField>(known), true);
  }

  /** The fields of each named field set. Unknown sets, and members reached through a lookup, are skipped. */
  public Boolean addFieldSets(Set<String> setNames) {
    Boolean grew = false;
    Map<String, FieldSet> fieldSets = source.fieldSetMap();
    for (String setName : setNames ?? new Set<String>()) {
      List<String> memberNames = new List<String>();
      for (FieldSetMember member : fieldSets.containsKey(setName) ? fieldSets.get(setName).getFields() : new List<FieldSetMember>()) {
        memberNames.add(member.getFieldPath());
      }
      grew = addFields(new Set<String>(memberNames)) || grew;
    }
    return grew;
  }

  /** '*' when every field is selected; otherwise the selected names, comma separated. */
  public String toSoql() {
    if (everyField) {
      return '*';
    }
    String[] names = new String[0];
    for (SObjectField field : chosen) {
      names.add('' + field);
    }
    return String.join(names, ', ');
  }

  /**
   * Splits mixed fields by the object they belong to: one entry per type, holding that type's
   * fields. A field goes to the first type that has it; fields of none of the types are dropped.
   */
  public static Map<SObjectType, ModelFields> siftFieldsIntoAnchors(Set<SObjectField> mixed, Set<SObjectType> types) {
    Map<SObjectType, ModelFields> byType = new Map<SObjectType, ModelFields>();
    Set<SObjectField> unplaced = mixed?.clone();
    for (SObjectType token : unplaced == null ? new Set<SObjectType>() : types) {
      ModelFields bucket = newInstance(token);
      Set<SObjectField> belonging = unplaced.clone();
      belonging.retainAll(bucket.fieldsOfModel());
      unplaced.removeAll(belonging);
      bucket.addFields(belonging, true);
      byType.put(token, bucket);
    }
    return byType;
  }
}
