/**
 * Governor-limit readings: take a Snapshot, do some work, take another, and getDelta() shows what
 * the work consumed. Each line reads "Name: 12.50% (used/limit)".
 */
global class LimitsUtil {
  global class AnyException extends Exception {
  }

  private static final List<String> TRACKED = new List<String>{
    'CPU Time',
    'Heap Size',
    'Query Count',
    'Query Rows',
    'DML Count',
    'DML Rows'
  };

  // Orders snapshots even when two are taken within the same millisecond.
  private static Integer snapshotsTaken = 0;

  /** All tracked limits at one moment, or the difference between two such moments. */
  global class Snapshot {
    private Integer sequence;
    private List<LimitItem> items;

    global Snapshot() {
      this(readAll());
    }

    private Snapshot(List<LimitItem> items) {
      snapshotsTaken++;
      this.sequence = snapshotsTaken;
      this.items = items;
    }

    /** What was consumed between this snapshot and the other, whichever was taken first. */
    global Snapshot getDelta(Snapshot other) {
      Snapshot earlier = other.sequence < sequence ? other : this;
      Snapshot later = earlier === this ? other : this;
      List<LimitItem> differences = new List<LimitItem>();
      for (Integer index = 0; index < later.items.size(); index++) {
        differences.add(later.items[index].getDelta(earlier.items[index]));
      }
      return new Snapshot(differences);
    }

    global String stringify() {
      return render(items);
    }

    global override String toString() {
      return stringify();
    }
  }

  /** One limit: how much is used out of what is available. */
  global class LimitItem {
    private String name;
    private Decimal used;
    private Decimal available;

    global LimitItem(String name, Decimal used, Decimal available) {
      this.name = name;
      this.used = used;
      this.available = available;
    }

    global String stringify() {
      Decimal share = (used / available * 100).setScale(2);
      return name + ': ' + share + '% (' + used + '/' + available + ')';
    }

    /** This reading minus an earlier one of the same limit. */
    global LimitItem getDelta(LimitItem preceeding) {
      if (preceeding.name != name) {
        throw new AnyException(
          'Cannot subtract ' + preceeding.name + ' from ' + name
        );
      }
      return new LimitItem(name, used - preceeding.used, available);
    }
  }

  /** The current reading of every tracked limit, one per line after a leading line break. */
  global static String stringify() {
    return render(readAll());
  }

  private static String render(List<LimitItem> items) {
    String text = '';
    for (LimitItem item : items) {
      text += '\n' + item.stringify();
    }
    return text;
  }

  private static List<LimitItem> readAll() {
    List<LimitItem> readings = new List<LimitItem>();
    for (String name : TRACKED) {
      readings.add(read(name));
    }
    return readings;
  }

  private static LimitItem read(String name) {
    Integer used;
    Integer ceiling;
    switch on name {
      when 'CPU Time' {
        used = Limits.getCpuTime();
        ceiling = Limits.getLimitCpuTime();
      }
      when 'Heap Size' {
        used = Limits.getHeapSize();
        ceiling = Limits.getLimitHeapSize();
      }
      when 'Query Count' {
        used = Limits.getQueries();
        ceiling = Limits.getLimitQueries();
      }
      when 'Query Rows' {
        used = Limits.getQueryRows();
        ceiling = Limits.getLimitQueryRows();
      }
      when 'DML Count' {
        used = Limits.getDmlStatements();
        ceiling = Limits.getLimitDmlStatements();
      }
      when else {
        used = Limits.getDmlRows();
        ceiling = Limits.getLimitDmlRows();
      }
    }
    return new LimitItem(name, used, ceiling);
  }
}
