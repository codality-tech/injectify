/**
 * Record Id helpers: fake Ids for tests, empty records from Ids, a tracker that reports which Ids
 * are new, Lightning record URLs, and validity checks.
 */
global class IdUtil {
  private class IdException extends Exception {
  }

  /** One empty record per Id (only the Id is set), grouped by type. Null in, null out. */
  global static Map<SObjectType, List<SObject>> toRecordsByToken(Set<Id> ids) {
    return ids == null ? null : asEmptyRecords(ids);
  }

  /** Empty records for the Ids. Unless `mixed` is true, every Id must be of the same type. */
  global static List<SObject> toRecords(Set<Id> ids, Boolean mixed) {
    if (ids == null) {
      return null;
    }
    Map<SObjectType, List<SObject>> byType = asEmptyRecords(ids);
    if (mixed != true && byType.size() > 1) {
      throw new IdException(
        'These Ids span ' + byType.size() + ' SObject types; pass mixed = true to allow that'
      );
    }
    List<SObject> flattened = new List<SObject>();
    for (SObjectType kind : byType.keySet()) {
      flattened.addAll(byType.get(kind));
    }
    return flattened;
  }

  private static Map<SObjectType, List<SObject>> asEmptyRecords(Set<Id> ids) {
    Map<SObjectType, List<SObject>> byType = new Map<SObjectType, List<SObject>>();
    for (Id each : ids) {
      SObjectType kind = each?.getSObjectType();
      if (kind == null) {
        throw new IdException('Cannot tell the SObject type of Id ' + each);
      }
      List<SObject> bucket = byType.get(kind);
      if (bucket == null) {
        bucket = new List<SObject>();
        byType.put(kind, bucket);
      }
      bucket.add(kind.newSObject(each));
    }
    return byType;
  }

  // One sequence for every fake Id in the transaction (RandomUtil.getIdUnique shares it).
  private static Integer issued = 0;

  global static Id generateId(IModel model) {
    return generateId(model.token());
  }

  /** A well-formed fake Id: the type's key prefix followed by a 12-digit serial number. */
  global static Id generateId(SObjectType token) {
    issued++;
    String serial = String.valueOf(issued).leftPad(12, '0');
    return Id.valueOf(token.getDescribe().getKeyPrefix() + serial);
  }

  global static List<Id> generateIds(IModel model, Integer count) {
    List<Id> fresh = new List<Id>();
    while (fresh.size() < count) {
      fresh.add(generateId(model.token()));
    }
    return fresh;
  }

  /** The record's Lightning URL on this org's domain, or null for a null Id. */
  global static String getRecordUrl(Id target) {
    if (target == null) {
      return null;
    }
    String domain = URL.getOrgDomainUrl().toExternalForm();
    return domain + '/lightning/r/' + target.getSObjectType() + '/' + target + '/view';
  }

  /** True when the text is a well-formed Id of the model's SObject type. */
  global static Boolean isValidId(String recordId, IModel model) {
    if (String.isBlank(recordId) || model == null) {
      return false;
    }
    try {
      return Id.valueOf(recordId).getSObjectType() == model.token();
    } catch (Exception malformed) {
      return false;
    }
  }

  /** Remembers the Ids it has seen and reports which incoming Ids are new. */
  global interface ITracker {
    Set<Id> getNovelIds(Set<Id> candidates, Boolean remember);
    Set<Id> getNovelIds(List<Id> candidates, Boolean remember);
    Set<Id> getIds();
  }

  global static ITracker getTracker() {
    ITracker fresh = new Tracker();
    return fresh;
  }

  public class Tracker implements ITracker {
    private Set<Id> seen;

    private Tracker() {
      seen = new Set<Id>();
    }

    /** The candidates not seen before. Remembers them too, unless `remember` is false. */
    public Set<Id> getNovelIds(Set<Id> candidates, Boolean remember) {
      if (candidates == null) {
        return new Set<Id>();
      }
      Set<Id> novel = candidates.clone();
      novel.removeAll(seen);
      if (remember != false) {
        seen.addAll(candidates);
      }
      return novel;
    }

    public Set<Id> getNovelIds(List<Id> candidates, Boolean remember) {
      Set<Id> unique = new Set<Id>();
      if (candidates != null) {
        unique.addAll(candidates);
      }
      return getNovelIds(unique, remember);
    }

    /** Every Id remembered so far. */
    public Set<Id> getIds() {
      return seen;
    }
  }
}
