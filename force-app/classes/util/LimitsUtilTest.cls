@IsTest
private class LimitsUtilTest {
  private static final List<String> NAMES = new List<String>{
    'CPU Time',
    'Heap Size',
    'Query Count',
    'Query Rows',
    'DML Count',
    'DML Rows'
  };

  private static String lineFor(String text, String name) {
    for (String line : text.split('\n')) {
      if (line.startsWith(name + ':')) {
        return line;
      }
    }
    return null;
  }

  @IsTest
  static void aLimitReadsAsNamePercentAndCounts() {
    LimitsUtil.LimitItem item = new LimitsUtil.LimitItem('Widgets', 1, 4);

    Assert.areEqual('Widgets: 25.00% (1/4)', item.stringify());
  }

  @IsTest
  static void subtractingKeepsTheCeiling() {
    LimitsUtil.LimitItem before = new LimitsUtil.LimitItem('Widgets', 3, 10);
    LimitsUtil.LimitItem after = new LimitsUtil.LimitItem('Widgets', 8, 10);

    Assert.areEqual('Widgets: 50.00% (5/10)', after.getDelta(before).stringify());
  }

  @IsTest
  static void differentLimitsCannotBeSubtracted() {
    LimitsUtil.LimitItem widgets = new LimitsUtil.LimitItem('Widgets', 1, 10);
    LimitsUtil.LimitItem gadgets = new LimitsUtil.LimitItem('Gadgets', 1, 10);

    try {
      widgets.getDelta(gadgets);
      Assert.fail('mismatched limits must not subtract');
    } catch (LimitsUtil.AnyException expected) {
      Assert.isTrue(expected.getMessage().contains('Gadgets'));
    }
  }

  @IsTest
  static void theCurrentReadingListsEveryTrackedLimit() {
    String reading = LimitsUtil.stringify();

    String snapshot = new LimitsUtil.Snapshot().stringify();

    Assert.isTrue(reading.startsWith('\n'), 'one limit per line after a leading break');
    for (String name : NAMES) {
      Assert.isNotNull(lineFor(reading, name), name + ' missing from: ' + reading);
      Assert.isNotNull(lineFor(snapshot, name), name + ' missing from: ' + snapshot);
    }
  }

  @IsTest
  static void aDeltaShowsWhatTheWorkInBetweenUsed() {
    LimitsUtil.Snapshot before = new LimitsUtil.Snapshot();
    Integer accounts = [SELECT COUNT() FROM Account];
    Integer contacts = [SELECT COUNT() FROM Contact];
    LimitsUtil.Snapshot after = new LimitsUtil.Snapshot();

    String forward = after.getDelta(before).stringify();
    String backward = before.getDelta(after).toString();

    Integer queryLimit = Limits.getLimitQueries();
    String expected = 'Query Count: ' + (200.0 / queryLimit).setScale(2) + '% (2/' + queryLimit + ')';
    Assert.areEqual(expected, lineFor(forward, 'Query Count'));
    Assert.areEqual(expected, lineFor(backward, 'Query Count'), 'order of the two snapshots does not matter');
    Assert.areEqual('DML Count: 0.00% (0/' + Limits.getLimitDmlStatements() + ')', lineFor(forward, 'DML Count'));
  }
}
