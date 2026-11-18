// The sample Ids are fixed inputs for golden UUID values, so they stay literal.
@SuppressWarnings('PMD.AvoidHardcodingId')
@IsTest
private class UuidUtilTest {
  private static final List<Integer> PI_DIGITS = new List<Integer>{
    3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 9, 3, 2, 3, 8, 4, 6, 2, 6, 4, 3, 3, 8, 3
  };
  private static final List<Integer> E_DIGITS = new List<Integer>{
    2, 7, 1, 8, 2, 8, 1, 8, 2, 8, 4, 5, 9, 0, 4, 5, 2, 3, 5, 3, 6, 0, 2, 8, 7, 4, 7, 1
  };
  private static final Id SAMPLE = Id.valueOf('001Aq00000xYz12');
  private static final Id LARGE = Id.valueOf('001000ZZZZZZZZZ');

  // Golden values from an independent model of the layout; they pin the format across releases.
  @IsTest
  static void producesTheDocumentedLayout() {
    UuidUtil.Converter plain = new UuidUtil.Converter(null, null);
    UuidUtil.Converter onePi = new UuidUtil.Converter(null, new List<List<Integer>>{ PI_DIGITS });
    UuidUtil.Converter piThenE = new UuidUtil.Converter(null, new List<List<Integer>>{ PI_DIGITS, E_DIGITS });

    Assert.areEqual('0087b020-0001-815a-81c4-a40d10fe11fc', plain.fromRecordId(SAMPLE));
    Assert.areEqual('00f033d0-0000-8aee-85a2-26d0c34a4dff', plain.fromRecordId(LARGE));
    Assert.areEqual('43bfe023-1416-8a70-86f9-2d7642265712', onePi.fromRecordId(SAMPLE));
    Assert.areEqual('43bfe023-1416-8a70-86f9-2d7642265712', piThenE.fromRecordId(SAMPLE), '"02" picks shifter 0');
    Assert.areEqual('873743d2-7182-82f6-8726-7fd4157f73f1', piThenE.fromRecordId(LARGE), '"3d" picks shifter 1');
  }

  @IsTest
  static void everyConfigurationRoundTrips() {
    List<List<Integer>> shifters = randomShifters(64);
    List<UuidUtil.Converter> converters = new List<UuidUtil.Converter>();
    for (List<List<Integer>> tables : new List<List<List<Integer>>>{ null, shifters }) {
      converters.add(new UuidUtil.Converter(null, tables));
      converters.add(new UuidUtil.Converter(UuidUtil.CachingDirection.Unidirectional, tables));
      converters.add(new UuidUtil.Converter(UuidUtil.CachingDirection.Bidirectional, tables));
    }
    List<Id> samples = new List<Id>{ SAMPLE, LARGE, Id.valueOf('001000000000000') };
    for (Integer n = 0; n < 20; n++) {
      samples.add(RandomUtil.getId(Account.SObjectType));
    }

    for (UuidUtil.Converter converter : converters) {
      List<String> uuids = converter.fromRecordIds(samples);
      Assert.areEqual(samples, converter.toRecordIds(uuids));
      Assert.areEqual(uuids, converter.fromRecordIds(converter.toRecordIds(uuids)), 'second pass, from cache');
    }
  }

  @IsTest
  static void outputIsAVersion8Uuid() {
    String uuid = new UuidUtil.Converter(randomShifters(3)).fromRecordId(RandomUtil.getId(Contact.SObjectType));

    Assert.isTrue(Pattern.matches('[0-9a-f]{8}-[0-9a-f]{4}-8[0-9a-f]{3}-8[0-9a-f]{3}-[0-9a-f]{12}', uuid), uuid);
  }

  @IsTest
  static void eighteenCharacterIdsMatchTheirShortForm() {
    UuidUtil.Converter converter = new UuidUtil.Converter(null, null);
    String longForm = String.valueOf(SAMPLE);

    Assert.areEqual(18, longForm.length());
    Assert.areEqual(converter.fromRecordId(longForm.left(15)), converter.fromRecordId(longForm));
  }

