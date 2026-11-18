/**
 * Character sets used as number bases: convert text between bases, generate random strings, and
 * apply a per-position shift (a reversible scramble, not encryption).
 */
global class CharUtil {
  global interface ICharset {
    Integer getBase();
    String get(Integer position);
    Decimal toDecimal(String digits);
    String fromDecimal(Decimal value, Integer width);
    String convert(String digits, Integer width, ICharset target);
    Integer getPlaces(Decimal value);
    String generateRandom(Integer length);
    String shiftEncrypt(String text, List<Integer> offsets);
    String shiftDecrypt(String text, List<Integer> offsets);
  }

  private static final String DIGITS = '0123456789';
  private static final String LOWER = 'abcdefghijklmnopqrstuvwxyz';
  private static final String UPPER = LOWER.toUpperCase();

  global static final ICharset binary = new Charset('01');
  global static final ICharset numeric = new Charset(DIGITS);
  global static final ICharset lowerhex = new Charset(DIGITS + 'abcdef');
  global static final ICharset upperhex = new Charset(DIGITS + 'ABCDEF');
  global static final ICharset lowerdec = new Charset(DIGITS + LOWER);
  global static final ICharset upperdec = new Charset(DIGITS + UPPER);
  global static final ICharset alphadec = new Charset(DIGITS + LOWER + UPPER);
  global static final ICharset ascii = new Charset(asciiTable());

  global static ICharset charset(String chars) {
    return new Charset(chars);
  }

  // Codes 0 to 127. The null character comes from a literal: building it from code 0 loses it.
  private static String asciiTable() {
    Integer[] codes = new Integer[127];
    for (Integer code = 1; code < 128; code++) {
      codes[code - 1] = code;
    }
    return '\u0000' + String.fromCharArray(codes);
  }

  /** The characters, in order, are the digits of the base: the first is zero. */
  public class Charset implements ICharset {
    public String characters;
    private Integer base;

    public Charset(String characters) {
      Integer length = characters.length();
      if (new Set<String>(characters.split('')).size() != length) {
        throw new IllegalArgumentException('A charset cannot repeat a character: ' + characters);
      }
      this.characters = characters;
      base = length;
    }

    public Integer getBase() {
      return base;
    }

    public String get(Integer position) {
      return characters.substring(position, position + 1);
    }

    public Decimal toDecimal(String digits) {
      if (digits == null) {
        return null;
      }
      Decimal total = 0;
      for (Integer code : digits.getChars()) {
        total = total * base + digitOf(code);
      }
      return total;
    }

    /** The whole part of the value in this base, left-padded with the zero character to `width`. */
    public String fromDecimal(Decimal value, Integer width) {
      String digits = '';
      Decimal remaining = value.setScale(0, System.RoundingMode.DOWN);
      while (remaining > 0) {
        Decimal quotient = remaining.divide(base, 0, System.RoundingMode.DOWN);
        digits = get((remaining - quotient * base).intValue()) + digits;
        remaining = quotient;
      }
      return digits.leftPad(width, get(0));
    }

    public String convert(String digits, Integer width, ICharset target) {
      return target.fromDecimal(toDecimal(digits), width);
    }

    /** How many digits this base needs to write the value (fractions round up). */
    public Integer getPlaces(Decimal value) {
      Integer places = 0;
      Decimal remaining = value.setScale(0, System.RoundingMode.CEILING);
      while (remaining > 0) {
        remaining = remaining.divide(base, 0, System.RoundingMode.DOWN);
        places++;
      }
      return places;
    }

    public String generateRandom(Integer length) {
      String text = '';
      while (text.length() < length) {
        text += get(RandomUtil.getIntegerBetween(0, base - 1));
      }
      return text;
    }

    public String shiftEncrypt(String text, List<Integer> offsets) {
      return shifted(text, offsets, 1);
    }

    public String shiftDecrypt(String text, List<Integer> offsets) {
      return shifted(text, offsets, -1);
    }

    // Moves each character `direction * offset` places around the charset, wrapping both ways.
    private String shifted(String text, List<Integer> offsets, Integer direction) {
      List<Integer> codes = text.getChars();
      if (offsets.size() < codes.size()) {
        throw new IllegalArgumentException(
          'Need an offset per character: ' + offsets.size() + ' for ' + codes.size()
        );
      }
      Integer[] moved = new Integer[codes.size()];
      for (Integer at = 0; at < codes.size(); at++) {
        Integer landing = Math.mod(digitOf(codes[at]) + direction * offsets[at], base);
        moved[at] = characters.charAt(landing < 0 ? landing + base : landing);
      }
      return String.fromCharArray(moved);
    }

    private Integer digitOf(Integer code) {
      Integer digit = characters.indexOfChar(code);
      if (digit < 0) {
        throw new IllegalArgumentException(
          'Not in this charset: ' + String.fromCharArray(new List<Integer>{ code })
        );
      }
      return digit;
    }
  }
}
