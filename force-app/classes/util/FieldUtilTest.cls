@IsTest
private class FieldUtilTest {
  @IsTest
  static void cropKeepsOnlyTheNamedFields() {
    Account parent = new Account(Name = 'Acme', Industry = 'Energy');
    Contact person = new Contact(FirstName = 'Ada', LastName = 'Lovelace', Email = 'ada@example.com', Account = parent);

    SObject byToken = FieldUtil.crop(person, new Set<SObjectField>{ Contact.FirstName, Contact.Email });
    SObject byName = FieldUtil.crop(person, new Set<String>{ 'LastName', 'Account.Name' });

    Assert.areEqual(new Set<String>{ 'FirstName', 'Email' }, byToken.getPopulatedFieldsAsMap().keySet());
    Assert.areEqual(new Set<String>{ 'LastName', 'Account' }, byName.getPopulatedFieldsAsMap().keySet());
    SObject keptParent = byName.getSObject('Account');
    Assert.areEqual(new Set<String>{ 'Name' }, keptParent.getPopulatedFieldsAsMap().keySet(), 'Industry was not asked for');
    Assert.areEqual('Acme', keptParent.get('Name'));

    SObject orphan = FieldUtil.crop(new Contact(LastName = 'Solo'), new Set<String>{ 'Account.Name' });
    Assert.isTrue(orphan.getPopulatedFieldsAsMap().isEmpty(), 'nothing to follow');
  }

  @IsTest
  static void joinFillsGapsFromTheFallback() {
    Task dominant = new Task(Subject = 'Call back', Description = null);
    Task fallback = new Task(Subject = 'Ignored', Description = 'From the fallback', Priority = 'High');

    Task merged = (Task) FieldUtil.join(dominant, fallback);

    Assert.areEqual('Call back', merged.Subject);
    Assert.areEqual('From the fallback', merged.Description);
    Assert.areEqual('High', merged.Priority);
    Assert.areEqual(fallback, FieldUtil.join(null, fallback));
  }

  @IsTest
  static void mapJoinPrefersTheFirstNonNullValue() {
    Map<String, Object> first = new Map<String, Object>{ 'a' => 1, 'b' => null };
    Map<String, Object> second = new Map<String, Object>{ 'b' => 2, 'c' => 3, 'a' => 9 };

    Assert.areEqual(new Map<String, Object>{ 'a' => 1, 'b' => 2, 'c' => 3 }, FieldUtil.join(first, second));
    Assert.areEqual(second, FieldUtil.join(null, second));
    Assert.areEqual(first, FieldUtil.join(first, null));
    Assert.isTrue(FieldUtil.join((Map<String, Object>) null, null).isEmpty());
  }

  @IsTest
  static void blankFieldsAreNullOrWhitespace() {
    Contact person = new Contact(FirstName = 'Ada', LastName = null, Email = '  ');

    List<SObjectField> blank = FieldUtil.getBlankFields(
      person,
      new Set<SObjectField>{ Contact.FirstName, Contact.LastName, Contact.Email }
    );

    Assert.areEqual(new Set<SObjectField>{ Contact.LastName, Contact.Email }, new Set<SObjectField>(blank));
  }

  @IsTest
  static void catalogGroupsByTheFieldsText() {
    List<Account> firms = new List<Account>{
      new Account(Name = 'a', Industry = 'Energy'),
      new Account(Name = 'b'),
      new Account(Name = 'c', Industry = 'Energy'),
      new Account(Name = 'd')
    };

    Map<String, List<SObject>> groups = FieldUtil.catalog(firms, 'Industry');

    Assert.areEqual(new Set<String>{ 'Energy', '' }, groups.keySet());
    Assert.areEqual(2, groups.get('').size(), 'nulls group under the empty string');
    Assert.isTrue(FieldUtil.catalog(null, 'Industry').isEmpty());
  }

