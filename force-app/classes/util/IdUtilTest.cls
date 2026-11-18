@IsTest
private class IdUtilTest {
  private static IModel accounts = Application.s.model(Account.SObjectType);

  @IsTest
  static void fakeIdsAreWellFormedAndNeverRepeat() {
    List<Id> ids = IdUtil.generateIds(accounts, 5);
    ids.add(IdUtil.generateId(accounts));
    ids.add(IdUtil.generateId(Contact.SObjectType));

    Assert.areEqual(7, new Set<Id>(ids).size(), 'no repeats');
    for (Integer at = 0; at < 6; at++) {
      Assert.areEqual(Account.SObjectType, ids[at].getSObjectType());
    }
    Assert.areEqual(Contact.SObjectType, ids[6].getSObjectType());
  }

  @IsTest
  static void sharesItsSequenceWithRandomUtil() {
    Set<Id> issued = new Set<Id>();
    for (Integer round = 0; round < 5; round++) {
      issued.add(IdUtil.generateId(accounts));
      issued.add(RandomUtil.getIdUnique(Account.SObjectType));
    }

    Assert.areEqual(10, issued.size());
  }

  @IsTest
  static void idsBecomeEmptyRecordsGroupedByType() {
    Id accountId = IdUtil.generateId(accounts);
    Id contactId = IdUtil.generateId(Contact.SObjectType);

    Map<SObjectType, List<SObject>> grouped = IdUtil.toRecordsByToken(new Set<Id>{ accountId, contactId });

    Assert.areEqual(2, grouped.size());
    SObject account = grouped.get(Account.SObjectType)[0];
    Assert.areEqual(accountId, account.Id);
    Assert.areEqual(new Set<String>{ 'Id' }, account.getPopulatedFieldsAsMap().keySet());
    Assert.areEqual(contactId, grouped.get(Contact.SObjectType)[0].Id);
  }

  @IsTest
  static void recordsOfOneTypeOrMixedOnRequest() {
    Set<Id> sameType = new Set<Id>(IdUtil.generateIds(accounts, 2));
    Set<Id> mixedTypes = new Set<Id>{ IdUtil.generateId(accounts), IdUtil.generateId(Contact.SObjectType) };

    Assert.areEqual(2, IdUtil.toRecords(sameType, false).size());
    Assert.areEqual(2, IdUtil.toRecords(mixedTypes, true).size());
    Assert.areEqual(0, IdUtil.toRecords(new Set<Id>(), false).size(), 'nothing in, nothing out');
    try {
      IdUtil.toRecords(mixedTypes, false);
      Assert.fail('mixed types need mixed = true');
    } catch (Exception expected) {
      Assert.isTrue(expected.getMessage().contains('mixed'), expected.getMessage());
    }
  }

  @IsTest
  static void nullIdSetsGiveNull() {
    Assert.isNull(IdUtil.toRecordsByToken(null));
    Assert.isNull(IdUtil.toRecords(null, true));
  }

  @IsTest
  static void trackerReportsOnlyIdsItHasNotSeen() {
    List<Id> first = IdUtil.generateIds(accounts, 2);
    Id later = IdUtil.generateId(accounts);
    IdUtil.ITracker tracker = IdUtil.getTracker();

    Assert.areEqual(new Set<Id>(first), tracker.getNovelIds(first, null), 'all new; null means remember');
    Assert.areEqual(new Set<Id>{ later }, tracker.getNovelIds(new List<Id>{ first[0], later }, false));
    Assert.areEqual(new Set<Id>(first), tracker.getIds(), 'false means do not remember');
    Assert.areEqual(new Set<Id>{ later }, tracker.getNovelIds(new Set<Id>{ later }, true));
    Assert.isTrue(tracker.getNovelIds(new Set<Id>{ later }, true).isEmpty());
    Assert.isTrue(tracker.getNovelIds((List<Id>) null, true).isEmpty());
  }

  @IsTest
  static void recordUrlsPointAtThisOrgsLightningPage() {
    Id accountId = IdUtil.generateId(accounts);

    String link = IdUtil.getRecordUrl(accountId);

    Assert.areEqual(
      URL.getOrgDomainUrl().toExternalForm() + '/lightning/r/Account/' + accountId + '/view',
      link
    );
    Assert.isNull(IdUtil.getRecordUrl(null));
  }

  @IsTest
  static void validIdsMustMatchTheModelsType() {
    Id accountId = IdUtil.generateId(accounts);
    String shortForm = String.valueOf(accountId).left(15);

    Assert.isTrue(IdUtil.isValidId(accountId, accounts));
    Assert.isTrue(IdUtil.isValidId(shortForm, accounts), '15 characters are fine');
    Assert.isFalse(IdUtil.isValidId(IdUtil.generateId(Contact.SObjectType), accounts));
    Assert.isFalse(IdUtil.isValidId('not an id', accounts));
    Assert.isFalse(IdUtil.isValidId(null, accounts));
    Assert.isFalse(IdUtil.isValidId(accountId, null));
  }
}
