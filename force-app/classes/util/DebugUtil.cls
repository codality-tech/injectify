/**
 * Collects lines for one System.debug call, with indentation and section headers, so a multi-step
 * trace reads as a single block in the log.
 */
global class DebugUtil {
  global interface IPrinter {
    IPrinter writeSection(String title);
    IPrinter write(Object value);
    IPrinter writeSerialized(Object value);
    IPrinter writePretty(Object value);
    IPrinter writeLimits();
    IPrinter inc();
    IPrinter dec();
    void print();
  }

  private static final String INDENT = '  ';
  private static IPrinter shared;

  /** One printer shared across the transaction. */
  global static IPrinter printer {
    get {
      if (shared == null) {
        shared = new Printer();
      }
      return shared;
    }
  }

  /** A fresh printer. */
  global static IPrinter printer() {
    return new Printer();
  }

  public class Printer implements IPrinter {
    private List<String> lines = new List<String>();
    private Integer depth = 0;

    public Printer() {
    }

    /** Indents later lines one level deeper. */
    public IPrinter inc() {
      depth++;
      return this;
    }

    /** Indents later lines one level shallower, never below zero. */
    public IPrinter dec() {
      depth = Math.max(0, depth - 1);
      return this;
    }

    /** Writes the text trimmed, indenting each of its lines at the current depth. */
    public Printer writeString(String value) {
      String margin = INDENT.repeat(depth);
      for (String line : value.trim().split('\n')) {
        lines.add(margin + line);
      }
      return this;
    }

    public IPrinter write(Object value) {
      return writeString(value == null ? 'null' : String.valueOf(value));
    }

    public IPrinter writeSerialized(Object value) {
      return writeString(JSON.serialize(value));
    }

    public IPrinter writePretty(Object value) {
      return writeString(JSON.serializePretty(value));
    }

    /** Writes the current governor-limit reading. */
    public IPrinter writeLimits() {
      return write(new LimitsUtil.Snapshot());
    }

    /** A blank line, then the title as a header. */
    public IPrinter writeSection(String title) {
      lines.add('');
      return writeString('~~~[ ' + title + ' ]~~~');
    }

    /** Every line followed by a line break; empty when nothing was written. */
    public override String toString() {
      return lines.isEmpty() ? '' : String.join(lines, '\n') + '\n';
    }

    public void print() {
      System.debug(toString());
    }
  }
}