  @IsTest
  static void changedFindsRecordsThatDifferFromBefore() {
    List<Id> ids = IdUtil.generateIds(Application.s.model(Account.SObjectType), 3);
    List<Account> now = new List<Account>{
      new Account(Id = ids[0], Name = 'Renamed', Industry = 'Energy'),
      new Account(Id = ids[1], Name = 'Same', Industry = 'Energy'),
      new Account(Id = ids[2], Name = 'New')
    };
    Map<Id, SObject> before = new Map<Id, SObject>{
      ids[0] => new Account(Id = ids[0], Name = 'Original', Industry = 'Energy'),
      ids[1] => new Account(Id = ids[1], Name = 'Same', Industry = 'Energy')
    };

    List<SObject> byName = FieldUtil.changed(now, before, new List<String>{ 'Name' });
    List<SObject> byIndustry = FieldUtil.changed(now, before, new List<SObjectField>{ Account.Industry });

    Assert.areEqual(new List<SObject>{ now[0], now[2] }, byName, 'no previous version counts as changed');
    Assert.areEqual(new List<SObject>{ now[2] }, byIndustry);
  }

  @IsTest
  static void chunkSpreadsTextAcrossFields() {
    List<SObjectField> parts = new List<SObjectField>{ Contact.FirstName, Contact.LastName, Contact.Email };
    String digits = '';
    while (digits.length() < 125) {
      digits += String.valueOf(Math.mod(digits.length(), 10));
    }
    Contact person = new Contact();

    FieldUtil.chunk(person, parts, digits);
    Assert.areEqual(40, person.FirstName.length());
    Assert.areEqual(80, person.LastName.length());
    Assert.areEqual('01234', person.Email);
    Assert.areEqual(digits, person.FirstName + person.LastName + person.Email);

    FieldUtil.chunk(person, parts, 'short');
    Assert.areEqual('short', person.FirstName);
    Assert.isNull(person.LastName, 'leftover parts are cleared');
    Assert.isNull(person.Email);
  }

  @IsTest
  static void chunkChecksEveryFieldBeforeWriting() {
    Contact person = new Contact(FirstName = 'Kept');
    try {
      FieldUtil.chunk(person, new List<SObjectField>{ Contact.FirstName, Contact.Birthdate }, 'value');
      Assert.fail('Birthdate cannot hold text');
    } catch (FieldUtil.GeneralException expected) {
      Assert.isTrue(expected.getMessage().startsWith('Birthdate'), expected.getMessage());
    }
    Assert.areEqual('Kept', person.FirstName);

    Account firm = new Account(Name = 'Untouched');
    Assert.areEqual(firm, FieldUtil.chunk(firm, 'NoSuchField', 'value'), 'no numbered fields, nothing to do');
  }

  @IsTest
  static void csvGoesThroughCsvUtilBehindADataPrefix() {
    String prefix = 'data:text/csv;charset=utf-8,';
    List<Account> firms = new List<Account>{ new Account(Name = 'Acme "Inc"', Industry = 'Energy') };
    List<String> columns = new List<String>{ 'Name', 'Industry' };

    Assert.areEqual(prefix + '"Name","Industry"\n"Acme ""Inc""","Energy"', FieldUtil.toCSV(firms, columns, true));
    Assert.areEqual(prefix + '"Acme ""Inc""","Energy"', FieldUtil.toCSV(firms, columns, false));
    Assert.areEqual(new List<String>{ 'Name', 'Industry' }, columns, 'the caller\'s list is not touched');
  }

  @IsTest
  static void csvDefaultsToPopulatedFieldsAndFollowsPaths() {
    Contact person = new Contact(LastName = 'Doe', Account = new Account(Name = 'Acme'));
    Contact loner = new Contact(LastName = 'Roe');

    String everything = FieldUtil.toCSV(new List<Contact>{ person });
    String headless = FieldUtil.toCSV(new List<Contact>{ person }, false);
    String pathed = FieldUtil.toCSV(new List<Contact>{ person, loner }, new List<String>{ 'LastName', 'Account.Name' }, true);

    Assert.areEqual('data:text/csv;charset=utf-8,"LastName"\n"Doe"', everything, 'the related record is not a column');
    Assert.areEqual('data:text/csv;charset=utf-8,"Doe"', headless);
    Assert.areEqual('data:text/csv;charset=utf-8,"LastName","Account.Name"\n"Doe","Acme"\n"Roe",""', pathed);
  }

