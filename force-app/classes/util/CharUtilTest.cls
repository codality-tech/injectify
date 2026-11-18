@IsTest
private class CharUtilTest {
  @IsTest
  static void convertsBetweenBases() {
    Assert.areEqual('1010', CharUtil.numeric.convert('10', 0, CharUtil.binary));
    Assert.areEqual('10', CharUtil.binary.convert('1010', 0, CharUtil.numeric));
    Assert.areEqual('ff', CharUtil.numeric.convert('255', 0, CharUtil.lowerhex));
    Assert.areEqual('00FF', CharUtil.lowerhex.convert('ff', 4, CharUtil.upperhex));
  }

  @IsTest
  static void largeValuesSurviveARoundTrip() {
    String fifteen = 'a1B2c3D4e5F6g7H';

    Decimal value = CharUtil.alphadec.toDecimal(fifteen);

    Assert.isTrue(value > 9223372036854775807L, 'beyond a Long');
    Assert.areEqual(fifteen, CharUtil.alphadec.fromDecimal(value, 15));
  }

  @IsTest
  static void fromDecimalPadsWithTheZeroCharacterAndDropsFractions() {
    Assert.areEqual('00042', CharUtil.numeric.fromDecimal(42, 5));
    Assert.areEqual('42', CharUtil.numeric.fromDecimal(42.9, 0));
    Assert.areEqual('000', CharUtil.numeric.fromDecimal(0, 3));
  }

  @IsTest
  static void placesCountTheDigitsNeeded() {
    Assert.areEqual(0, CharUtil.numeric.getPlaces(0));
    Assert.areEqual(1, CharUtil.numeric.getPlaces(9));
    Assert.areEqual(2, CharUtil.numeric.getPlaces(10));
    Assert.areEqual(2, CharUtil.numeric.getPlaces(9.5), 'fractions round up');
    Assert.areEqual(4, CharUtil.binary.getPlaces(8));
  }

  @IsTest
  static void toDecimalRejectsForeignCharactersAndPassesNull() {
    Assert.isNull(CharUtil.numeric.toDecimal(null));
    Assert.areEqual(0, CharUtil.numeric.toDecimal('').intValue());
    try {
      CharUtil.binary.toDecimal('102');
      Assert.fail('2 is not a binary digit');
    } catch (IllegalArgumentException expected) {
      Assert.isTrue(expected.getMessage().endsWith('2'), expected.getMessage());
    }
  }

  @IsTest
  static void customCharsetsMustNotRepeat() {
    CharUtil.ICharset abc = CharUtil.charset('abc');

    Assert.areEqual(3, abc.getBase());
    Assert.areEqual('b', abc.get(1));
    try {
      CharUtil.charset('abca');
      Assert.fail('a repeated character must be rejected');
    } catch (IllegalArgumentException expected) {
      Assert.isTrue(expected.getMessage().contains('abca'));
    }
  }

  @IsTest
  static void builtInCharsetsHaveTheExpectedBases() {
    Assert.areEqual(2, CharUtil.binary.getBase());
    Assert.areEqual(10, CharUtil.numeric.getBase());
    Assert.areEqual(16, CharUtil.lowerhex.getBase());
    Assert.areEqual(16, CharUtil.upperhex.getBase());
    Assert.areEqual(36, CharUtil.lowerdec.getBase());
    Assert.areEqual(36, CharUtil.upperdec.getBase());
    Assert.areEqual(62, CharUtil.alphadec.getBase());
    Assert.areEqual(128, CharUtil.ascii.getBase());
    Assert.areEqual('A', CharUtil.ascii.get(65));
  }

  @IsTest
  static void randomStringsUseTheCharset() {
    String drawn = CharUtil.lowerhex.generateRandom(30);

    Assert.areEqual(30, drawn.length());
    Assert.isTrue(drawn.containsOnly('0123456789abcdef'), drawn);
    Assert.areEqual('', CharUtil.lowerhex.generateRandom(0));
  }

  @IsTest
  static void shiftingIsReversibleForAnyOffsets() {
    List<Integer> offsets = new List<Integer>{ 1, 35, 36, 100, -7 };

    String scrambled = CharUtil.lowerdec.shiftEncrypt('hello', offsets);

    Assert.areNotEqual('hello', scrambled);
    Assert.areEqual('hello', CharUtil.lowerdec.shiftDecrypt(scrambled, offsets));
    Assert.areEqual('b', CharUtil.lowerdec.shiftEncrypt('a', new List<Integer>{ 1 }));
    Assert.areEqual('z', CharUtil.lowerdec.shiftDecrypt('0', new List<Integer>{ 1 }), 'wraps backwards');
  }

  @IsTest
  static void shiftingNeedsAnOffsetPerCharacter() {
    try {
      CharUtil.lowerdec.shiftEncrypt('abc', new List<Integer>{ 1 });
      Assert.fail('too few offsets');
    } catch (IllegalArgumentException expected) {
      Assert.isTrue(expected.getMessage().contains('1 for 3'), expected.getMessage());
    }
  }
}
