@IsTest
private class PersistentTest {
  @IsTest
  static void namespacesStoreReadAndForget() {
    for (String prefix : new List<String>{ '', 'p1', 'o__o' }) {
      Persistent.INamespace space = Persistent.getNamespace(prefix);
      Assert.areEqual(prefix, space.prefix());
      Assert.isTrue(space.getAll().isEmpty());

      space.putAll(new Map<String, Object>{ 'a' => 'apple', 'b' => 'banana', 'c' => 'cherry' });
      space.put('d', 'date');

      Assert.areEqual(new Set<String>{ 'a', 'b', 'c', 'd' }, space.keySet());
      Assert.areEqual('banana', space.get('b'));
      Assert.areEqual(new Map<String, Object>{ 'a' => 'apple', 'z' => null }, space.getAll(new Set<String>{ 'a', 'z' }));

      space.remove('d');
      space.removeAll(new Set<String>{ 'b', 'c' });
      Assert.areEqual(new Map<String, Object>{ 'a' => 'apple' }, space.getAll());
      Assert.isTrue(space.containsKey('a'));
      Assert.isFalse(space.containsKey('b'));

      space.removeAll();
      Assert.isTrue(space.keySet().isEmpty(), prefix);
    }
  }

  @IsTest
  static void prefixesKeepKeysApart() {
    Persistent.getNamespace('').put('shared', 1);
    Persistent.getNamespace('left').put('shared', 2);
    Persistent.getNamespace('right').put('shared', 3);

    Assert.areEqual(1, Persistent.getNamespace(null).get('shared'), 'null is the blank prefix');
    Assert.areEqual(2, Persistent.getNamespace('left').get('shared'));
    Assert.areEqual(new Set<String>{ 'shared' }, Persistent.getNamespace('').keySet());
    Assert.areEqual(new Set<String>{ 'shared', 'left@shared', 'right@shared' }, Persistent.globalKeySet());

    Persistent.getNamespace('left').removeAll();
    Assert.areEqual(new Set<String>{ 'shared', 'right@shared' }, Persistent.globalKeySet());
  }

  @IsTest
  static void valuesReadBackAsTheirOwnType() {
    Map<String, Object> samples = new Map<String, Object>{
      'flag' => true,
      'recordId' => IdUtil.generateId(Account.SObjectType),
      'text' => 'hello',
      'day' => Date.newInstance(2026, 11, 10),
      'moment' => Datetime.newInstanceGmt(2026, 11, 10, 8, 30, 15),
      'clock' => Time.newInstance(8, 30, 15, 250),
      'count' => 42,
      'big' => 9000000000L,
      'money' => 12.75
    };
    Persistent.INamespace space = Persistent.getNamespace('types');

    space.putAll(samples);

    for (String name : samples.keySet()) {
      Assert.areEqual(samples.get(name), space.get(name), name);
    }
    Assert.isTrue(space.get('count') instanceof Integer);
    Assert.isTrue(space.get('recordId') instanceof Id);
  }

  @IsTest
  static void overwritingReplacesTheStoredValue() {
    Persistent.INamespace space = Persistent.getNamespace('counter');

    space.put('n', 1);
    space.put('n', 'one');

    Assert.areEqual('one', space.get('n'));
    Assert.areEqual(1, Persistent.globalKeySet().size());
  }

  @IsTest
  static void unsupportedOrOversizedValuesAreRejected() {
    Persistent.INamespace space = Persistent.getNamespace('');
    List<Object> rejected = new List<Object>{ new Account(), 'x'.repeat(300) };

    for (Object value : rejected) {
      try {
        space.put('v', value);
        Assert.fail('stored ' + value);
      } catch (Persistent.RuntimeException expected) {
        Assert.isFalse(space.containsKey('v'));
      }
    }
  }

  @IsTest
  static void malformedKeysAreRejected() {
    Assert.isNull(Persistent.getNamespace('has space'));
    Assert.areEqual('p@k', Persistent.buildGlobalKey('p', 'k', true));
    Assert.areEqual('k', Persistent.buildGlobalKey(null, 'k', true));
    Assert.areEqual('p@bad key', Persistent.buildGlobalKey('p', 'bad key', false), 'unchecked');

    List<String> badKeys = new List<String>{ 'bad key', 'a@b', null, 'k'.repeat(37) };
    Persistent.INamespace space = Persistent.getNamespace('p');
    for (String key : badKeys) {
      try {
        space.put(key, 1);
        Assert.fail('accepted ' + key);
      } catch (Persistent.RuntimeException expected) {
        Assert.isTrue(expected.getMessage().startsWith('Not a usable key'), expected.getMessage());
      }
    }
  }

  @IsTest
  static void globalAccessSpansEveryPrefix() {
    Map<String, Object> everything = new Map<String, Object>{ 'top' => 1, 'one@a' => 2, 'two@a' => 3 };

    Persistent.globalPutAll(everything);

    Assert.areEqual(everything, Persistent.globalGetAll());
    Assert.areEqual(new Map<String, Object>{ 'a' => 2 }, Persistent.getNamespace('one').getAll());

    Persistent.globalRemoveAll(everything.keySet());
    Assert.isTrue(Persistent.globalGetAll().isEmpty());
  }

  @IsTest
  static void globalWritesValidateButRemovalDoesNot() {
    Map<String, Object> malformed = new Map<String, Object>{ '##$%' => '*', '#@#' => 'f' };
    try {
      Persistent.globalPutAll(malformed);
      Assert.fail('malformed keys');
    } catch (Persistent.RuntimeException expected) {
      Assert.isTrue(Persistent.globalKeySet().isEmpty());
    }

    Persistent.store(malformed);
    Assert.areEqual(malformed.keySet(), Persistent.globalKeySet());

    Persistent.globalRemoveAll(malformed.keySet());
    Assert.isTrue(Persistent.globalKeySet().isEmpty());
  }
}
