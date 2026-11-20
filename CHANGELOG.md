# Changelog

All notable changes to this project. Versions follow [semantic versioning](https://semver.org/); until 1.0, minor versions may change the API.

## Unreleased

Nothing yet.

## 0.4.0

Released 2026-11-20 as `Injectify@0.4.0-1`. It is 0.4.0, not 0.3.1, because the new methods on `IQuery` and `IAggregateQuery` break a class that implements either directly (see Changed).

### Added

- **Semi-joins and anti-joins.** `iin` and `nin` (and `cond` with `IIN` or `NIN`) take a query as their value: `App.s.iin(Account.Id, contactQuery)` writes `Id IN (SELECT AccountId FROM Contact WHERE ...)`, and `nin` writes `NOT IN`. No new method: the value was already an `Object`, and `IFieldCondition.value()` returns the query.
  - The field on the left is an `Id` or a lookup field. Another kind of field, or a query given to another operator, throws a `ConditionException` when the condition is built.
  - The inner query selects one field: the lookup field you chose, or its `Id` when you chose none. A query from the factory needs `fields().clearFields()` first. Any other selection, a limit or an offset is refused when the outer query is written or run, with a `UnifValidationException` such as `Cannot use the query on Contact in a semi-join: it selects 62 fields besides Id`.
  - Its values are bound with the outer query's (`:a0`, `:a1`...) in `run()`, `fetch()`, `count()` and `toLocator()`, and written inline, escaped, by `toSoql()`.
  - It works in a query's WHERE clause, in a child subquery's, in an aggregate query's WHERE clause and in a search's filters. HAVING takes none (the platform refuses it). A `ConditionException` says so: when the condition is built, if its left side is an aggregate function, and otherwise when the aggregate query is written or run.
  - `withSecurity(true)` also checks the inner query's object and the field it selects. User mode (`withSharing(true)`) on the outer query covers the inner one.
  - `deepClone()` and `clone(true)` copy the inner query. `evaluate()` throws for a semi-join: it cannot be tested in memory. `parseCondition` does not read one from text, and says so.
  - The platform's own rules (two per query, not under `OR` or `NOT`, top level of WHERE only, different objects) come through as its `QueryException`. The [query guide](docs/documentation/query-guide.md#semi-joins-and-anti-joins) lists them as checked at API version 68.0.

- **Date literals.** `DateLiteral` makes SOQL's relative ranges of days, as the value of a condition on a date or date-time field: `App.s.ge(Opportunity.CloseDate, inj.DateLiteral.lastNDays(30))` writes `CloseDate >= LAST_N_DAYS:30`. There is a factory for each of the 44 literals in the SOQL reference (`today()`, `thisWeek()`, `nextNMonths(2)`, `lastFiscalQuarter()`, `nFiscalYearsAgo(1)`...), and `DateLiteral.of('NEXT_N_FISCAL_QUARTERS:2')` reads one from text. New global types: the class `DateLiteral` and the interface `IDateLiteral` (`toSoql()`, `startDate()`, `endDate()`).
  - `startDate()` and `endDate()` give the range in Apex: its first and its last day, inclusive, for the running user today. `inj.DateLiteral.thisFiscalQuarter().endDate()` is the last day of the current fiscal quarter. A range of no days (`LAST_N_WEEKS:0`) ends the day before it starts.
  - It goes with `eq`, `ne`, `lt`, `le`, `gt` and `ge`; `iin` and `nin` take a `List<IDateLiteral>`. Another operator, or a field that is not a date or date-time, throws when the condition is built.
  - It is written into the SOQL as it is and never bound, in a query, a child subquery, the inner query of a semi-join, an aggregate query's WHERE and HAVING, and a search's filters. A literal of a class of your own that implements `IDateLiteral` is read from the text its `toSoql()` gives, so only the text of a date literal reaches a query.
  - `parseCondition` reads them: `CloseDate = LAST_N_DAYS:30`, `CreatedDate IN (THIS_WEEK, LAST_WEEK)`.
  - `evaluate` gives them SOQL's meaning: whole days in the running user's time zone, weeks from the first day of the week of the user's locale, an empty field outside every range. Fiscal literals are worked out for a standard fiscal year: two queries, once per transaction, through the scheme of the object the condition is on, so a `MockScheme` answers them. An organization with custom fiscal years gets a `ConditionException`. So does a count above 365000, the most the platform takes for any unit.
- **`IQuery.allRows(true)`, `usingScope(scope)`, `forView(true)` and `forReference(true)`**, in the style of `forUpdate`: `ALL ROWS`, `USING SCOPE`, `FOR VIEW` and `FOR REFERENCE`, each written where the platform takes it. **`IAggregateQuery.allRows(true)` and `usingScope(scope)`** as well; the platform fails on the other two in an aggregate query. The new enum `Enums.FilterScope` has the scopes of the SOQL reference (`DELEGATED`, `EVERYTHING`, `MINE`, `MINE_AND_MY_GROUPS`, `MY_TERRITORY`, `MY_TEAM_TERRITORY`, `SCOPING_RULE`, `TEAM`). A class of your own that implements either interface needs the new methods: see Changed.
  - Copies (`deepClone()`) carry them. `count()` takes `ALL ROWS` and the scope; `toLocator()` takes all but the lock.
  - Combinations the platform refuses with `unexpected token` are refused by the framework when the query is written or run, with a message that names them, such as `Cannot write FOR VIEW with FOR REFERENCE on Account: a query takes one or the other`. They are `FOR VIEW` with `FOR REFERENCE`, `FOR UPDATE` with `ALL ROWS`, `ALL ROWS` or a scope on a child subquery, and `ALL ROWS` on the inner query of a semi-join (each a `UnifValidationException`), and `ALL ROWS` or a scope on a query of a search (a `SearchException`).
  - For a scope the queried object does not support, the platform ends the transaction with an error no code can catch. The framework cannot check this: see the [query guide](docs/documentation/query-guide.md#deleted-records-scopes-and-view-marks).
- **Paths through a polymorphic lookup.** `What.Type`, `Owner.Name`, `Owner.Profile.Name`: the fields every target of such a lookup has, which the platform keeps on the `Name` object, are now paths. They work in conditions by name (`App.s.eq('What.Type', 'Account')`) and by field (`new List<SObjectField>{ Task.WhatId, Schema.Name.Type }`), in `parseCondition`, in orderings, in selected fields, in an aggregate query's groupings and in a search. Before, each threw `Cannot follow ...`. A field of one target (`What.Industry`) still needs `TYPEOF`, and the exception says why: `What can point at several objects, and Industry is not a field of them all`.
  - In memory such a path reads what the record carries: a row the query returned for `What.Type`, a row of the target itself (a user put on the record with its profile answers `Owner.Profile.Name`), or the Id alone, from which `Type` is told. A group of any kind is `Queue`, as in SOQL.
  - `fields().add(lookup, names)` on a polymorphic lookup reads the names as fields of the `Name` object; it threw before.
  - A path and `TYPEOF` through the same lookup in one SELECT (`What.Type` beside `TYPEOF What`) are refused when the SELECT is written, as the platform refuses them: `Cannot select What.Type beside TYPEOF What: one SELECT reads a lookup as a path or with TYPEOF, not both`.
- **`parseCondition` reads times of day** (`MondayStartTime >= 09:30:00.000Z`), and a date literal with spaces around its colon (`LAST_N_DAYS : 30`), as SOQL takes it. Every value `toSoql()` writes for a condition is now read back.

### Changed

- **A class of your own that implements `IQuery` or `IAggregateQuery` directly stops compiling until it has the new methods**: `allRows`, `usingScope`, `forView` and `forReference` for `IQuery`, and `allRows` and `usingScope` for `IAggregateQuery`. Add them to the class, each returning the query. A class that extends `BaseQuery` needs nothing.
- **`neg` reverses a condition; it no longer only sets it.** `neg(c)` still changes the condition it is given and returns that same condition. A second `neg` now takes the first one back: `neg(neg(c))` is `c`, where it was `NOT c`. `NOT NOT x` in `parseCondition` is `x` in the same way. Code that negated one condition twice to be sure of it now undoes the negation.
- **An empty `any` or `all` is a constant, in SOQL as in memory.** A group with no members was left out of the SOQL, so it filtered nothing, while in memory an empty `all` held and an empty `any` did not. Now an empty `any` is never true and is written `(Id = null AND Id != null)`, and an empty `all` is always true and is written `(Id = null OR Id != null)`; in HAVING the same tests are written on `COUNT(Id)`. **A query that was given an empty `any` returned every row and now returns none.** `ILogicalCondition.toSoql()` returns that text where it returned null. The root of a query, `filters()`, still writes no WHERE while it has no members.
- **A `null` value with `lt`, `le`, `gt`, `ge` or `lk` is refused when the query is written or run**, bound or inline: `Cannot compare AnnualRevenue with null by GT: null goes with EQ and NE` (a `ValidationException`; for an aggregate function in HAVING, a `ConditionException`). Bound, such a query used to run, with answers that followed no rule. In memory nothing is thrown: the answer is unknown, so the record is left out, and stays out under `neg`. Before, `neg(gt(field, null))` matched every record whose field had a value.
- **A whole number compared with an integer field is held as an Integer.** `eq(Account.NumberOfEmployees, 5.0)`, a `Long`, or a list or set of whole decimals now runs, and `IFieldCondition.value()` returns the Integer or Integers. The platform refused the value as it was (`Invalid bind expression type of Decimal for column of type Integer`). A number that is not whole stays as it is, and the platform still refuses it.
- **`lk` on a multi-select picklist is refused when the query is written or run**: `Cannot write LK on Channel: a multi-select picklist takes INC and EXC`, in place of the platform's `invalid operator on multipicklist field`. It still builds, and is still tested in memory.
- **`parseCondition` reads quoted text as text, whatever it looks like.** `BillingPostalCode = '94105'` and `Name = '2026-01-31'` threw, because the text was turned into a number or a date; they parse now. The other way round, a quoted value on a number, date, date-time or checkbox field (`CloseDate = '2026-01-31'`, `NumberOfEmployees = '5'`) used to be read as the date or the number. It is now refused when the condition is built (`CloseDate holds datetime values, so it cannot be compared with string`), as the platform refuses it (`should not be enclosed in quotes`): write such a value without quotes.
- **`parseCondition` keeps a group in brackets as a group.** `(A AND B) AND C` is written back as `((A AND B) AND C)`, where it was flattened to `(A AND B AND C)`. The meaning is the same. For a negated group the meaning changes: see Fixed.
- **A search takes queries made by the framework only.** A query class of your own that implements `IQuery` without extending `Query` or `BaseQuery` is refused when the search is written: `A search needs queries made by the framework`. Its limit and offset used to be read out of its SOQL text.
- **`fields().add(Set<String>)` selects names that go through a polymorphic lookup** (`'What.Type'`, `'Owner.Name'`). Such names used to be skipped without a word, as unknown names are; a query that passed them now selects them.
- `parseCondition` given `IN (SELECT ...)` throws `A subquery at position N cannot be parsed: build a semi-join in code, with iin or nin`, in place of a general `Expected literal` error.
- **`parseCondition` no longer drops what follows a complete condition.** `Name = 'x' ORDER BY Name` parsed as `Name = 'x'`; it now throws `Unexpected ORDER at position 11: the condition is complete before it, and only AND or OR can continue it`. Text without its closing quote throws too; it was read to the end.
- **`parseCondition` reads SOQL's escape sequences in text**: `\'`, `\\`, `\"`, `\n`, `\r`, `\t`, `\b`, `\f`, `\uXXXX`, and `\%` and `\_` for `LIKE`. So it reads back what `toSoql()` writes for a value with a quote or a backslash, which it could not. **Text that holds a backslash before one of those letters now means the character**: `'north\team'` has a tab in it; for a backslash, write `'north\\team'`. A backslash before any other character is kept as it was.
- **A child subquery keeps its limit and offset.** `setLimit` and `setOffset` on a child query were silently left out of the SOQL. They are written now; the platform takes an offset there only when the parent query returns one row, and says so itself.
- **In memory, an empty number, date, date-time or time is neither above nor below a value, and stays out under NOT, as in SOQL.** `neg(gt(Account.AnnualRevenue, 5))` used to match an account with no revenue; SOQL's `NOT (AnnualRevenue > 5)` does not return it, and now `evaluate` does not either. The same holds inside negated groups. `evaluate` still returns `true` or `false`.
- **In memory, `lk` no longer matches an empty field**, not even with `%`, as in SOQL.
- **In memory, Ids match in their exact case, and a 15-character Id matches its 18-character form**, as in SOQL. Before, Ids were compared without regard to case, and the two lengths never matched.
- **In memory, a checkbox compared with `null` is compared with `false`**, as in SOQL: `eq(field, null)` matches the unchecked records. It matched none.
- **In memory, `inc` and `exc` read a value that names several choices as "has them all"**, as in SOQL: `inc(field, new List<String>{ 'A;B' })` matches a record that has both A and B. It matched a record that had either.
- **In memory, `eq`, `ne`, `iin` and `nin` on a multi-select picklist take the choices in any order**, as in SOQL: `'B;A'` equals `'A;B'`. They were compared as text.
- **In memory, `inc` on an empty multi-select picklist is unknown, and stays out under NOT**, as in SOQL: `neg(inc(field, values))` no longer matches a record whose field is empty. `exc` matches it, as before.
- **`toSoql()` writes a `Date` compared with a date-time field as midnight GMT** (`CreatedDate > 2026-01-15T00:00:00.000Z`), which is what the platform makes of the bound value. The bare date it wrote before is not SOQL for such a field. The same goes for a `Date` compared with `min` or `max` of a date-time field in HAVING.

### Fixed

- **`parseCondition` let a negated group take in what followed it.** `NOT (A AND B) AND C` was read as `NOT (A AND B AND C)`, and `NOT (A OR B) OR C` as `NOT (A OR B OR C)`. `NOT` now covers the group it stands before and nothing after the closing bracket. **A condition parsed from such text selects other records than it did.**
- **`parseCondition` read a datetime offset of less than an hour behind GMT with the wrong sign**: `2026-01-31T09:30:00-00:30` was read as 09:00 GMT, and is 10:00 GMT.
- **A search took the limit of an object's query from its SOQL text**, so a filter value such as `'Acme LIMIT 9'` added `LIMIT 9` to the `RETURNING` clause. The limit and offset now come from the query itself.
- **`parseCondition` shifted a datetime written in UTC by the running user's offset**: `2026-01-31T09:30:00Z` was read as 17:30 GMT by a user in Los Angeles. `Z` now means GMT for every user. Datetimes with an explicit offset (`+02:00`) were read correctly and still are.
- `parseCondition` threw a `JSONException` for a list of whole and decimal numbers (`AnnualRevenue IN (0, 10.5)`), and an `Invalid integer` error for a whole number of more than nine digits.
- `iin` or `nin` given `null` in place of a collection threw a `NullPointerException` when the query ran. It is written as the constant test `toSoql()` always showed.
- A condition tree that holds nothing but empty groups threw `Argument cannot be null` from `toSoql()` and from a search. Each empty group is now written as a constant: see Changed.
- `parseCondition(null)` threw a `NullPointerException`; it throws the parser's own exception, as for empty text.
- `toSoql()` wrote a decimal with an exponent when the value carried one (`1.5E+10`), which is not SOQL. Numbers are written in plain digits.

## 0.3.0

Released 2026-11-18 as `Injectify@0.3.0-2`.

The package is now **Injectify**, an unlocked package in the namespace `inj`; this is its first release. Versions up to 0.2.x were built in an earlier package under another namespace, and there is no upgrade path between the two: install Injectify beside the old package, change `unif.` to `inj.` in your code, then uninstall the old one.

### Added

- **A class that extends `BaseQuery` or `BaseDomain` can call what it inherits directly**: `setLimit(100)`, `records()`, `getChangedRecords(oldMap, fields)`, where it had to write `base().setLimit(100)`. Code holding your type can too: `accountQuery.run()`. The methods of `IQuery` and `IDomain` are now `global` on `Query` and `DomainRecords`, the classes the two base classes extend. `base()` still works.
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
- **`withSecurity(true)` works again, and no longer writes `WITH SECURITY_ENFORCED`.** The platform stopped accepting that clause at API version 67, so every query with it failed (`WITH SECURITY_ENFORCED is no longer supported`). The framework now makes the check itself before the query runs: the running user must be able to read the object and every field the `SELECT` names (lookups and subqueries included; in an aggregate query, the fields aggregated and grouped by). Otherwise a `QueryException` names what was refused. Sharing is left alone, as before. `toSoql()` no longer shows the clause.
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