  @IsTest
  static void addressPartsTravelTogether() {
    Account firm = new Account(BillingStreet = '1 Main St', BillingCity = 'Springfield');

    Assert.isTrue(FieldUtil.addressIsBlank(firm, 'Billing', true), 'some parts are blank');
    Assert.isFalse(FieldUtil.addressIsBlank(firm, 'Billing', false), 'not every part is');
    Assert.isTrue(FieldUtil.addressIsBlank(firm, 'Shipping'));

    FieldUtil.copyAddress(firm, 'Billing', firm, 'Shipping');
    Assert.areEqual('1 Main St', firm.ShippingStreet);
    Assert.areEqual('Springfield', firm.ShippingCity);
    Assert.isNull(firm.ShippingCountry);
    Assert.areEqual(
      new Set<String>{ 'MailingStreet', 'MailingCity', 'MailingState', 'MailingPostalCode', 'MailingCountry' },
      FieldUtil.getAddressFieldNames('Mailing')
    );
  }

  @IsTest
  static void multiSelectValuesAreAddedAndRemoved() {
    Account firm = new Account(Description = 'red;green');

    Assert.isTrue(FieldUtil.pushMultipickValues(firm, Account.Description, new Set<String>{ 'blue', 'red', ' ' }));
    Assert.areEqual(new Set<String>{ 'red', 'green', 'blue' }, FieldUtil.getMultipickValues(firm, Account.Description));
    Assert.isFalse(FieldUtil.pushMultipickValues(firm, Account.Description, new Set<String>{ 'red' }), 'already there');
    Assert.isFalse(FieldUtil.pushMultipickValues(firm, Account.Description, null));

    Assert.isTrue(FieldUtil.clearMultipickValues(firm, Account.Description, new Set<String>{ 'red', 'purple' }));
    Assert.areEqual('green;blue', firm.Description);
    Assert.isFalse(FieldUtil.clearMultipickValues(firm, Account.Description, new Set<String>{ 'purple' }));
    Assert.isTrue(FieldUtil.getMultipickValues(new Account(), Account.Description).isEmpty());
  }

  @IsTest
  static void multiSelectNeedsARecordAndAField() {
    for (Integer attempt = 0; attempt < 2; attempt++) {
      try {
        FieldUtil.getMultipickValues(attempt == 0 ? null : new Account(), attempt == 0 ? Account.Name : null);
        Assert.fail('attempt ' + attempt);
      } catch (FieldUtil.GeneralException expected) {
        Assert.isTrue(expected.getMessage().startsWith('Both'), expected.getMessage());
      }
    }
  }

  @IsTest
  static void invalidSelectionsAreDropped() {
    String real = new List<String>(FieldUtil.getPicklistValues(Account.Industry))[0];
    Account firm = new Account(Industry = real + ';Not A Real Industry');

    Assert.isTrue(FieldUtil.clearInvalidMultipickValues(firm, Account.Industry));
    Assert.areEqual(real, firm.Industry);
    Assert.isFalse(FieldUtil.clearInvalidMultipickValues(firm, Account.Industry), 'nothing left to drop');
  }

  @IsTest
  static void dependentValuesFollowTheValidForBits() {
    List<FieldUtil.PicklistEntryWrapper> entries = new List<FieldUtil.PicklistEntryWrapper>{
      wrapper('x', 'gAAA'), // 100000...: the first controlling value
      wrapper('y', 'wAAA'), // 110000...: the first two
      wrapper('z', 'IAAA'), // 001000...: the third
      wrapper('w', 'BAAA') // 000001...: a sixth value that does not exist
    };

    Map<String, Set<String>> allowed = FieldUtil.groupByController(new List<String>{ 'US', 'CA', 'MX' }, entries);

    Assert.areEqual(
      new Map<String, Set<String>>{
        'US' => new Set<String>{ 'x', 'y' },
        'CA' => new Set<String>{ 'y' },
        'MX' => new Set<String>{ 'z' }
      },
      allowed
    );
    Assert.isTrue(FieldUtil.getDependentPicklistValues(Account.Industry).isEmpty(), 'Industry has no controller');
  }

  @IsTest
  static void picklistEntriesExposeTheirValues() {
    List<Schema.PicklistEntry> entries = Account.Industry.getDescribe().getPicklistValues();

    List<FieldUtil.PicklistEntryWrapper> wrapped = FieldUtil.readEntries(entries);

    Assert.areEqual(entries.size(), wrapped.size());
    Assert.areEqual(entries[0].getValue(), wrapped[0].value);
    Assert.areEqual(entries.size(), FieldUtil.getPicklistValues(Account.Industry).size());
  }

