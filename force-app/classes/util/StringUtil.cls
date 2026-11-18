/**
 * String comparisons that treat null as an empty string. Case-insensitive unless caseSensitive is
 * true. (Apex's == on strings ignores case, so these compare folded values with equals().)
 */
global class StringUtil {
  global static Boolean areEquivalent(String first, String second, Boolean caseSensitive) {
    String folded = fold(first, caseSensitive);
    return folded.equals(fold(second, caseSensitive));
  }

  /** True when every item of `wanted` appears in `pool`. False if either is empty. */
  global static Boolean containsAll(
    Iterable<String> pool,
    Iterable<String> wanted,
    Boolean caseSensitive
  ) {
    Set<String> available = foldAll(pool, caseSensitive);
    Set<String> required = foldAll(wanted, caseSensitive);
    return !available.isEmpty() && !required.isEmpty() && available.containsAll(required);
  }

  /** True when at least one item of `wanted` appears in `pool`. False if either is empty. */
  global static Boolean containsAny(
    Iterable<String> pool,
    Iterable<String> wanted,
    Boolean caseSensitive
  ) {
    Set<String> overlap = foldAll(wanted, caseSensitive);
    overlap.retainAll(foldAll(pool, caseSensitive));
    return !overlap.isEmpty();
  }

  private static String fold(String value, Boolean caseSensitive) {
    if (value == null) {
      return '';
    }
    return caseSensitive == true ? value : value.toLowerCase();
  }

  private static Set<String> foldAll(Iterable<String> values, Boolean caseSensitive) {
    Set<String> folded = new Set<String>();
    if (values == null) {
      return folded;
    }
    Iterator<String> cursor = values.iterator();
    while (cursor.hasNext()) {
      folded.add(fold(cursor.next(), caseSensitive));
    }
    return folded;
  }
}
