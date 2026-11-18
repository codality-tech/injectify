@IsTest
private class TandemSortingUtilTest {
  @IsTest
  static void companionsFollowTheirKeys() {
    List<String> keys = new List<String>{ 'pear', 'apple', 'fig' };
    List<Object> prices = new List<Object>{ 3, 1, 2 };

    TandemSortingUtil.sort(prices, keys, true, true);

    Assert.areEqual(new List<String>{ 'apple', 'fig', 'pear' }, keys);
    Assert.areEqual(new List<Object>{ 1, 2, 3 }, prices);
  }

  @IsTest
  static void eachKeyTypeSortsBothWays() {
    Datetime noon = Datetime.newInstanceGmt(2026, 1, 1, 12, 0, 0);
    List<List<Object>> inOrder = new List<List<Object>>{
      new List<Decimal>{ -2.5, 0, 7 },
      new List<Datetime>{ noon.addDays(-1), noon, noon.addSeconds(1) },
      new List<String>{ 'a', 'b', 'c' }
    };

    for (List<Object> sorted : inOrder) {
      List<Object> shuffled = sorted.clone();
      shuffled[0] = sorted[2];
      shuffled[1] = sorted[0];
      shuffled[2] = sorted[1];
      List<Object> labels = new List<Object>{ 'third', 'first', 'second' };

      sortTyped(labels, shuffled, true);
      Assert.areEqual(new List<Object>{ 'first', 'second', 'third' }, labels, 'ascending ' + sorted);
      Assert.areEqual(sorted, shuffled);

      sortTyped(labels, shuffled, false);
      Assert.areEqual(new List<Object>{ 'third', 'second', 'first' }, labels, 'descending ' + sorted);
    }
  }

  @IsTest
  static void equalKeysKeepTheirOrder() {
    List<Boolean> flags = new List<Boolean>{ true, false, true, false, true };
    List<Object> arrival = new List<Object>{ 1, 2, 3, 4, 5 };

    TandemSortingUtil.sort(arrival, flags, null, null);
    Assert.areEqual(new List<Object>{ 2, 4, 1, 3, 5 }, arrival, 'a null direction sorts ascending');

    flags = new List<Boolean>{ true, false, true, false, true };
    arrival = new List<Object>{ 1, 2, 3, 4, 5 };
    TandemSortingUtil.sort(arrival, flags, false, null);
    Assert.areEqual(new List<Object>{ 1, 3, 5, 2, 4 }, arrival);
  }

  @IsTest
  static void nullsGoToTheChosenEndInEitherDirection() {
    for (Boolean ascending : new List<Boolean>{ true, false }) {
      List<Decimal> atEnd = new List<Decimal>{ null, 5, 1, null };
      List<Decimal> atFront = atEnd.clone();
      Decimal lowest = 1;
      Decimal highest = 5;

      TandemSortingUtil.sort(null, atEnd, ascending, true);
      TandemSortingUtil.sort(null, atFront, ascending, false);

      Assert.areEqual(new List<Decimal>{ ascending ? lowest : highest, ascending ? highest : lowest, null, null }, atEnd);
      Assert.areEqual(new List<Decimal>{ null, null, ascending ? lowest : highest, ascending ? highest : lowest }, atFront);
    }
  }

  @IsTest
  static void recordsSortByAFieldOrALookupPath() {
    List<Account> parents = new List<Account>{ new Account(Name = 'Mid'), new Account(Name = 'Low') };
    List<Contact> people = new List<Contact>{
      new Contact(LastName = 'b', Account = parents[0], Birthdate = Date.newInstance(1990, 5, 1)),
      new Contact(LastName = 'c', Account = parents[1], Birthdate = null),
      new Contact(LastName = 'a', Birthdate = Date.newInstance(1980, 1, 1))
    };

    TandemSortingUtil.sort(people, Application.s.path(Contact.Birthdate), false, true);
    Assert.areEqual('bac', lastNames(people), 'newest first, unknown last');

    TandemSortingUtil.sort(
      people,
      Application.s.path(new List<SObjectField>{ Contact.AccountId, Account.Name }),
      true,
      false
    );
    Assert.areEqual('acb', lastNames(people), 'no account first, then by account name');
  }

  @IsTest
  static void integerFieldsCompareAsNumbers() {
    List<Account> firms = new List<Account>();
    for (Integer staff : new List<Integer>{ 9, 300, 3 }) {
      firms.add(new Account(NumberOfEmployees = staff));
    }

    TandemSortingUtil.sort(firms, Application.s.path(Account.NumberOfEmployees), true, true);

    Assert.areEqual(3, firms[0].NumberOfEmployees);
    Assert.areEqual(300, firms[2].NumberOfEmployees, 'by value, not as text');
  }

  @IsTest
  static void timeFieldsSortWithinTheDay() {
    List<BusinessHours> schedules = new List<BusinessHours>{
      new BusinessHours(Name = 'late', MondayStartTime = Time.newInstance(18, 30, 0, 0)),
      new BusinessHours(Name = 'early', MondayStartTime = Time.newInstance(7, 0, 0, 0))
    };

    TandemSortingUtil.sort(schedules, Application.s.path(BusinessHours.MondayStartTime), true, true);

    Assert.areEqual('early', schedules[0].Name);
  }

  @IsTest
  static void mismatchedOrUnorderableInputIsRejected() {
    try {
      TandemSortingUtil.sort(new List<Object>{ 1 }, new List<String>{ 'a', 'b' }, true, true);
      Assert.fail('the lengths differ');
    } catch (TandemSortingUtil.GeneralException expected) {
      Assert.isTrue(expected.getMessage().contains('2 keys but 1 companions'), expected.getMessage());
    }
    List<Attachment> files = new List<Attachment>{
      new Attachment(Body = Blob.valueOf('x')),
      new Attachment(Body = Blob.valueOf('y'))
    };
    try {
      TandemSortingUtil.sort(files, Application.s.path(Attachment.Body), true, true);
      Assert.fail('blobs have no order');
    } catch (TandemSortingUtil.GeneralException expected) {
      Assert.isTrue(expected.getMessage().startsWith('Cannot sort by'), expected.getMessage());
    }
  }

  @IsTest
  static void emptyOrMissingListsAreLeftAlone() {
    List<Object> untouched = new List<Object>{ 'x' };

    TandemSortingUtil.sort(untouched, (List<String>) null, true, true);
    TandemSortingUtil.sort(untouched, new List<String>(), true, true);
    TandemSortingUtil.sort((SObject[]) null, Application.s.path(Account.Name), true, true);

    Assert.areEqual(new List<Object>{ 'x' }, untouched);
  }

  // Calls the overload that matches the list's runtime type.
  private static void sortTyped(List<Object> labels, List<Object> keys, Boolean ascending) {
    if (keys instanceof List<Decimal>) {
      TandemSortingUtil.sort(labels, (List<Decimal>) keys, ascending, true);
    } else if (keys instanceof List<Datetime>) {
      TandemSortingUtil.sort(labels, (List<Datetime>) keys, ascending, true);
    } else {
      TandemSortingUtil.sort(labels, (List<String>) keys, ascending, true);
    }
  }

  private static String lastNames(List<Contact> people) {
    String joined = '';
    for (Contact person : people) {
      joined += person.LastName;
    }
    return joined;
  }
}