  @IsTest
  static void bitHelpers() {
    Assert.areEqual('100', FieldUtil.decimalToBinary(4));
    Assert.areEqual('10011', FieldUtil.decimalToBinary(19));
    Assert.areEqual('', FieldUtil.decimalToBinary(0));
    Assert.areEqual('', FieldUtil.decimalToBinary(-3));
    Assert.areEqual('', FieldUtil.decimalToBinary(null));

    Assert.areEqual('', FieldUtil.base64ToBits(null));
    Assert.areEqual('000000', FieldUtil.base64ToBits('A'));
    Assert.areEqual('011010', FieldUtil.base64ToBits('a'));
    Assert.areEqual('111111', FieldUtil.base64ToBits('/'));
    Assert.areEqual('100000000000000000000000', FieldUtil.base64ToBits('gA=='), 'padding reads as zeros');
  }

  // Text to values

  private static String refusal(SObjectField field, String text) {
    try {
      FieldUtil.fromText(field, text);
    } catch (FieldUtil.GeneralException refused) {
      return refused.getMessage();
    }
    return null;
  }

  @IsTest
  static void textIsTrimmedAndBlankTextIsNull() {
    Assert.areEqual('Acme, Inc', FieldUtil.fromText(Account.Name, '  Acme, Inc '));
    Assert.areEqual('a@b.example.com', FieldUtil.fromText(Contact.Email.getDescribe(), 'a@b.example.com'));
    Assert.isNull(FieldUtil.fromText(Account.Name, null));
    Assert.isNull(FieldUtil.fromText(Account.AnnualRevenue, '   '));
  }

  @IsTest
  static void aCheckboxReadsYesAndNoInSeveralSpellings() {
    for (String yes : new List<String>{ 'true', 'TRUE', 'Yes', 'y', '1' }) {
      Assert.areEqual(true, FieldUtil.fromText(Contact.DoNotCall, yes), yes);
    }
    for (String no : new List<String>{ 'false', 'No', 'N', '0' }) {
      Assert.areEqual(false, FieldUtil.fromText(Contact.DoNotCall, no), no);
    }
    Assert.areEqual('"maybe" is not yes or no', refusal(Contact.DoNotCall, 'maybe'));
  }

  @IsTest
  static void aNumberMayHaveASignADecimalPointAndThousandsSeparators() {
    Assert.areEqual(1234.5, FieldUtil.fromText(Account.AnnualRevenue, '1234.5'));
    Assert.areEqual(-1234.5, FieldUtil.fromText(Account.AnnualRevenue, '-1234.5'));
    Assert.areEqual(5.0, FieldUtil.fromText(Account.AnnualRevenue, '+5'));
    Assert.areEqual(0.5, FieldUtil.fromText(Account.AnnualRevenue, '.5'));
    Assert.areEqual(1234567.25, FieldUtil.fromText(Account.AnnualRevenue, '1,234,567.25'));
    Assert.areEqual(50.0, FieldUtil.fromText(Opportunity.Probability, '50 %'), 'a percent may say so');
  }

  @IsTest
  static void aCommaThatIsNotAThousandsSeparatorIsRefusedNotGuessedAt() {
    Assert.areEqual('"1,5" is not a number', refusal(Account.AnnualRevenue, '1,5'));
    Assert.areEqual('"12,34" is not a number', refusal(Account.AnnualRevenue, '12,34'));
    Assert.areEqual('"abc" is not a number', refusal(Account.AnnualRevenue, 'abc'));
    Assert.areEqual('"50%" is not a number', refusal(Account.AnnualRevenue, '50%'), 'only a percent field takes the sign');
    Assert.areEqual('"' + 'x'.repeat(37) + '..." is not a number', refusal(Account.AnnualRevenue, 'x'.repeat(100)), 'a long text is cut short');
  }

  @IsTest
  static void aWholeNumberFieldTakesWholeNumbers() {
    Assert.areEqual(1200, FieldUtil.fromText(Account.NumberOfEmployees, '1,200'));
    Assert.areEqual(12, FieldUtil.fromText(Account.NumberOfEmployees, '12.0'));
    Assert.isTrue(FieldUtil.fromText(Account.NumberOfEmployees, '12') instanceof Integer);
    Assert.areEqual('"12.5" is not a whole number this field can hold', refusal(Account.NumberOfEmployees, '12.5'));
    Assert.areEqual('"99999999999" is not a whole number this field can hold', refusal(Account.NumberOfEmployees, '99999999999'));
  }

