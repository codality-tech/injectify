/**
 * Turns record Ids into UUID-shaped strings and back, so an Id can leave the org without showing
 * its key prefix or its place in the sequence. Given shifters, each digit is also moved by a
 * per-position offset: that obscures the value, but it is not encryption.
 *
 * The 36 characters read `ddddd pp b-bbbb-8bbb-8bbb-bbbbbbbbbbbb` (spaces added for clarity):
 *   b  the 15-character Id rewritten as 23 hex digits (62^15 needs 23; 22 fall short)
 *   p  the Id's last character as two hex digits; it picks the shifter, so it is never shifted
 *   d  the Id's 13th and 14th characters as five hex digits: filler that hides the pattern
 * The two literal 8s fill the version and variant positions of a version 8 UUID.
 */
global class UuidUtil {
  global enum CachingDirection {
    Unidirectional,
    Bidirectional
  }

  private static final CharUtil.ICharset HEX = CharUtil.lowerhex;
  private static final CharUtil.ICharset BASE62 = CharUtil.alphadec;
  private static final Integer BODY_WIDTH = 23;
  private static final Integer OFFSETS_NEEDED = BODY_WIDTH + 5;
  private static final Pattern WELL_FORMED = Pattern.compile('^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$');

  global class Converter {
    private List<List<Integer>> shifters;
    private CachingDirection caching;
    @TestVisible
    private Map<Id, String> uuidById = new Map<Id, String>();
    @TestVisible
    private Map<String, Id> idByUuid = new Map<String, Id>();

    /** Caches Id to UUID results. Pass null shifters to skip the shifting. */
    global Converter(List<List<Integer>> offsetTables) {
      this(CachingDirection.Unidirectional, offsetTables);
    }

    /**
     * A null `caching` turns the cache off. Each shifter needs at least 28 offsets; the
     * Id's last character decides which shifter a value uses.
     */
    global Converter(CachingDirection caching, List<List<Integer>> offsetTables) {
      if (offsetTables != null) {
        if (offsetTables.isEmpty()) {
          throw new IllegalArgumentException('Pass null for no shifting, or at least one shifter');
        }
        for (List<Integer> table : offsetTables) {
          if (table == null || table.size() < OFFSETS_NEEDED) {
            throw new IllegalArgumentException('Every shifter needs at least ' + OFFSETS_NEEDED + ' offsets');
          }
        }
      }
      this.caching = caching;
      shifters = offsetTables;
    }

    global List<String> fromRecordIds(Iterable<String> recordIds) {
      if (recordIds == null) {
        return null;
      }
      List<String> uuids = new List<String>();
      for (String each : recordIds) {
        uuids.add(fromRecordId(each));
      }
      return uuids;
    }

    /** The UUID for a record Id (15 or 18 characters). A UUID passes through; null gives null. */
    global String fromRecordId(String recordId) {
      if (recordId == null) {
        return null;
      }
      if (!(recordId instanceof Id)) {
        if (WELL_FORMED.matcher(recordId).matches()) {
          return recordId;
        }
        throw new IllegalArgumentException('Neither a record Id nor a UUID: ' + recordId);
      }
      Id key = (Id) recordId;
      String known = uuidById.get(key);
      if (known != null) {
        return known;
      }
      String uuid = encode(key.to15());
      remember(key, uuid);
      return uuid;
    }

    global List<String> toRecordIds(Iterable<String> uuids) {
      if (uuids == null) {
        return null;
      }
      List<String> recordIds = new List<String>();
      for (String each : uuids) {
        recordIds.add(toRecordId(each));
      }
      return recordIds;
    }

    /** The record Id for a UUID. A record Id passes through; null gives null. */
    global Id toRecordId(String uuid) {
      if (uuid == null) {
        return null;
      }
      if (uuid instanceof Id) {
        return (Id) uuid;
      }
      Id known = idByUuid.get(uuid);
      if (known != null) {
        return known;
      }
      if (!WELL_FORMED.matcher(uuid).matches()) {
        throw new IllegalArgumentException('Not a lowercase UUID: ' + uuid);
      }
      Id recordId = Id.valueOf(decode(uuid));
      remember(recordId, uuid);
      return recordId;
    }

    // Both directions fill the Id-keyed cache; only Bidirectional fills the UUID-keyed one.
    private void remember(Id recordId, String uuid) {
      if (caching == null) {
        return;
      }
      uuidById.put(recordId, uuid);
      if (caching == CachingDirection.Bidirectional) {
        idByUuid.put(uuid, recordId);
      }
    }

    private String encode(String id15) {
      String selector = BASE62.convert(id15.right(1), 2, HEX);
      String body = BASE62.convert(id15, BODY_WIDTH, HEX);
      String filler = BASE62.convert(id15.mid(12, 2), 5, HEX);
      List<Integer> offsets = offsetsFor(selector);
      if (offsets != null) {
        // One pass: the body takes offsets 0-22 and the filler, placed after it, takes 23-27.
        String moved = HEX.shiftEncrypt(body + filler, offsets);
        body = moved.left(BODY_WIDTH);
        filler = moved.substring(BODY_WIDTH, OFFSETS_NEEDED);
      }
      return String.join(
        new List<String>{
          filler + selector + body.left(1),
          body.mid(1, 4),
          '8' + body.mid(5, 3),
          '8' + body.mid(8, 3),
          body.substring(11)
        },
        '-'
      );
    }

    // Reads back only the selector and the body; the filler and the two 8s are ignored.
    private String decode(String uuid) {
      List<String> groups = uuid.split('-');
      String selector = groups[0].mid(5, 2);
      String body = groups[0].right(1) + groups[1] + groups[2].right(3) + groups[3].right(3) + groups[4];
      List<Integer> offsets = offsetsFor(selector);
      if (offsets != null) {
        body = HEX.shiftDecrypt(body, offsets);
      }
      return HEX.convert(body, 15, BASE62);
    }

    // The selector's two hex characters are read as base 62 digits (so "3d" is 199), then
    // wrapped by the number of shifters. Odd, but changing it would change every UUID.
    private List<Integer> offsetsFor(String selector) {
      if (shifters == null) {
        return null;
      }
      Integer position = BASE62.toDecimal(selector).intValue();
      return shifters[Math.mod(position, shifters.size())];
    }
  }
}
