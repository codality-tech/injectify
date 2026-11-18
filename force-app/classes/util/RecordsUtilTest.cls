@IsTest
private class RecordsUtilTest {
  @TestSetup
  static void accounts() {
    insert new List<Account>{
      new Account(Name = 'empty'),
      new Account(Name = 'partly filled', Industry = 'Retail', Description = '   '),
      new Account(Name = 'already set', Industry = 'Energy', Rating = 'Warm', Description = 'kept')
    };
  }

  private static Map<String, Account> byName() {
    Map<String, Account> accounts = new Map<String, Account>();
    for (Account record : [SELECT Name, Industry, Rating, Description FROM Account ORDER BY Name LIMIT 200]) {
      accounts.put(record.Name, record);
    }
    return accounts;
  }

  @IsTest
  static void differentValuesAreOverwrittenAndPersistedThroughWork() {
    List<Account> records = byName().values();
    IWork work = Application.s.work();

    Boolean changed = RecordsUtil.updateWhereDifferent(
      records,
      new Account(Industry = 'Energy', Rating = 'Hot'),
      work
    );
    work.apply();

    Assert.isTrue(changed);
    for (Account saved : byName().values()) {
      Assert.areEqual('Energy', saved.Industry, saved.Name);
      Assert.areEqual('Hot', saved.Rating, saved.Name);
    }
  }

  @IsTest
  static void blanksOnlyFillsNullAndBlankText() {
    IWork work = Application.s.work();

    RecordsUtil.updateWhereBlank(
      byName().values(),
      new Account(Industry = 'Energy', Rating = 'Cold', Description = 'filled'),
      work
    );
    work.apply();

    Map<String, Account> saved = byName();
    Assert.areEqual('Energy', saved.get('empty').Industry);
    Assert.areEqual('Cold', saved.get('empty').Rating);
    Assert.areEqual('Retail', saved.get('partly filled').Industry, 'set values stay');
    Assert.areEqual('filled', saved.get('partly filled').Description, 'whitespace counts as blank');
    Assert.areEqual('Warm', saved.get('already set').Rating);
    Assert.areEqual('kept', saved.get('already set').Description);
  }

  @IsTest
  static void onlyChangedRecordsAreTracked() {
    Account already = byName().get('already set');
    IWork work = Application.s.work();

    Boolean changed = RecordsUtil.updateWhereDifferent(already, new Account(Industry = 'Energy'), work);
    Integer dmlBefore = Limits.getDmlStatements();
    work.apply();

    Assert.isFalse(changed);
    Assert.areEqual(dmlBefore, Limits.getDmlStatements(), 'nothing to save');
  }

  @IsTest
  static void singleRecordsWorkWithoutAUnitOfWork() {
    Account record = new Account(Name = 'in memory');

    Assert.isTrue(RecordsUtil.updateWhereBlank(record, new Account(Rating = 'Hot'), null));
    Assert.isTrue(RecordsUtil.updateWhereDifferent(record, new Account(Rating = 'Cold'), null));
    Assert.areEqual('Cold', record.Rating);
  }

  @IsTest
  static void aTemplateOfAnotherTypeIsRejected() {
    for (SObject template : new List<SObject>{ new Contact(LastName = 'x'), null }) {
      try {
        RecordsUtil.updateWhereDifferent(new Account(Name = 'a'), template, null);
        Assert.fail('accepted template ' + template);
      } catch (RecordsUtil.GenericException expected) {
        Assert.isTrue(expected.getMessage().contains('Account'), expected.getMessage());
      }
    }
  }

  @IsTest
  static void aMissingModelIsRejected() {
    try {
      RecordsUtil.doTemplatedUpdate(null, new List<Account>(), new Account(), null, false);
      Assert.fail('a model is required');
    } catch (RecordsUtil.GenericException expected) {
      Assert.isTrue(expected.getMessage().contains('SObject type'), expected.getMessage());
    }
  }
}