  @IsTest
  static void aDateIsWrittenTheIsoWayOrTheWayOfTheUsersLocale() {
    Date day = Date.newInstance(2026, 1, 31);

    Assert.areEqual(day, FieldUtil.fromText(Contact.Birthdate, '2026-01-31'));
    Assert.areEqual(day, FieldUtil.fromText(Contact.Birthdate, day.format()));
    Assert.areEqual('"soon" is not a date; write it like 2026-01-31', refusal(Contact.Birthdate, 'soon'));
  }

  @IsTest
  static void aDateAndTimeIsReadInFourWays() {
    Datetime local = Datetime.newInstance(2026, 1, 31, 14, 30, 0);

    Assert.areEqual(Datetime.newInstanceGmt(2026, 1, 31, 14, 30, 0), FieldUtil.fromText(Account.CreatedDate, '2026-01-31T14:30:00Z'), 'with its own time zone');
    Assert.areEqual(local, FieldUtil.fromText(Account.CreatedDate, '2026-01-31 14:30'), 'in the time zone of the user');
    Assert.areEqual(local.addSeconds(15), FieldUtil.fromText(Account.CreatedDate, '2026-01-31 14:30:15'));
    Assert.areEqual(Datetime.newInstance(2026, 1, 31, 0, 0, 0), FieldUtil.fromText(Account.CreatedDate, '2026-01-31'), 'a date alone is its first moment');
    Assert.areEqual(local, FieldUtil.fromText(Account.CreatedDate, local.format()), 'the way their locale writes it');
    Assert.areEqual('"soon" is not a date and time; write it like 2026-01-31 14:30', refusal(Account.CreatedDate, 'soon'));
  }

  @IsTest
  static void aTimeIsHoursAndMinutesWithOrWithoutSeconds() {
    Assert.areEqual(Time.newInstance(14, 30, 0, 0), FieldUtil.fromText(BusinessHours.MondayStartTime, '14:30'));
    Assert.areEqual(Time.newInstance(9, 5, 15, 0), FieldUtil.fromText(BusinessHours.MondayStartTime, '9:05:15'));
    Assert.areEqual('"25:00" is not a time; write it like 14:30', refusal(BusinessHours.MondayStartTime, '25:00'));
    Assert.areEqual('"noon" is not a time; write it like 14:30', refusal(BusinessHours.MondayStartTime, 'noon'));
  }

  @IsTest
  static void aLookupTakesAnIdOfAnObjectItCanPointAt() {
    Id firm = IdUtil.generateId(Account.SObjectType);
    Id person = IdUtil.generateId(Contact.SObjectType);

    Assert.areEqual(firm, FieldUtil.fromText(Contact.AccountId, String.valueOf(firm)));
    Assert.areEqual(firm, FieldUtil.fromText(Contact.AccountId, String.valueOf(firm).left(15)), 'the short form of an Id will do');
    Assert.areEqual('"Acme" is not an Id', refusal(Contact.AccountId, 'Acme'));
    Assert.isTrue(refusal(Contact.AccountId, person).contains('is the Id of a Contact, which '), refusal(Contact.AccountId, person));
  }

  @IsTest
  static void aPicklistTakesAValueInAnyCaseAndPassesOnWhatItDoesNotKnow() {
    String known = Account.Industry.getDescribe().getPicklistValues()[0].getValue();

    Assert.areEqual(known, FieldUtil.fromText(Account.Industry, known.toUpperCase()));
    Assert.areEqual('Not On The List', FieldUtil.fromText(Account.Industry, 'Not On The List'), 'the org decides whether the field takes it');
  }

  @IsTest
  static void someFieldsCannotBeFilledFromText() {
    Assert.isFalse(FieldUtil.takesText(Account.BillingAddress.getDescribe()));
    Assert.isTrue(FieldUtil.takesText(Account.Name.getDescribe()));
  }

  private static FieldUtil.PicklistEntryWrapper wrapper(String value, String validFor) {
    FieldUtil.PicklistEntryWrapper entry = new FieldUtil.PicklistEntryWrapper();
    entry.value = value;
    entry.validFor = validFor;
    return entry;
  }
}
