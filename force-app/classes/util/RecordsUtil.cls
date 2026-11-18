/**
 * Copies the populated fields of a template record onto records of the same type, and tracks the
 * records that changed in an IWork (optional). "Blanks only" fills fields that are null, or blank
 * text, and leaves everything else alone.
 */
global class RecordsUtil {
  global class GenericException extends Exception {
  }

  private static final Boolean ANY_VALUE = false;
  private static final Boolean BLANKS_ONLY = true;

  global static Boolean updateWhereDifferent(List<SObject> targets, SObject pattern, IWork work) {
    return applyTo(targets, pattern, work, ANY_VALUE);
  }

  global static Boolean updateWhereDifferent(SObject target, SObject pattern, IWork work) {
    return applyTo(new List<SObject>{ target }, pattern, work, ANY_VALUE);
  }

  global static Boolean updateWhereBlank(List<SObject> targets, SObject pattern, IWork work) {
    return applyTo(targets, pattern, work, BLANKS_ONLY);
  }

  global static Boolean updateWhereBlank(SObject target, SObject pattern, IWork work) {
    return applyTo(new List<SObject>{ target }, pattern, work, BLANKS_ONLY);
  }

  /** Returns true when at least one record changed. */
  global static Boolean doTemplatedUpdate(
    IModel model,
    List<SObject> targets,
    SObject pattern,
    IWork work,
    Boolean blanksOnly
  ) {
    if (model == null) {
      throw new GenericException('Cannot tell which SObject type the records are');
    }
    SObjectType patternType = pattern?.getSObjectType();
    if (model.token() != patternType) {
      throw new GenericException(
        'The template is ' + patternType + ' but the records are ' + model.token()
      );
    }
    Map<String, Object> incoming = pattern.getPopulatedFieldsAsMap();
    Integer changedCount = 0;
    for (SObject target : targets) {
      if (copyInto(target, incoming, blanksOnly == true)) {
        changedCount++;
        if (work != null) {
          work.track(target);
        }
      }
    }
    return changedCount > 0;
  }

  private static Boolean applyTo(
    List<SObject> targets,
    SObject pattern,
    IWork work,
    Boolean blanksOnly
  ) {
    IModel model = Application.s.model(targets);
    return doTemplatedUpdate(model, targets, pattern, work, blanksOnly);
  }

  private static Boolean copyInto(SObject target, Map<String, Object> incoming, Boolean blanksOnly) {
    Boolean touched = false;
    for (String field : incoming.keySet()) {
      Object current = target.get(field);
      Object replacement = incoming.get(field);
      if ((!blanksOnly || isBlank(current)) && current != replacement) {
        target.put(field, replacement);
        touched = true;
      }
    }
    return touched;
  }

  private static Boolean isBlank(Object value) {
    return value == null || (value instanceof String && String.isBlank((String) value));
  }
}
