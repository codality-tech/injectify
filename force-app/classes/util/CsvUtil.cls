/**
 * Writes and reads CSV text.
 *
 * WRITING (toCsv): a header line, then one line per row, separated by \n. Every cell is quoted and
 * inner quotes are doubled (RFC 4180), so commas, quotes and line breaks survive. Null is "".
 * SObject columns are field paths and may cross relationships, e.g. 'Account.Owner.Name'.
 *
 * READING (read, rows): a cell in quotes may hold the separator, line breaks, and quotes written
 * twice. Lines may end in \n, \r\n or \r, and a byte order mark at the start is dropped. The
 * separator is a comma, semicolon, tab or bar, worked out from the first line unless you name it.
 *
 *   CsvUtil.Table table = CsvUtil.read(text);
 *   table.header;        // the cells of the first row that is not blank, trimmed
 *   table.rows;          // the rows after it, each a list of cells as written
 *   table.rowNumber(0);  // where the first of those sits in the text, counting from 1
 */
global class CsvUtil {
  global class GeneralException extends Exception {
  }

  private static final String LINE_BREAK = '\n';
  private static final String BYTE_ORDER_MARK = String.fromCharArray(new List<Integer>{ 65279 });
  private static final List<String> SEPARATORS = new List<String>{ ',', ';', '\t', '|' };

  //* Writing

  global static String toCsv(List<String> header, List<Map<String, Object>> data) {
    List<String> lines = new List<String>{ encode(header) };
    for (Map<String, Object> entry : data) {
      Object[] cells = new Object[header.size()];
      for (Integer at = 0; at < header.size(); at++) {
        cells[at] = entry.get(header[at]);
      }
      lines.add(encode(cells));
    }
    String text = String.join(lines, LINE_BREAK);
    return text;
  }

  global static String toCsv(List<String> fieldPaths, List<SObject> records) {
    return tabulate(fieldPaths, fieldPaths, records);
  }

  /** Columns are field paths mapped to the header label to show for each. */
  global static String toCsv(Map<String, String> labelByPath, List<SObject> records) {
    List<String> paths = new List<String>(labelByPath.keySet());
    String[] labels = new String[paths.size()];
    for (Integer at = 0; at < paths.size(); at++) {
      labels[at] = labelByPath.get(paths[at]);
      if (String.isBlank(labels[at])) {
        throw new GeneralException('Column ' + paths[at] + ' needs a label');
      }
    }
    return tabulate(labels, paths, records);
  }

  private static String tabulate(List<String> labels, List<String> paths, List<SObject> records) {
    String text = encode(labels);
    for (SObject record : records) {
      Object[] cells = new Object[paths.size()];
      for (Integer at = 0; at < paths.size(); at++) {
        cells[at] = valueAt(record, paths[at]);
      }
      text += LINE_BREAK + encode(cells);
    }
    return text;
  }

  private static String encode(List<Object> cells) {
    String[] quoted = new String[cells.size()];
    for (Integer at = 0; at < cells.size(); at++) {
      String raw = cells[at] == null ? '' : String.valueOf(cells[at]);
      quoted[at] = '"' + raw.replace('"', '""') + '"';
    }
    return String.join(quoted, ',');
  }

  // Follows each relationship in a dotted path; a missing parent yields null.
  private static Object valueAt(SObject record, String path) {
    if (record == null || String.isBlank(path)) {
      return null;
    }
    List<String> hops = path.split('\\.');
    SObject holder = record;
    for (Integer at = 0; at < hops.size() - 1 && holder != null; at++) {
      holder = holder.getSObject(hops[at]);
    }
    return holder?.get(hops[hops.size() - 1]);
  }

  //* Reading

  /** What read() returns: the header of a CSV text and the rows beneath it. */
  global class Table {
    global String separator;
    global List<String> header = new List<String>();
    global List<List<String>> rows = new List<List<String>>();
    private Integer blankRowsAbove = 0;

    /** The row of the text that rows[index] came from. The first row of the text is 1. */
    global Integer rowNumber(Integer index) {
      return blankRowsAbove + index + 2;
    }
  }

  /**
   * The text as a header and the rows beneath it, with the separator worked out from the first
   * line. Blank rows above the header are skipped; blank rows below it are kept, so rowNumber()
   * stays true to the text. Empty text gives a table with an empty header.
   */
  global static Table read(String text) {
    Table table = new Table();
    table.separator = separatorOf(text);
    List<List<String>> everyRow = rows(text, table.separator);
    Integer top = 0;
    while (top < everyRow.size() && isBlank(everyRow[top])) {
      top++;
    }
    if (top == everyRow.size()) {
      return table;
    }
    table.blankRowsAbove = top;
    for (String title : everyRow[top]) {
      table.header.add(title.trim());
    }
    for (Integer next = top + 1; next < everyRow.size(); next++) {
      table.rows.add(everyRow[next]);
    }
    return table;
  }

  /**
   * Every row of the text, blank ones included, as lists of cells. A null or empty separator is
   * worked out from the first line. Throws a GeneralException when a quote is never closed.
   *
   * The text is cut at its quotes, so the pieces alternate: outside quotes, inside, outside. An
   * outside piece is cut into rows and cells; an inside piece is cell text as it stands. An empty
   * outside piece between two inside pieces is a quote written twice, which stands for one quote.
   * That keeps the work per row, not per character.
   */
  global static List<List<String>> rows(String text, String separator) {
    List<List<String>> found = new List<List<String>>();
    if (String.isEmpty(text)) {
      return found;
    }
    String cut = Pattern.quote(String.isEmpty(separator) ? separatorOf(text) : separator);
    List<String> pieces = tidied(text).split('"', -1);
    if (Math.mod(pieces.size(), 2) == 0) {
      throw new GeneralException('A quoted cell is opened and never closed');
    }

    List<String> row = new List<String>();
    String cell = '';
    for (Integer at = 0; at < pieces.size(); at++) {
      String piece = pieces[at];
      Boolean inQuotes = Math.mod(at, 2) == 1;
      if (inQuotes) {
        cell += piece;
      } else if (piece == '' && at > 0 && at < pieces.size() - 1) {
        cell += '"';
      } else {
        List<String> lines = piece.split(LINE_BREAK, -1);
        for (Integer line = 0; line < lines.size(); line++) {
          if (line > 0) {
            row.add(cell);
            found.add(row);
            row = new List<String>();
            cell = '';
          }
          List<String> parts = lines[line].split(cut, -1);
          for (Integer part = 0; part < parts.size(); part++) {
            if (part > 0) {
              row.add(cell);
              cell = '';
            }
            cell += parts[part];
          }
        }
      }
    }
    if (!row.isEmpty() || cell != '') {
      row.add(cell);
      found.add(row);
    }
    return found;
  }

  /**
   * Which of comma, semicolon, tab and bar separates the cells: the one the first line holds most
   * of, outside its quotes. A comma when none of them appears.
   */
  global static String separatorOf(String text) {
    String firstLine = String.isEmpty(text) ? '' : tidied(text).substringBefore(LINE_BREAK).replaceAll('"[^"]*"', '');
    String chosen = SEPARATORS[0];
    Integer most = 0;
    for (String candidate : SEPARATORS) {
      Integer times = firstLine.countMatches(candidate);
      if (times > most) {
        most = times;
        chosen = candidate;
      }
    }
    return chosen;
  }

  /** Whether every cell of the row is empty or white space. */
  global static Boolean isBlank(List<String> row) {
    for (String cell : row) {
      if (String.isNotBlank(cell)) {
        return false;
      }
    }
    return true;
  }

  private static String tidied(String text) {
    return text.removeStart(BYTE_ORDER_MARK).replace('\r\n', LINE_BREAK).replace('\r', LINE_BREAK);
  }
}
