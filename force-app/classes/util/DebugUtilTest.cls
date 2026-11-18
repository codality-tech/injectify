@IsTest
private class DebugUtilTest {
  @IsTest
  static void linesAreTrimmedAndEndWithABreak() {
    DebugUtil.IPrinter printer = DebugUtil.printer();

    printer.write('  first  ').write(42).write(null);

    Assert.areEqual('first\n42\nnull\n', printer.toString());
  }

  @IsTest
  static void indentationAppliesToEveryLineAndStopsAtZero() {
    DebugUtil.IPrinter printer = DebugUtil.printer();

    printer.write('top').inc().write('one\ntwo').inc().write('deep').dec().dec().dec().write('back');

    Assert.areEqual('top\n  one\n  two\n    deep\nback\n', printer.toString());
  }

  @IsTest
  static void sectionsStartWithABlankLine() {
    DebugUtil.IPrinter printer = DebugUtil.printer();

    printer.write('before').writeSection('Totals').write('after');

    Assert.areEqual('before\n\n~~~[ Totals ]~~~\nafter\n', printer.toString());
  }

  @IsTest
  static void valuesCanBeWrittenAsJson() {
    Map<String, Object> value = new Map<String, Object>{ 'n' => 1 };
    DebugUtil.IPrinter compact = DebugUtil.printer().writeSerialized(value);
    DebugUtil.IPrinter pretty = DebugUtil.printer().inc().writePretty(value);

    Assert.areEqual('{"n":1}\n', compact.toString());
    for (String line : pretty.toString().removeEnd('\n').split('\n')) {
      Assert.isTrue(line.startsWith('  '), 'every pretty line is indented: ' + line);
    }
  }

  @IsTest
  static void limitsCanBeWritten() {
    DebugUtil.Printer printer = new DebugUtil.Printer();

    printer.writeLimits();

    Assert.isTrue(printer.toString().contains('CPU Time: '), printer.toString());
  }

  @IsTest
  static void anEmptyPrinterPrintsNothing() {
    DebugUtil.IPrinter printer = DebugUtil.printer();

    printer.print();

    Assert.areEqual('', printer.toString());
  }

  @IsTest
  static void thePropertyIsSharedAndTheMethodIsFresh() {
    Assert.isTrue(DebugUtil.printer === DebugUtil.printer);
    Assert.isFalse(DebugUtil.printer() === DebugUtil.printer());
  }
}
