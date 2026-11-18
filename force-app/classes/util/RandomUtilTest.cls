@IsTest
private class RandomUtilTest {
  private static void expectFailure(String label, Exception caught) {
    Assert.isNotNull(caught, label + ' should have failed');
    Assert.isTrue(caught instanceof RandomUtil.RuntimeException, label + ': ' + caught);
  }

  @IsTest
  static void integersBetweenStayInsideBothBounds() {
    Set<Integer> seen = new Set<Integer>();
    for (Integer draw = 0; draw < 200; draw++) {
      Integer value = RandomUtil.getIntegerBetween(-2, 2);
      Assert.isTrue(value >= -2 && value <= 2, String.valueOf(value));
      seen.add(value);
    }

    Assert.isTrue(seen.contains(-2) && seen.contains(2), 'both ends are reachable: ' + seen);
    Assert.areEqual(7, RandomUtil.getIntegerBetween(7, 7));
  }

  @IsTest
  static void boundsMustBePresentAndInOrder() {
    for (List<Integer> bounds : new List<List<Integer>>{ new List<Integer>{ null, 1 }, new List<Integer>{ 1, null }, new List<Integer>{ 5, 4 } }) {
      Exception caught;
      try {
        RandomUtil.getIntegerBetween(bounds[0], bounds[1]);
      } catch (Exception e) {
        caught = e;
      }
      expectFailure(String.valueOf(bounds), caught);
    }
  }

  @IsTest
  static void uniqueIntegersInARangeRunOutCleanly() {
    Set<Integer> drawn = new Set<Integer>();
    for (Integer draw = 0; draw < 3; draw++) {
      drawn.add(RandomUtil.getIntegerBetweenUnique(1, 3));
    }
    Assert.areEqual(new Set<Integer>{ 1, 2, 3 }, drawn);

    Exception caught;
    try {
      RandomUtil.getIntegerBetweenUnique(1, 3);
    } catch (Exception e) {
      caught = e;
    }
    expectFailure('exhausted range', caught);
  }

  @IsTest
  static void uniqueIntegersNeverRepeat() {
    Set<Integer> drawn = new Set<Integer>();
    for (Integer draw = 0; draw < 50; draw++) {
      drawn.add(RandomUtil.getIntegerUnique());
    }

    Assert.areEqual(50, drawn.size());
  }

  @IsTest
  static void otherIntegersHaveTheRightShape() {
    Assert.isTrue(RandomUtil.getCountingNumber() >= 0);
    Assert.isNotNull(RandomUtil.getInteger());
    Integer fourDigits = RandomUtil.getInteger(4);
    Assert.isTrue(fourDigits >= 0 && fourDigits < 10000, String.valueOf(fourDigits));
  }

  @IsTest
  static void listPicksComeFromTheList() {
    List<Object> options = new List<Object>{ 'a', 'b', 'c' };

    Assert.isTrue(options.contains(RandomUtil.getListItem(options)));
    Assert.isNull(RandomUtil.getListItem(new List<Object>()));
    Assert.isNull(RandomUtil.getListItem(null));
  }

  @IsTest
  static void stringsUseOnlyTheGivenCharacters() {
    String drawn = RandomUtil.getString(40, 'xy');

    Assert.areEqual(40, drawn.length());
    Assert.isTrue(drawn.containsOnly('xy'), drawn);
    Assert.isTrue(Pattern.matches('[A-Za-z0-9]{25}', RandomUtil.getString(25)));
  }

  @IsTest
  static void stringsNeedALengthAndCharacters() {
    for (Object[] arguments : new List<Object[]>{ new Object[]{ 0, 'ab' }, new Object[]{ null, 'ab' }, new Object[]{ 3, ' ' } }) {
      Exception caught;
      try {
        RandomUtil.getString((Integer) arguments[0], (String) arguments[1]);
      } catch (Exception e) {
        caught = e;
      }
      expectFailure(String.valueOf(arguments), caught);
    }
  }

  @IsTest
  static void decimalsHaveTheRequestedDigits() {
    Decimal whole = RandomUtil.getDecimal(3);
    Decimal fraction = RandomUtil.getDecimal(2, 3);

    Assert.isTrue(whole >= 0 && whole < 1000 && whole.scale() == 0, String.valueOf(whole));
    Assert.isTrue(fraction >= 0 && fraction < 100, String.valueOf(fraction));
    Assert.areEqual(3, fraction.scale());
  }

  @IsTest
  static void idsBelongToTheRequestedType() {
    Id randomId = RandomUtil.getId(Contact.SObjectType);
    Id first = RandomUtil.getIdUnique(Contact.SObjectType);
    Id second = RandomUtil.getIdUnique(Contact.SObjectType);

    Assert.areEqual(Contact.SObjectType, randomId.getSObjectType());
    Assert.areEqual(Contact.SObjectType, first.getSObjectType());
    Assert.areNotEqual(first, second);
  }
}
