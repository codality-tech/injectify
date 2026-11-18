/** Random values for test data: integers, strings, decimals, list picks and Ids. */
global class RandomUtil {
  global class RuntimeException extends Exception {
  }

  private static final String DIGITS = '0123456789';
  private static final String LETTERS = 'abcdefghijklmnopqrstuvwxyz';
  private static final String ALPHANUMERIC = LETTERS + LETTERS.toUpperCase() + DIGITS;

  // Values the *Unique methods have handed out in this transaction.
  private static Set<Integer> handedOut = new Set<Integer>();

  /** A random integer across the whole Integer range. */
  global static Integer getInteger() {
    Integer drawn = Crypto.getRandomInteger();
    return drawn;
  }

  /** A random integer not handed out before in this transaction. */
  global static Integer getIntegerUnique() {
    Integer candidate;
    do {
      candidate = getInteger();
    } while (handedOut.contains(candidate));
    handedOut.add(candidate);
    return candidate;
  }

  /** Inclusive of both bounds. */
  global static Integer getIntegerBetween(Integer min, Integer max) {
    if (min == null || max == null) {
      throw new RuntimeException('Both bounds are required, got ' + min + ' and ' + max);
    }
    if (min > max) {
      throw new RuntimeException('The lower bound ' + min + ' is above the upper bound ' + max);
    }
    Long span = (Long) max - min + 1;
    Double offset = Math.floor(Math.random() * span);
    return min + offset.intValue();
  }

  /** A random integer that is zero or positive. */
  global static Integer getCountingNumber() {
    Integer drawn = getInteger();
    return Math.abs(drawn);
  }

  /** A number made of `length` random digits (leading zeros allowed). */
  global static Integer getInteger(Integer length) {
    Decimal digits = getDecimal(length);
    return digits.intValue();
  }

  /** Inclusive of both bounds; never repeats, and fails once every value has been used. */
  global static Integer getIntegerBetweenUnique(Integer min, Integer max) {
    Integer candidate = getIntegerBetween(min, max);
    Long usedInRange = 0;
    for (Integer used : handedOut) {
      if (used >= min && used <= max) {
        usedInRange++;
      }
    }
    if (usedInRange > (Long) max - min) {
      throw new RuntimeException('Every value from ' + min + ' to ' + max + ' is used up');
    }
    while (handedOut.contains(candidate)) {
      candidate = getIntegerBetween(min, max);
    }
    handedOut.add(candidate);
    return candidate;
  }

  /** A random element, or null for a null or empty list. */
  global static Object getListItem(List<Object> options) {
    if (options == null || options.isEmpty()) {
      return null;
    }
    return options[getIntegerBetween(0, options.size() - 1)];
  }

  /** `length` characters drawn at random from `chars`. */
  global static String getString(Integer length, String chars) {
    if (length == null || length < 1) {
      throw new RuntimeException('Length must be at least 1, got ' + length);
    }
    if (String.isBlank(chars)) {
      throw new RuntimeException('Draw from at least one non-blank character');
    }
    Integer[] codes = new Integer[length];
    for (Integer at = 0; at < length; at++) {
      codes[at] = chars.charAt(getIntegerBetween(0, chars.length() - 1));
    }
    return String.fromCharArray(codes);
  }

  /** Letters of both cases and digits. */
  global static String getString(Integer length) {
    return getString(length, ALPHANUMERIC);
  }

  global static Decimal getDecimal(Integer length) {
    return getDecimal(length, 0);
  }

  /** `left` random digits before the point and `right` after it. */
  global static Decimal getDecimal(Integer left, Integer right) {
    String digits = getString(left, DIGITS);
    if (right != null && right > 0) {
      digits += '.' + getString(right, DIGITS);
    }
    return Decimal.valueOf(digits);
  }

  /** A random, well-formed Id of the type. Not guaranteed unique; see getIdUnique(). */
  global static Id getId(SObjectType token) {
    return Id.valueOf(token.getDescribe().getKeyPrefix() + '000' + getString(9));
  }

  /** Unique within the transaction; shares IdUtil's sequence so the two never collide. */
  global static Id getIdUnique(SObjectType token) {
    return IdUtil.generateId(token);
  }
}
