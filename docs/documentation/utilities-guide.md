# Utilities guide

The package carries twelve utility classes. They are `global`, so subscriber code can call them with the namespace prefix. They do not depend on an application: none of them needs `App.s`.

The examples are subscriber code. Every signature is in [`package_api.apex`](package_api.apex).

| Class | For |
| --- | --- |
| [`RandomUtil`](#randomutil-and-idutil) | Random integers, strings, decimals, list picks and Ids for test data |
| [`IdUtil`](#randomutil-and-idutil) | Fake Ids, empty records from Ids, record URLs, a tracker of Ids already seen |
| [`FieldUtil`](#fieldutil) | Picklist values, address groups, change detection, cropping and joining records, text turned into field values |
| [`RecordsUtil`](#recordsutil) | Copying a template record's fields onto other records |
| [`CsvUtil`](#csvutil) | CSV text from records or maps, and CSV text read into rows |
| [`TandemSortingUtil`](#tandemsortingutil) | Sorting one list by the values of another |
| [`StringUtil`](#stringutil) | String comparisons that treat null as empty |
| [`Persistent`](#persistent) | Small values that outlive the transaction |
| [`LimitsUtil`](#limitsutil-and-debugutil) | Governor-limit readings and the difference between two |
| [`DebugUtil`](#limitsutil-and-debugutil) | A multi-line trace written as one debug statement |
| [`CharUtil`](#charutil-and-uuidutil) | Character sets as number bases |
| [`UuidUtil`](#charutil-and-uuidutil) | Record Ids as UUID-shaped strings, and back |

## RandomUtil and IdUtil

```apex
String code = unif.RandomUtil.getString(8);                 // letters and digits
String pin = unif.RandomUtil.getString(4, '0123456789');
Integer quantity = unif.RandomUtil.getIntegerBetween(1, 10); // both bounds included
Object pick = unif.RandomUtil.getListItem(new List<Object>{ 'Hot', 'Warm', 'Cold' });

Id accountId = unif.IdUtil.generateId(Account.SObjectType);
```

`IdUtil.generateId` returns a well-formed Id that belongs to no record: the object's key prefix and a serial number. Each call in a transaction returns a different one, and `RandomUtil.getIdUnique` draws from the same sequence, so the two never collide. Use them to build records for tests that never touch the database.

The `Unique` methods of `RandomUtil` never repeat a value within a transaction. `getIntegerBetweenUnique` throws a `RandomUtil.RuntimeException` once every value in the range has been handed out.

```apex
// One empty record per Id, with only the Id set
List<SObject> stubs = unif.IdUtil.toRecords(accountIds, false);

// Which of these have I not seen before?
unif.IdUtil.ITracker tracker = unif.IdUtil.getTracker();
Set<Id> firstTime = tracker.getNovelIds(accountIds, true);
```

`toRecords` throws when the Ids are of more than one object, unless its second argument is `true`.

## FieldUtil

```apex
// In a trigger: the accounts whose owner or rating changed
List<SObject> moved = unif.FieldUtil.changed(
    Trigger.new, Trigger.oldMap, new List<SObjectField>{ Account.OwnerId, Account.Rating });

// A copy that holds only these fields
SObject slim = unif.FieldUtil.crop(account, new Set<SObjectField>{ Account.Name, Account.Industry });

// The first record, with its gaps filled from the second
SObject merged = unif.FieldUtil.join(incoming, existing);

// Multi-select picklists as sets
Set<String> chosen = unif.FieldUtil.getMultipickValues(record, Product2.Family);

// For each controlling value, the dependent values it allows
Map<String, Set<String>> allowed = unif.FieldUtil.getDependentPicklistValues(Account.Rating);

// Compound addresses by their stem
unif.FieldUtil.copyAddress(account, 'Billing', contact, 'Mailing');
```

`changed` counts a record with no previous version as changed. `getDependentPicklistValues` returns an empty map for a field with no controlling field.

`fromText` turns text, as a person types it into a file or a form, into the value a field takes:

```apex
Object due = unif.FieldUtil.fromText(Opportunity.CloseDate, '2026-01-31');   // a Date
Object amount = unif.FieldUtil.fromText(Opportunity.Amount, '1,234.50');     // a Decimal
Object stage = unif.FieldUtil.fromText(Opportunity.StageName, 'closed won'); // 'Closed Won'
```

| Field | Text it reads |
| --- | --- |
| Checkbox | `true`, `yes`, `y`, `1`, `false`, `no`, `n`, `0`, in any case |
| Number, currency, percent | `1234.5`, `-1234.5`, `1,234.5`; a percent may end in `%` |
| Date | `2026-01-31`, or the way the running user's locale writes a date |
| Date and time | `2026-01-31T14:30:00Z`, `2026-01-31 14:30` in the user's time zone, a date alone, or their locale's way |
| Time | `14:30` or `14:30:15` |
| Lookup | An Id of an object the field can point at |
| Picklist | A value or its label, in any case; anything else is passed on as written |
| Any other | The text, trimmed |

Blank text is null. Text the field cannot take throws `unif.FieldUtil.GeneralException` with a message a person can act on, such as `"soon" is not a date; write it like 2026-01-31`. A comma counts as a thousands separator only where it sits like one, so `1,5` is refused and not read as 15. `takesText(describe)` says whether a field can be filled from text at all: an address, a location or a file cannot.

## RecordsUtil

Copies the populated fields of a template onto records of the same object. Pass a unit of work and the records that changed are tracked in it; pass null and they are only changed in memory. Both methods return true when at least one record changed.

```apex
unif.IWork work = App.s.work();
Account template = new Account(Industry = 'Other', Rating = 'Cold');

unif.RecordsUtil.updateWhereBlank(accounts, template, work);     // fills only blank fields
unif.RecordsUtil.updateWhereDifferent(accounts, template, work); // sets every field that differs
work.apply();
```

## CsvUtil

```apex
String csv = unif.CsvUtil.toCsv(new List<String>{ 'LastName', 'Account.Name' }, contacts);
```

Columns are field paths and may cross lookups. Every cell is quoted and inner quotes are doubled (RFC 4180), lines end with `\n`, and null is an empty cell. To choose the header text, pass a map of path to label instead of the list. A third form takes a header and a list of maps.

It reads CSV too:

```apex
unif.CsvUtil.Table table = unif.CsvUtil.read(text);
table.header;        // the cells of the first row that is not blank, trimmed
table.rows;          // the rows beneath it, each a list of cells as written
table.rowNumber(0);  // which row of the text rows[0] was, counting from 1
table.separator;     // comma, semicolon, tab or bar: the one the first line holds most of
```

A quoted cell may hold the separator, line breaks, and quotes written twice. Lines may end in `\n`, `\r\n` or `\r`, and a byte order mark at the start is dropped. Rows need not be the same length. Blank rows beneath the header are kept, so `rowNumber` stays true to the text; test a row with `unif.CsvUtil.isBlank(row)`. Text with nothing in it gives an empty header. A quote that is never closed throws `unif.CsvUtil.GeneralException`.

`unif.CsvUtil.rows(text, separator)` returns every row with no header taken off, and `unif.CsvUtil.separatorOf(text)` says which separator a text uses.

## TandemSortingUtil

Sorts a list of keys and moves a second list in step with it. Both are reordered in place.

```apex
List<String> names = new List<String>{ 'Ada', 'Grace', 'Edsger' };
List<Decimal> scores = new List<Decimal>{ 72, 95, 88 };

unif.TandemSortingUtil.sort(names, scores, false, true); // descending, nulls last
// names: Grace, Edsger, Ada
```

Keys can be strings, decimals, datetimes or booleans. Equal keys keep their order. A fifth form sorts records by the value at a path, which may sit across lookups:

```apex
unif.IPath ownerName = App.s.model(Account.SObjectType).path('Owner.Name');
unif.TandemSortingUtil.sort(accounts, ownerName, true, true);
```

## StringUtil

```apex
unif.StringUtil.areEquivalent(null, '', false);   // true: null counts as empty
unif.StringUtil.areEquivalent('ACME', 'acme', true); // false: the last argument asks for case to matter
```

`containsAll` and `containsAny` compare two collections of strings the same way.

## Persistent

Small values that outlive the transaction, kept in a custom setting the package owns. Keys are grouped under a prefix, so two features do not collide.

```apex
unif.Persistent.INamespace sync = unif.Persistent.getNamespace('sync');

sync.put('lastRun', Datetime.now());
Datetime lastRun = (Datetime) sync.get('lastRun');
sync.remove('lastRun');
```

- Values are primitives and read back as the type they were stored as. Storing null removes the key.
- A prefix and a key are letters, digits and underscores, and together fit in 38 characters. A value fits in 255 once written as JSON.
- `put` is a DML statement. It counts against the transaction's limits, and it cannot run before a callout in the same transaction.
- Every caller in the org shares one store. Choose a prefix nobody else will.

## LimitsUtil and DebugUtil

```apex
unif.LimitsUtil.Snapshot before = new unif.LimitsUtil.Snapshot();
// ... the work being measured ...
System.debug(new unif.LimitsUtil.Snapshot().getDelta(before));
```

A snapshot reads six governor limits (CPU time, heap size, queries, query rows, DML statements, DML rows); `getDelta` is what was consumed between two. Each line reads `Name: 12.50% (used/limit)`.

`DebugUtil` collects lines and writes them as a single debug statement, so a trace of several steps reads as one block in the log:

```apex
unif.DebugUtil.printer()
    .writeSection('Sync')
    .inc()
    .write('3 accounts changed')
    .writePretty(payload)
    .dec()
    .writeLimits()
    .print();
```

`DebugUtil.printer()` makes a new printer. The `DebugUtil.printer` property is one printer shared by the whole transaction.

## CharUtil and UuidUtil

A `CharUtil.ICharset` is a set of characters read as the digits of a number base. Several are built in (`binary`, `numeric`, `lowerhex`, `upperhex`, `lowerdec`, `upperdec`, `alphadec`, `ascii`), and `CharUtil.charset('...')` makes another.

```apex
String hex = unif.CharUtil.numeric.convert('255', 2, unif.CharUtil.lowerhex); // 'ff'
String token = unif.CharUtil.alphadec.generateRandom(12);
```

`UuidUtil` turns a record Id into a UUID-shaped string and back, so an Id can leave the org without showing its key prefix:

```apex
unif.UuidUtil.Converter converter = new unif.UuidUtil.Converter(null);

String uuid = converter.fromRecordId(account.Id);
Id sameId = converter.toRecordId(uuid);
```

Pass the constructor lists of offsets and each digit is also shifted by position. That obscures the value. It is not encryption: anyone with the offsets, or enough examples, can reverse it.