  @IsTest
  static void convertedValuesAndNullsPassThrough() {
    UuidUtil.Converter converter = new UuidUtil.Converter(randomShifters(1));
    String uuid = converter.fromRecordId(SAMPLE);

    Assert.areEqual(uuid, converter.fromRecordId(uuid));
    Assert.areEqual(SAMPLE, converter.toRecordId(SAMPLE));
    Assert.isNull(converter.fromRecordId(null));
    Assert.isNull(converter.toRecordId(null));
    Assert.isNull(converter.fromRecordIds(null));
    Assert.isNull(converter.toRecordIds(null));
  }

  @IsTest
  static void shiftingHidesTheIdButKeepsTheSelector() {
    String plain = new UuidUtil.Converter(null, null).fromRecordId(SAMPLE);
    String shifted = new UuidUtil.Converter(null, new List<List<Integer>>{ PI_DIGITS }).fromRecordId(SAMPLE);

    Assert.areNotEqual(plain, shifted);
    Assert.areEqual(plain.mid(5, 2), shifted.mid(5, 2));
  }

  @IsTest
  static void malformedInputIsRejected() {
    UuidUtil.Converter converter = new UuidUtil.Converter(null, null);
    Map<String, String> attempts = new Map<String, String>{
      'from: not an id' => 'Neither',
      'to: not-a-uuid' => 'Not a lowercase UUID',
      'to: gggggggg-gggg-8ggg-8ggg-gggggggggggg' => 'Not a lowercase UUID',
      'to: 0087B020-0001-815A-81C4-A40D10FE11FC' => 'Not a lowercase UUID'
    };

    for (String attempt : attempts.keySet()) {
      String input = attempt.substringAfter(': ');
      try {
        if (attempt.startsWith('from')) {
          converter.fromRecordId(input);
        } else {
          converter.toRecordId(input);
        }
        Assert.fail('accepted ' + input);
      } catch (IllegalArgumentException expected) {
        Assert.isTrue(expected.getMessage().startsWith(attempts.get(attempt)), expected.getMessage());
      }
    }
  }

  @IsTest
  static void shiftersMustBeLongEnough() {
    List<Integer> tooShort = PI_DIGITS.clone();
    tooShort.remove(0);
    List<List<List<Integer>>> rejected = new List<List<List<Integer>>>{
      new List<List<Integer>>(),
      new List<List<Integer>>{ tooShort },
      new List<List<Integer>>{ PI_DIGITS, null }
    };

    for (List<List<Integer>> tables : rejected) {
      try {
        new UuidUtil.Converter(tables);
        Assert.fail('accepted ' + tables);
      } catch (IllegalArgumentException expected) {
        Assert.isNotNull(expected.getMessage());
      }
    }
  }

  @IsTest
  static void cachingDirectionDecidesWhatIsKept() {
    Map<UuidUtil.CachingDirection, List<Integer>> expectedSizes = new Map<UuidUtil.CachingDirection, List<Integer>>{
      null => new List<Integer>{ 0, 0 },
      UuidUtil.CachingDirection.Unidirectional => new List<Integer>{ 2, 0 },
      UuidUtil.CachingDirection.Bidirectional => new List<Integer>{ 2, 2 }
    };
    String other = new UuidUtil.Converter(null, null).fromRecordId(LARGE);

    for (UuidUtil.CachingDirection direction : expectedSizes.keySet()) {
      UuidUtil.Converter converter = new UuidUtil.Converter(direction, null);
      converter.fromRecordId(SAMPLE);
      converter.toRecordId(other);

      List<Integer> sizes = expectedSizes.get(direction);
      Assert.areEqual(sizes[0], converter.uuidById.size(), 'by Id, ' + direction);
      Assert.areEqual(sizes[1], converter.idByUuid.size(), 'by UUID, ' + direction);
    }
  }

  private static List<List<Integer>> randomShifters(Integer count) {
    List<List<Integer>> tables = new List<List<Integer>>();
    while (tables.size() < count) {
      List<Integer> offsets = new List<Integer>();
      while (offsets.size() < 28) {
        offsets.add(RandomUtil.getIntegerBetween(0, 15));
      }
      tables.add(offsets);
    }
    return tables;
  }
}
