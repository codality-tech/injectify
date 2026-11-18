global class FieldScope {
  global enum Trait {
    ALL,
    CUSTOM,
    STANDARD,
    NAMESPACED,
    UNDERSIZE,
    OVERSIZE,
    FORMULA
  }

  // Static factory methods
  global static IFieldScope any(List<IFieldScope> scopes) {
    return new CombinatorialScope(true, scopes);
  }

  global static IFieldScope all(List<IFieldScope> scopes) {
    return new CombinatorialScope(false, scopes);
  }

  global static IFieldScope make(Trait trait) {
    return new TraitScope(trait);
  }

  global static IFieldScope make(String patt) {
    return new RegexScope(patt);
  }

  global static IFieldScope make(Schema.SOAPType st) {
    return new SOAPTypeScope(st);
  }

  global static IFieldScope make(DisplayType dt) {
    return new DisplayTypeScope(dt);
  }

  // Static helper methods
  private static Set<SObjectField> getUnion(List<Set<SObjectField>> fieldSets) {
    Set<SObjectField> result = new Set<SObjectField>();
    if (fieldSets == null) {
      return result;
    }
    for (Set<SObjectField> fieldSet : fieldSets) {
      if (fieldSet != null) {
        result.addAll(fieldSet);
      }
    }
    return result;
  }

  private static Set<SObjectField> getIntersect(
    List<Set<SObjectField>> fieldSets
  ) {
    if (fieldSets == null || fieldSets.isEmpty()) {
      return new Set<SObjectField>();
    }

    // Start with the first set
    Set<SObjectField> result = new Set<SObjectField>();
    if (fieldSets[0] != null) {
      result.addAll(fieldSets[0]);
    }

    // Intersect with each subsequent set
    for (Integer i = 1; i < fieldSets.size(); i++) {
      if (fieldSets[i] != null) {
        result.retainAll(fieldSets[i]);
      } else {
        return new Set<SObjectField>();
      }
    }

    return result;
  }

  private static Set<SObjectField> fieldsForTrait(Trait cat, IModel model) {
    if (model == null) {
      return new Set<SObjectField>();
    }

    Set<SObjectField> result = new Set<SObjectField>();
    Map<String, SObjectField> fieldMap = model.fieldMap();

    if (cat == Trait.ALL) {
      result.addAll(fieldMap.values());
      return result;
    }

    for (SObjectField field : fieldMap.values()) {
      if (fieldMatchesTrait(field, cat, model)) {
        result.add(field);
      }
    }

    return result;
  }

  private static Boolean fieldMatchesTrait(
    SObjectField field,
    Trait cat,
    IModel model
  ) {
    if (field == null) {
      return false;
    }

    DescribeFieldResult describe = model.scheme().getFieldDescribe(field);

    switch on cat {
      when ALL {
        return true;
      }
      when FORMULA {
        return describe.isCalculated();
      }
      when CUSTOM {
        return describe.isCustom();
      }
      when STANDARD {
        return !describe.isCustom();
      }
      when NAMESPACED {
        if (!describe.isCustom()) {
          return false;
        }
        String fieldName = describe.getName();
        if (!fieldName.contains('__')) {
          return false;
        }
        String beforeC = fieldName.substringBefore('__c');
        return beforeC.contains('__');
      }
      when OVERSIZE {
        return isLongText(describe);
      }
      when UNDERSIZE {
        return !isLongText(describe);
      }
      when else {
        return false;
      }
    }
  }

  private static Boolean isKeyField(SObjectField field) {
    String fieldName = String.valueOf(field);
    return fieldName == 'Id' || fieldName == 'Name';
  }

  private static Boolean isLongText(DescribeFieldResult describe) {
    return describe.getType() == DisplayType.TEXTAREA &&
      describe.getLength() > 255;
  }

  // Pattern cache for performance
  private static Map<String, Pattern> patternCache = new Map<String, Pattern>();

  private static Boolean matchesPattern(String fieldName, String regex) {
    try {
      Pattern compiledPattern = patternCache.get(regex);
      if (compiledPattern == null) {
        compiledPattern = Pattern.compile(regex);
        patternCache.put(regex, compiledPattern);
      }
      return compiledPattern.matcher(fieldName).matches();
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Error matching regex: ' + regex + ', Error: ' + e.getMessage()
      );
      return false;
    }
  }

  // Base scope implementation with exclusion support
  private abstract class BaseScope implements IFieldScope {
    private List<IFieldScope> excludes = new List<IFieldScope>();

    public IFieldScope exclude(IFieldScope scope) {
      if (scope != null) {
        this.excludes.add(scope);
      }
      return this;
    }

    public Set<SObjectField> apply(IModel model) {
      Set<SObjectField> result = doApply(model);

      // Apply exclusions
      for (IFieldScope exclusion : excludes) {
        Set<SObjectField> toRemove = exclusion.apply(model);
        result.removeAll(toRemove);
      }

      return result;
    }

    protected abstract Set<SObjectField> doApply(IModel model);
  }

  // Concrete implementations
  private class CombinatorialScope extends BaseScope {
    private Boolean isUnion;
    private List<IFieldScope> scopes;

    public CombinatorialScope(Boolean isUnion, List<IFieldScope> scopes) {
      this.isUnion = isUnion;
      this.scopes = scopes != null ? scopes : new List<IFieldScope>();
    }

    protected override Set<SObjectField> doApply(IModel model) {
      List<Set<SObjectField>> fieldSets = new List<Set<SObjectField>>();
      for (IFieldScope scope : scopes) {
        if (scope != null) {
          fieldSets.add(scope.apply(model));
        }
      }
      return isUnion ? getUnion(fieldSets) : getIntersect(fieldSets);
    }
  }

  private class RegexScope extends BaseScope {
    private String regex;

    public RegexScope(String regex) {
      this.regex = regex;
    }

    protected override Set<SObjectField> doApply(IModel model) {
      Set<SObjectField> result = new Set<SObjectField>();
      if (model == null || String.isBlank(regex)) {
        return result;
      }

      Map<String, SObjectField> fieldMap = model.fieldMap();
      for (SObjectField field : fieldMap.values()) {
        String fieldName = String.valueOf(field);
        if (matchesPattern(fieldName, regex)) {
          result.add(field);
        }
      }
      return result;
    }
  }

  private class TraitScope extends BaseScope {
    private Trait trait;

    public TraitScope(Trait trait) {
      this.trait = trait;
    }

    protected override Set<SObjectField> doApply(IModel model) {
      return fieldsForTrait(trait, model);
    }
  }

  private class SOAPTypeScope extends BaseScope {
    private Schema.SOAPType st;

    public SOAPTypeScope(Schema.SOAPType st) {
      this.st = st;
    }

    protected override Set<SObjectField> doApply(IModel model) {
      Set<SObjectField> result = new Set<SObjectField>();
      if (model == null || st == null) {
        return result;
      }

      Map<String, SObjectField> fieldMap = model.fieldMap();
      for (SObjectField field : fieldMap.values()) {
        DescribeFieldResult describe = model.scheme().getFieldDescribe(field);
        if (describe.getSOAPType() == st) {
          result.add(field);
        }
      }
      return result;
    }
  }

  private class DisplayTypeScope extends BaseScope {
    private DisplayType dt;

    public DisplayTypeScope(DisplayType dt) {
      this.dt = dt;
    }

    protected override Set<SObjectField> doApply(IModel model) {
      Set<SObjectField> result = new Set<SObjectField>();
      if (model == null || dt == null) {
        return result;
      }

      Map<String, SObjectField> fieldMap = model.fieldMap();
      for (SObjectField field : fieldMap.values()) {
        DescribeFieldResult describe = model.scheme().getFieldDescribe(field);
        if (describe.getType() == dt) {
          result.add(field);
        }
      }
      return result;
    }
  }
}
