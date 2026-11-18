# Changelog

All notable changes to this project. Versions follow [semantic versioning](https://semver.org/); until 1.0, minor versions may change the API.

## Unreleased

The package is now **Injectify**, an unlocked package in the namespace `inj`; its first beta is 0.3.0-1. Versions up to 0.2.x were built in an earlier package under another namespace, and there is no upgrade path between the two: install Injectify beside the old package, change `unif.` to `inj.` in your code, then uninstall the old one.

### Added

- A query guide (`docs/documentation/query-guide.md`).
- The extension, work and testing guides, rewritten as subscriber code and checked against the source.
- `MockScheme`: a scheme for tests. Describes are real; queries return rows you register (typed to the queried object) and are recorded with their bind values.
- `IJob.setShared` / `getShared`, and `IJobAware`: a handler implementing it is given its job during each call, to share values along a chain.
- `Async.synchronousInTests` is now `global`, so subscriber tests can run whole chains inline.
- `IdUtil.generateId(SObjectType)`.
- **The utility classes are `global`**, so subscriber code can call them: `CharUtil`, `CsvUtil`, `DebugUtil`, `FieldUtil`, `IdUtil`, `LimitsUtil`, `Persistent`, `RandomUtil`, `RecordsUtil`, `StringUtil`, `TandemSortingUtil` and `UuidUtil`. `CharUtil.Charset`, `DebugUtil.Printer`, `IdUtil.Tracker` and `Persistent.Namespace` stay internal behind their interfaces and factory methods. `DebugUtil.IPrinter` gains `writeLimits()`. See the new utilities guide (`docs/documentation/utilities-guide.md`).
- **`IWork.withSharing(true)`** runs a work's inserts, updates, upserts and deletes in user mode: the running user's object permissions, field permissions and sharing apply, and the platform refuses a statement that breaks them. System mode stays the default. A class of your own that implements `IWork` needs the new method.
- **`ISearchScheme`**, an optional interface for schemes: `search(String sosl, System.AccessLevel accessLevel)`. Searches now run through the scheme of their first query when it implements the interface, which the default scheme and `MockScheme` do. `MockScheme` returns the registered rows for each object after `RETURNING` and records the SOSL. A scheme that implements only `IScheme` keeps working: its searches go straight to the platform, as before.
- A search runs in user mode when one of its queries was set to `withSharing(true)`.
- **`ICore.aggregate(Enums.Aggregate, field)`** and the enum `Enums.Aggregate` (`COUNT`, `COUNT_DISTINCT`, `SUM`, `AVG`, `MIN`, `MAX`): an aggregate function chosen at run time, as `cond(Enums.Comparator, ...)` chooses a comparison.
- **`IQuery.forUpdate(true)`** adds `FOR UPDATE` to `run()` and `fetch()`, locking the rows returned until the transaction ends. A class of your own that implements `IQuery` needs the new method; one that extends `BaseQuery` does not.
- **`IWork.failures()` and `IWork.failureOf(record)`**, with the new interface `IWorkFailure` (`getRecord()`, `getMessage()`, `getErrors()`): after `apply()` with `options().optAllOrNone = false`, the work says which records were not saved and why. Before, it did not report them. A class of your own that implements `IWork` needs the two new methods.
- **`ITriggeredFactory.disableWhen(rule)`**, with the new interface `ITriggeredBypass` (`bypasses(SObjectType, TriggerOperation)`): a rule of your own that switches triggers off, asked each time a trigger is about to run. A rule that reads a custom permission lets an administrator switch triggers off for a user without a deployment. A class of your own that implements `ITriggeredFactory` needs the new method.
- **`CsvUtil` reads CSV**: `read(text)` returns a `CsvUtil.Table` (header, rows, the separator it found, and `rowNumber(index)`); `rows(text, separator)`, `separatorOf(text)` and `isBlank(row)` are the pieces. Quoted cells, any line ending, a byte order mark, and comma, semicolon, tab or bar as the separator.
- **`FieldUtil.fromText(field, text)`** turns text into the value a field takes (checkbox, number, percent, date, date and time, time, lookup Id, picklist value or label), and throws a `FieldUtil.GeneralException` that quotes the text and says what was expected. `FieldUtil.takesText(describe)` says whether a field can be filled from text at all.

### Changed

- **API version 68.0** (was 60.0). Describes now include fields added to the platform since 60.0, so default field sets pick up new standard fields. Default field sets leave out fields no user can be given access to, such as the license-gated Einstein Account Tier.
- `Work`, `Persistent`, `SchedulableJob`, `SchemeDefault` and `MockScheme` declare `inherited sharing`, and their DML and queries state system mode explicitly. Behavior is unchanged.
- **Async engine rebuilt** on a singly linked chain: `then()` appends at the end and returns the job it was called on; a job may appear in a chain once; chains are capped at 20 waiting jobs and 40 in a lineage. Captured jobs are handled in a fixed order: synchronous jobs run, then the chain becomes released jobs (in tests; outside tests they start at once), one queueable bundling the immediate jobs, prepended jobs, the jobs already waiting, and appended jobs; ignored jobs are dropped. Job ids come from the platform context, and a handler's `batchDefaultSize()` is honored.
- **Inline SOQL** (`toSoql()`): string values are escaped, and dates, datetimes and times are written as SOQL literals. `run()` still binds values.
- **In-memory LIKE** ignores case and matches across line breaks, as SOQL does.
- A condition on an unsupported value or field type throws a `ValidationException`.
- `Work` fills lookups to records that already exist before inserting the child, so fewer updates follow an insert.
- **`Work` with `optAllOrNone = false` no longer saves a record without the new record it depends on.** When a new parent fails, a child tracked with `track(child, lookupField, parent)` is not inserted; before, it was inserted without that lookup. An existing record that was to be related to the failed parent is not updated; before, its lookup was set to null. Both are listed by `failures()`. With `optAllOrNone` true, the default, nothing changes.
- **A user-mode upsert by a user with no access to the object throws a `SecurityException`** (`Access to entity '...' denied`), as an insert, update or delete does. Before, with `optAllOrNone` true, the platform ended the transaction with an error Apex could not catch. With `optAllOrNone` false nothing changes: the records are listed in `failures()`.
- Sorting (`Ordering.apply`, `Domain.sort`, `TandemSortingUtil`) is stable: equal values keep their order. `Ordering.apply` places nulls first or last as asked whatever the direction, as SOQL does.
- `setLimit`, `setOffset`, `withSecurity` and `withSharing` treat null as off.
- **`Query`, `BaseQuery`, `AggregateQuery` and `SearchQuery` declare `inherited sharing`**, so a system-mode query has the sharing of the class that builds it. Before, the sharing keyword of a subscriber's class did not reach a query made through the package: built in a class declared `without sharing`, a query could still leave out records the running user could not see. Code that relied on that now reads more records from a `without sharing` class. A scheme with a sharing keyword of its own still decides for every query run through it.
- **User-mode queries leave out default fields the running user cannot read**, instead of failing. This applies to the fields the query factory adds (the default set, or a registered class's `getDefaultFields()`), in a query, its subqueries and a search. A field added by name that the user cannot read still fails the query. System-mode queries are unchanged.
- A batch released while another batch is in its start or execute step is started by a queueable, since the platform refuses to start it there. Before, the release failed with the platform's error.
- `ModelFields` checks every untrusted field against the object, not a sample of three.
- `Domain.updateDifferent` and `updateBlank` reject a template of another object type.
- Schedulable handlers that return a blank name or cron expression get the handler's class name and a run one minute ahead. `unschedule()` matches the job name exactly.
- **Three internal classes are renamed:** `Queueable` to `QueueableJob`, `Schedulable` to `SchedulableJob` and `Domain` to `DomainRecords`. Deployed as source, with no namespace, the old names hid `System.Queueable`, `System.Schedulable` and `System.Domain` from every other class in the org: a class that said `implements Queueable` stopped compiling. The classes are not `global`, so code that uses the package is unaffected.
- **Enum order:** the values of `Enums.Comparator`, `Enums.SearchScope` and `Enums.CaptureMode` are listed in a new order. Names are unchanged, but code that relies on `ordinal()` or on the order of `values()` sees different results.
- Utilities:
  - `CsvUtil` quotes per RFC 4180;
  - `FieldUtil.toCSV` writes through `CsvUtil`;
  - `UuidUtil` converts Ids exactly, so UUIDs for real Ids may differ from earlier versions;
  - `Persistent` caps keys at 38 characters, rejects values over 255 and validates keys more strictly;
  - `TandemSortingUtil` compares Integer fields as numbers, sorts Time fields, and throws on Blob fields;
  - `RandomUtil.getIntegerBetweenUnique` throws once a range is used up;
  - `IdUtil` and `RandomUtil` share one fake-Id sequence; `IdUtil.toRecords` returns an empty list for an empty set;
  - `StringUtil` treats a null case flag as case-insensitive;
  - `RecordsUtil` decides blankness by value;
  - `LimitsUtil` snapshots keep the order they were taken in;
  - `DebugUtil` applies its indentation.
- Interface parameter names and declaration order changed (no signature changes). `IDomain` and `ILookupPath` use array notation for the same types.

### Fixed

- Fields added through a polymorphic lookup wrote a `TYPEOF` branch for every possible target (about ninety for `What`), some of them empty, which SOQL rejects. Only targets given fields get a branch now.
- Asking a lookup for a field by a name it does not have (`lookup.path('Nmae')`, `getReference`) returned the lookup itself. It returns null, or throws when asked strictly, as a model does.
- `count(null)` in an aggregate query rendered `COUNT() cnt`, which SOQL rejects. It renders `COUNT(Id) cnt`.
- `ServiceFactory.get()` of a null or unregistered type threw a NullPointerException. It throws a `ServiceFactoryException`, as `make()` does.
- `Work` dropped a new record whose field values matched another new record's. It also:
  - could leave a child with two new parents missing one lookup;
  - overflowed the stack on a cycle among new records (now a `WorkException`);
  - failed on required lookups to existing records.
- With trigger security enforcement on, every insert and undelete threw "Unknown operation". Undelete now checks the undelete permission.
- `WITH SECURITY_ENFORCED` came after `ORDER BY`, `LIMIT` and `OFFSET` (and after `GROUP BY` in aggregate queries), which SOQL rejects.
- `Domain.aggregate` MIN and MAX returned the first value instead of the smallest or largest.
- A recycled domain's AFTER phase saw `catalog()` results from its BEFORE phase.
- A query built from a core with an injected scheme resolved its conditions through the default core.
- Async:
  - adding a job that was already in the chain looped forever (now rejected);
  - a captured synchronous job did not run;
  - a bundled job's successors did not run;
  - a failed job left capture switched on;
  - shared values did not reach every job in a chain.
- `FieldUtil`: `chunk` checks every field before writing; `changed`, cropping by dotted name and checkbox-controlled dependent picklists no longer throw.
- `CharUtil` shifts now wrap for negative and oversized offsets, characters outside a charset are rejected, and conversions handle values beyond a Long.

### Security

- Aggregate query values in `WHERE` and `HAVING` are bound when the query runs; they used to be written inline.
- A SOSL search term can no longer close `FIND {...}` early: backslashes, braces and quotes are escaped.
- `INCLUDES`/`EXCLUDES` values, and every other inline string, are escaped.

### Performance

- Describes, field maps and resolved paths are cached for the transaction: resolving a three-step path went from about 6 ms to 0.2 ms, building a query from about 10 ms to 3.5 ms.
- Condition evaluation over records roughly halved; LIKE patterns compile once per transaction.

### Removed

- The `logs` entry in a chain's shared values, the per-job `synchronousInTests()` override, and `dispatchAsyncHandler`.

## 0.2.6

Baseline for this changelog.
