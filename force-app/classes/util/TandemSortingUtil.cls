/**
 * Sorts a list of keys and moves a companion list in step, so the element at each position of the
 * companion still belongs with the key beside it. Both lists are reordered in place.
 *
 * Equal keys keep their original order. Nulls go to the end when `nullsAtEnd` is true and to the
 * front otherwise, whichever the direction. A null `ascending` sorts ascending. Strings compare
 * with Apex's own == and > operators.
 */
global class TandemSortingUtil {
  global class GeneralException extends Exception {
  }

  /** Sorts the records by the value at a path; the values may sit across lookups. */
  global static void sort(SObject[] records, IPath path, Boolean ascending, Boolean nullsAtEnd) {
    if (records == null) {
      return;
    }
    List<Object> keys = new List<Object>();
    for (SObject record : records) {
      keys.add(path.getFieldValue(record));
    }
    reorder(keys, records, ascending, nullsAtEnd);
  }

  global static void sort(List<Object> companions, List<String> keys, Boolean ascending, Boolean nullsAtEnd) {
    reorder(keys, companions, ascending, nullsAtEnd);
  }

  global static void sort(List<Object> companions, List<Decimal> keys, Boolean ascending, Boolean nullsAtEnd) {
    reorder(keys, companions, ascending, nullsAtEnd);
  }

  global static void sort(List<Object> companions, List<Datetime> keys, Boolean ascending, Boolean nullsAtEnd) {
    reorder(keys, companions, ascending, nullsAtEnd);
  }

  global static void sort(List<Object> companions, List<Boolean> keys, Boolean ascending, Boolean nullsAtEnd) {
    reorder(keys, companions, ascending, nullsAtEnd);
  }

  // Sorts the positions rather than the values, then lays both lists out in the new order.
  private static void reorder(List<Object> keys, List<Object> companions, Boolean ascending, Boolean nullsAtEnd) {
    if (keys == null || keys.isEmpty()) {
      return;
    }
    if (companions != null && companions.size() != keys.size()) {
      throw new GeneralException(
        'Cannot sort in tandem: ' + keys.size() + ' keys but ' + companions.size() + ' companions'
      );
    }
    List<Integer> order = new List<Integer>();
    for (Integer position = 0; position < keys.size(); position++) {
      order.add(position);
    }
    order.sort(new PositionComparator(keys, ascending != false, nullsAtEnd == true));
    rearrange(keys, order);
    if (companions != null) {
      rearrange(companions, order);
    }
  }

  private static void rearrange(List<Object> items, List<Integer> order) {
    List<Object> original = items.clone();
    for (Integer slot = 0; slot < order.size(); slot++) {
      items[slot] = original[order[slot]];
    }
  }

  private class PositionComparator implements System.Comparator<Integer> {
    private List<Object> keys;
    private Integer direction;
    private Integer nullSide;

    private PositionComparator(List<Object> keys, Boolean ascending, Boolean nullsAtEnd) {
      this.keys = keys;
      direction = ascending ? 1 : -1;
      nullSide = nullsAtEnd ? 1 : -1;
    }

    public Integer compare(Integer first, Integer second) {
      Object a = keys[first];
      Object b = keys[second];
      Integer verdict;
      if (a == null && b == null) {
        verdict = 0;
      } else if (a == null || b == null) {
        verdict = a == null ? nullSide : -nullSide;
      } else {
        verdict = direction * rank(a, b);
      }
      // The position breaks ties, which keeps the sort stable.
      return verdict == 0 ? first - second : verdict;
    }
  }

  private static Integer rank(Object a, Object b) {
    if (a instanceof String) {
      String x = (String) a;
      String y = (String) b;
      return x == y ? 0 : (x > y ? 1 : -1);
    }
    if (a instanceof Boolean) {
      return a == b ? 0 : ((Boolean) a ? 1 : -1);
    }
    // Dates land here too: Apex lets a Date pass as a Datetime at midnight.
    if (a instanceof Datetime) {
      return sign(((Datetime) a).getTime() - ((Datetime) b).getTime());
    }
    if (a instanceof Time) {
      return sign(millisOfDay((Time) a) - millisOfDay((Time) b));
    }
    if (a instanceof Decimal || a instanceof Integer || a instanceof Long || a instanceof Double) {
      Decimal x = Decimal.valueOf(String.valueOf(a));
      Decimal y = Decimal.valueOf(String.valueOf(b));
      return x == y ? 0 : (x > y ? 1 : -1);
    }
    throw new GeneralException('Cannot sort by a value like ' + a);
  }

  private static Integer sign(Long difference) {
    return difference == 0 ? 0 : (difference > 0 ? 1 : -1);
  }

  private static Long millisOfDay(Time moment) {
    return ((moment.hour() * 60L + moment.minute()) * 60 + moment.second()) * 1000 + moment.millisecond();
  }
}
