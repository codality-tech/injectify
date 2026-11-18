@IsTest
private class CsvUtilTest {
  @IsTest
  static void mapsBecomeQuotedLinesInColumnOrder() {
    String csv = CsvUtil.toCsv(
      new List<String>{ 'b', 'a' },
      new List<Map<String, Object>>{
        new Map<String, Object>{ 'a' => 1, 'b' => 'two' },
        new Map<String, Object>{ 'a' => null }
      }
    );

    Assert.areEqual('"b","a"\n"two","1"\n"",""', csv);
  }

  @IsTest
  static void quotesCommasAndLineBreaksSurvive() {
    String csv = CsvUtil.toCsv(
      new List<String>{ 'note' },
      new List<Map<String, Object>>{
        new Map<String, Object>{ 'note' => 'say "hi", then\nleave' }
      }
    );

    Assert.areEqual('"note"\n"say ""hi"", then\nleave"', csv);
  }

  @IsTest
  static void recordColumnsCanFollowRelationships() {
    Account parent = new Account(Name = 'Acme');
    List<Contact> rows = new List<Contact>{
      new Contact(LastName = 'Ng', Account = parent),
      new Contact(LastName = 'Orphan')
    };

    String csv = CsvUtil.toCsv(new List<String>{ 'LastName', 'Account.Name' }, rows);

    Assert.areEqual('"LastName","Account.Name"\n"Ng","Acme"\n"Orphan",""', csv);
  }

  @IsTest
  static void labelledColumnsUseTheLabelsAsHeader() {
    Map<String, String> columns = new Map<String, String>{
      'Name' => 'Company',
      'NumberOfEmployees' => 'Staff'
    };

    String csv = CsvUtil.toCsv(columns, new List<Account>{ new Account(Name = 'Acme', NumberOfEmployees = 12) });

    Assert.areEqual('"Company","Staff"\n"Acme","12"', csv);
  }

  @IsTest
  static void labelsMayRepeatWithoutLosingColumns() {
    Map<String, String> columns = new Map<String, String>{ 'Name' => 'Value', 'Rating' => 'Value' };

    String csv = CsvUtil.toCsv(columns, new List<Account>{ new Account(Name = 'Acme', Rating = 'Hot') });

    Assert.areEqual('"Value","Value"\n"Acme","Hot"', csv);
  }

  @IsTest
  static void aBlankLabelIsRejected() {
    try {
      CsvUtil.toCsv(new Map<String, String>{ 'Name' => ' ' }, new List<Account>());
      Assert.fail('a blank label must be rejected');
    } catch (CsvUtil.GeneralException expected) {
      Assert.isTrue(expected.getMessage().contains('Name'));
    }
  }

  @IsTest
  static void noRowsGivesJustTheHeader() {
    Assert.areEqual('"Name"', CsvUtil.toCsv(new List<String>{ 'Name' }, new List<Account>()));
  }

  // Reading

  @IsTest
  static void aQuotedCellHoldsSeparatorsLineBreaksAndQuotes() {
    List<List<String>> rows = CsvUtil.rows('Name,Note\n"Acme, Inc","said ""hi""\nthere"\nPlain, spaced \n', ',');

    Assert.areEqual(3, rows.size());
    Assert.areEqual(new List<String>{ 'Name', 'Note' }, rows[0]);
    Assert.areEqual(new List<String>{ 'Acme, Inc', 'said "hi"\nthere' }, rows[1]);
    Assert.areEqual(new List<String>{ 'Plain', ' spaced ' }, rows[2], 'a cell is left as it was written');
  }

  @IsTest
  static void quotesAtTheEdgesOfACellAreRead() {
    List<List<String>> rows = CsvUtil.rows('"","a""","""","""b""",c\n', ',');

    Assert.areEqual(new List<String>{ '', 'a"', '"', '"b"', 'c' }, rows[0]);
  }

  @IsTest
  static void anyLineEndingEndsARowAndABlankRowIsKept() {
    List<List<String>> rows = CsvUtil.rows('a,b\r\nc,d\r\re,f', ',');

    Assert.areEqual(4, rows.size());
    Assert.areEqual(new List<String>{ 'c', 'd' }, rows[1]);
    Assert.isTrue(CsvUtil.isBlank(rows[2]));
    Assert.areEqual(new List<String>{ 'e', 'f' }, rows[3], 'the last row needs no line break after it');
  }

