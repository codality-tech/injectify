@IsTest
private class StringUtilTest {
  @IsTest
  static void equivalenceIgnoresCaseUnlessAskedNotTo() {
    Assert.isTrue(StringUtil.areEquivalent('Apple', 'aPPLE', false));
    Assert.isTrue(StringUtil.areEquivalent('Apple', 'aPPLE', null), 'null means case-insensitive');
    Assert.isFalse(StringUtil.areEquivalent('Apple', 'aPPLE', true));
    Assert.isTrue(StringUtil.areEquivalent('Apple', 'Apple', true));
  }

  @IsTest
  static void nullIsEquivalentToEmpty() {
    Assert.isTrue(StringUtil.areEquivalent(null, '', true));
    Assert.isTrue(StringUtil.areEquivalent(null, null, true));
    Assert.isFalse(StringUtil.areEquivalent(null, 'x', false));
  }

  @IsTest
  static void containsAnyFindsASingleOverlap() {
    List<String> fruit = new List<String>{ 'Apple', 'Pear' };

    Assert.isTrue(StringUtil.containsAny(fruit, new List<String>{ 'kiwi', 'PEAR' }, false));
    Assert.isFalse(StringUtil.containsAny(fruit, new List<String>{ 'kiwi', 'PEAR' }, true));
    Assert.isFalse(StringUtil.containsAny(fruit, new List<String>{ 'kiwi' }, false));
  }

  @IsTest
  static void containsAllNeedsEveryItem() {
    Set<String> fruit = new Set<String>{ 'Apple', 'Pear', 'Plum' };

    Assert.isTrue(StringUtil.containsAll(fruit, new Set<String>{ 'plum', 'apple' }, false));
    Assert.isFalse(StringUtil.containsAll(fruit, new Set<String>{ 'plum', 'apple' }, true));
    Assert.isFalse(StringUtil.containsAll(fruit, new Set<String>{ 'plum', 'kiwi' }, false));
  }

  @IsTest
  static void emptyOrMissingCollectionsNeverMatch() {
    List<String> some = new List<String>{ 'a' };
    List<String> none = new List<String>();

    for (Boolean caseSensitive : new List<Boolean>{ true, false }) {
      Assert.isFalse(StringUtil.containsAny(none, some, caseSensitive));
      Assert.isFalse(StringUtil.containsAny(some, none, caseSensitive));
      Assert.isFalse(StringUtil.containsAny(null, some, caseSensitive));
      Assert.isFalse(StringUtil.containsAny(some, null, caseSensitive));
      Assert.isFalse(StringUtil.containsAll(none, some, caseSensitive));
      Assert.isFalse(StringUtil.containsAll(some, none, caseSensitive));
      Assert.isFalse(StringUtil.containsAll(null, some, caseSensitive));
      Assert.isFalse(StringUtil.containsAll(some, null, caseSensitive));
    }
  }

  @IsTest
  static void nullItemsMatchEmptyItems() {
    List<String> withNull = new List<String>{ null, 'b' };

    Assert.isTrue(StringUtil.containsAny(withNull, new List<String>{ '' }, true));
    Assert.isTrue(StringUtil.containsAll(new List<String>{ '', 'B' }, withNull, false));
  }
}
