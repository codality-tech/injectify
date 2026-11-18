@IsTest
private class EnumsTest {
  @IsTest
  static void testComparatorEnum() {
    // Test that all Comparator enum values exist
    List<Enums.Comparator> comparators = Enums.Comparator.values();
    System.assert(
      comparators.contains(Enums.Comparator.EQ),
      'EQ should be present'
    );
    System.assert(
      comparators.contains(Enums.Comparator.NE),
      'NE should be present'
    );
    System.assert(
      comparators.contains(Enums.Comparator.GE),
      'GE should be present'
    );
    System.assert(
      comparators.contains(Enums.Comparator.LE),
      'LE should be present'
    );
    System.assert(
      comparators.contains(Enums.Comparator.GT),
      'GT should be present'
    );
    System.assert(
      comparators.contains(Enums.Comparator.LT),
      'LT should be present'
    );
    System.assert(
      comparators.contains(Enums.Comparator.LK),
      'LK should be present'
    );
    System.assert(
      comparators.contains(Enums.Comparator.IIN),
      'IIN should be present'
    );
    System.assert(
      comparators.contains(Enums.Comparator.NIN),
      'NIN should be present'
    );
    System.assert(
      comparators.contains(Enums.Comparator.INC),
      'INC should be present'
    );
    System.assert(
      comparators.contains(Enums.Comparator.EXC),
      'EXC should be present'
    );

    // Test enum size
    System.assertEquals(
      11,
      comparators.size(),
      'Should have 11 comparator values'
    );
  }

  @IsTest
  static void testCaptureModeEnum() {
    // Test that all CaptureMode enum values exist
    List<Enums.CaptureMode> captureModes = Enums.CaptureMode.values();
    System.assert(
      captureModes.contains(Enums.CaptureMode.RELEASE),
      'RELEASE should be present'
    );
    System.assert(
      captureModes.contains(Enums.CaptureMode.IGNORE),
      'IGNORE should be present'
    );
    System.assert(
      captureModes.contains(Enums.CaptureMode.SYNCHRONOUS),
      'SYNCHRONOUS should be present'
    );
    System.assert(
      captureModes.contains(Enums.CaptureMode.IMMEDIATE),
      'IMMEDIATE should be present'
    );
    System.assert(
      captureModes.contains(Enums.CaptureMode.PREPEND),
      'PREPEND should be present'
    );
    System.assert(
      captureModes.contains(Enums.CaptureMode.APPEND),
      'APPEND should be present'
    );

    // Test enum size
    System.assertEquals(
      6,
      captureModes.size(),
      'Should have 6 capture mode values'
    );
  }

  @IsTest
  static void testCollectiveEnum() {
    // Test that all Collective enum values exist
    List<Enums.Collective> collectives = Enums.Collective.values();
    System.assert(
      collectives.contains(Enums.Collective.ALIST),
      'ALIST should be present'
    );
    System.assert(
      collectives.contains(Enums.Collective.ASET),
      'ASET should be present'
    );
    System.assert(
      collectives.contains(Enums.Collective.SINGLE),
      'SINGLE should be present'
    );

    // Test enum size
    System.assertEquals(
      3,
      collectives.size(),
      'Should have 3 collective values'
    );
  }
}