  @IsTest
  static void rowsNeedNotBeTheSameLength() {
    List<List<String>> rows = CsvUtil.rows('a,b,c\nd\ne,f,g,h', ',');

    Assert.areEqual(1, rows[1].size());
    Assert.areEqual(4, rows[2].size());
  }

  @IsTest
  static void aSeparatorThatIsNotNamedIsWorkedOut() {
    Assert.areEqual(new List<String>{ 'a', 'b', 'c,d' }, CsvUtil.rows('a;b;c,d\n', null)[0]);
    Assert.areEqual(new List<String>{ 'a', 'b' }, CsvUtil.rows('a|b', '')[0]);
    Assert.areEqual(new List<String>{ 'a.b', 'c' }, CsvUtil.rows('a.b|c', '|')[0], 'a named separator is taken as written, not as a pattern');
  }

  @IsTest
  static void aQuoteThatIsNeverClosedIsRefused() {
    try {
      CsvUtil.rows('a,"b\nc,d', ',');
      Assert.fail('expected a refusal');
    } catch (CsvUtil.GeneralException refused) {
      Assert.areEqual('A quoted cell is opened and never closed', refused.getMessage());
    }
  }

  @IsTest
  static void theSeparatorIsTheOneTheFirstLineHoldsMostOf() {
    Assert.areEqual(',', CsvUtil.separatorOf('a,b,c\n1;2;3'));
    Assert.areEqual(';', CsvUtil.separatorOf('a;b;c\n1,2,3'));
    Assert.areEqual('\t', CsvUtil.separatorOf('a\tb\tc'));
    Assert.areEqual('|', CsvUtil.separatorOf('a|b|c'));
    Assert.areEqual(';', CsvUtil.separatorOf('"Smith, John, and co";b'), 'what sits inside quotes is not counted');
    Assert.areEqual(',', CsvUtil.separatorOf('one column'));
    Assert.areEqual(',', CsvUtil.separatorOf(null));
  }

  @IsTest
  static void aTableHasAHeaderAndTheRowsBeneathIt() {
    String mark = String.fromCharArray(new List<Integer>{ 65279 });
    CsvUtil.Table table = CsvUtil.read(mark + ' Name ;Amount\nOne;1\n\nTwo;2\n');

    Assert.areEqual(';', table.separator);
    Assert.areEqual(new List<String>{ 'Name', 'Amount' }, table.header, 'trimmed, and without the byte order mark');
    Assert.areEqual(3, table.rows.size(), 'the blank row is there, so the rows keep their numbers');
    Assert.areEqual(2, table.rowNumber(0));
    Assert.areEqual(4, table.rowNumber(2));
    Assert.areEqual(new List<String>{ 'Two', '2' }, table.rows[2]);
  }

  @IsTest
  static void blankRowsAboveTheHeaderAreCountedToo() {
    CsvUtil.Table table = CsvUtil.read('\n,\nName\nOne');

    Assert.areEqual(new List<String>{ 'Name' }, table.header);
    Assert.areEqual(4, table.rowNumber(0), 'the header is the third row of the text');
  }

  @IsTest
  static void textWithNothingInItHasNoHeader() {
    Assert.isTrue(CsvUtil.read(null).header.isEmpty());
    Assert.isTrue(CsvUtil.read('').header.isEmpty());
    Assert.isTrue(CsvUtil.read('\n , \n').header.isEmpty());
    Assert.isTrue(CsvUtil.rows('', ',').isEmpty());
  }

  @IsTest
  static void whatIsWrittenCanBeReadBack() {
    List<Map<String, Object>> written = new List<Map<String, Object>>{
      new Map<String, Object>{ 'Name' => 'Acme, Inc', 'Note' => 'said "hi"\nthen left' },
      new Map<String, Object>{ 'Name' => 'Plain', 'Note' => null }
    };

    CsvUtil.Table table = CsvUtil.read(CsvUtil.toCsv(new List<String>{ 'Name', 'Note' }, written));

    Assert.areEqual(new List<String>{ 'Name', 'Note' }, table.header);
    Assert.areEqual(new List<String>{ 'Acme, Inc', 'said "hi"\nthen left' }, table.rows[0]);
    Assert.areEqual(new List<String>{ 'Plain', '' }, table.rows[1], 'null was written as an empty cell');
  }
}
