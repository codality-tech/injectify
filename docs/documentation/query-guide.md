# Query Guide

Queries are built from the same pieces as the rest of the framework: a **model** for each object, **paths** for fields (including fields reached through lookups), and **conditions** that can render as SOQL or test records in memory. This guide covers SOQL queries (`IQuery`), aggregate queries (`IAggregateQuery`) and searches (`ISearchQuery`).

The examples are written as subscriber code: framework types carry the `inj.` namespace, and `App.s` is your org's entry point (see the [README](../../README.md#sixty-second-tour)). Every SOQL string shown was produced by the code above it.

## Contents

1. [Starting a query](#1-starting-a-query)
2. [Selecting fields](#2-selecting-fields)
3. [Conditions](#3-conditions)
4. [Ordering, limit and offset](#4-ordering-limit-and-offset)
5. [Child subqueries](#5-child-subqueries)
6. [Running a query](#6-running-a-query)
7. [Aggregate queries](#7-aggregate-queries)
8. [Searches (SOSL)](#8-searches-sosl)
9. [Custom query classes](#9-custom-query-classes)

---

## 1. Starting a query

There are two ways in:

```apex
// From the query factory: a registered query class if there is one, with default fields.
inj.IQuery accounts = App.s.qf().make(Account.SObjectType);

// From the model: a plain query that selects only Id until you add fields.
inj.IQuery bare = App.s.model(Account.SObjectType).query();
```

`qf().make('Account')` takes the object's API name instead of its token.

### Default fields

`qf().make()` starts from the registered query class's `getDefaultFields()` when the object has one (see [section 9](#9-custom-query-classes)). Otherwise it selects every field of the object except:

- long text areas (text areas over 255 characters);
- formula fields;
- fields with a namespace prefix, from managed packages;
- `LastReferencedDate`, `LastViewedDate`, and fields whose names contain `Preferences` or `Permissions`;
- fields no user can be given access to, such as license-gated fields (Einstein Account Tier, for one).

The defaults are worked out once per object per transaction. To change the rule for every query the factory makes, give it a field scope:

```apex
App.s.qf().defaultFieldScope(inj.FieldScope.make(inj.FieldScope.Trait.CUSTOM));
```

Call `q.fields().clearFields()` to drop the defaults from one query and choose fields yourself. Id is always selected.

Describes run at the package's API version. A field added to the platform in a later API version is invisible until the package moves to that version, unless your scheme (`IScheme`) describes at another one.

### Extra arguments to the factory

`qf().make(token, List<Object>)` builds the query and then applies each extra argument:

| Argument | Effect |
|---|---|
| A lookup field, path or relationship name on this object (`Account.OwnerId`, `'Owner'`) | Adds the parent's default fields through the lookup |
| A child relationship name (`'Contacts'`) or the child's lookup field (`Contact.AccountId`) | Adds a subquery of the child with its default fields |
| `ICondition` | Adds it to the WHERE clause |
| `Set<String>`, `Set<SObjectField>`, `Set<IPath>`, `IFieldScope`, `IQueryFields` | Adds those fields |

```apex
inj.IQuery q = App.s.qf().make(Account.SObjectType, new List<Object>{
  'Contacts',
  App.s.eq(Account.Industry, 'Energy')
});
// ... (SELECT ... FROM Contacts) FROM Account WHERE (Industry = 'Energy')
```

An argument of another type, or a field from another object, throws an exception that says what was expected.

---

## 2. Selecting fields

`q.fields()` returns the query's `IQueryFields`. Every `add` returns it again, so calls chain.

### Fields of the object

```apex
inj.IQuery q = App.s.model(Account.SObjectType).query();
q.fields().add(new Set<SObjectField>{ Account.Name, Account.Industry });
// SELECT Id, Name, Industry FROM Account
```

`add(new Set<String>{ 'Name', 'Industry' })` takes API names instead. Unknown names are skipped, so prefer tokens when you can. `addAll()` selects every field of the object.

### Fields through lookups

The first argument is a **route**: how to get from this object to the one whose fields you want. A route can be:

- a relationship or lookup name, dotted for several steps (`'Account'`, `'AccountId'`, `'Account.Owner'`);
- a lookup field (`Contact.AccountId`);
- a list of lookup fields (`new List<SObjectField>{ Contact.AccountId, Account.OwnerId }`);
- an `IPath`.

```apex
inj.IQuery c = App.s.model(Contact.SObjectType).query();
c.fields().add(new Set<SObjectField>{ Contact.LastName });
c.fields().add('Account', new Set<SObjectField>{ Account.Name });
c.fields().add(new List<SObjectField>{ Contact.AccountId, Account.OwnerId }, new Set<SObjectField>{ User.Email });
c.fields().add(new Set<String>{ 'Account.Industry', 'Owner.Name' });
// SELECT Id, LastName, Account.Name, Account.Industry, Account.Owner.Email, Owner.Name FROM Contact
```

The fields must belong to the object the route leads to; a field of another object throws. `addAll(route)` selects every field there.

### Polymorphic lookups

A lookup that can point at several objects, such as `Task.WhatId` or `Case.OwnerId`, is read in two ways.

**The fields every target has.** For whatever such a lookup points at, the platform keeps a few fields on an object of its own, called `Name`: `Type` (the API name of the object pointed at), `Name`, and for people `FirstName`, `LastName`, `Title`, `Email`, `Phone`, `Alias`, `Username` and `IsActive`, with the lookups `Profile`, `UserRole` and `RecordType`. These are ordinary paths: select them, filter on them, order by them, group by them.

```apex
inj.IQuery t = App.s.model(Task.SObjectType).query();
t.fields().add(new Set<String>{ 'Subject', 'What.Type', 'What.Name', 'Owner.Name' });
t.filters().add(App.s.eq('What.Type', 'Account'));
t.orderings().add(App.s.ordering('What.Name', true, false));
// SELECT Id, Subject, What.Type, What.Name, Owner.Name FROM Task
//   WHERE (What.Type = :a0) ORDER BY What.Name ASC NULLS FIRST
```

With field tokens, the far side of the lookup is the `Name` object, written `Schema.Name` in Apex:

```apex
App.s.eq(new List<SObjectField>{ Task.WhatId, Schema.Name.Type }, 'Account');            // What.Type = 'Account'
t.fields().add(Task.WhatId, new Set<SObjectField>{ Schema.Name.Type, Schema.Name.Name }); // What.Type, What.Name
t.fields().add('Owner', new Set<String>{ 'Name', 'IsActive' });                           // Owner.Name, Owner.IsActive
```

- `Owner.Type` is `User` for a user and `Queue` for a group of any kind: a queue, a public group, the group of all internal users. It is never `Group`.
- Not every field is filled for every target. `Who.Email`, `Who.Phone` and `Who.Title` are empty for a contact and for a lead, though `Who.Name`, `Who.FirstName` and `Who.LastName` are filled; `Owner.Email` is filled for a user.
- A path can go on through the `Name` object's own lookups (`Owner.Profile.Name`), and can come after an ordinary lookup (`Parent.Owner.Name` from a case comment).
- A field of one target does not follow the lookup. `What.Industry` throws `Cannot follow What.Industry from Task: What can point at several objects, and Industry is not a field of them all`. For those, use `TYPEOF`.

**A target's own fields (TYPEOF).** Give the lookup fields of any of its targets. Each target you name fields for gets a `WHEN` branch, and its Id is added:

```apex
inj.IQuery t = App.s.model(Task.SObjectType).query();
t.fields().add(new Set<SObjectField>{ Task.Subject });
t.fields().add(Task.WhatId, new Set<SObjectField>{ Account.Name, Opportunity.Amount });
// SELECT Id, Subject, TYPEOF What WHEN Account THEN Id, Name WHEN Opportunity THEN Id, Amount END FROM Task
```

Use field tokens for these, not names: a name such as `'Industry'` could belong to any of the targets, and names given with a polymorphic lookup are read as fields of the `Name` object.

One `SELECT` reads a lookup as a path or with `TYPEOF`, not both. The platform refuses `What.Name` beside `TYPEOF What` (`TYPEOF operand 'What' and top-level SELECT list element 'What.Name' may not reference the same relationship field`), so the framework refuses it when the SELECT is written: `Cannot select What.Name beside TYPEOF What: one SELECT reads a lookup as a path or with TYPEOF, not both`. A path through one lookup beside `TYPEOF` on another is fine. So is a filter or an ordering on `What.Type` beside `TYPEOF What`, which is the usual pair: filter on the type, select that type's fields.

### Field scopes

An `IFieldScope` selects fields by rule. `FieldScope.make` takes:

| Argument | Selects |
|---|---|
| `FieldScope.Trait.ALL` | every field |
| `Trait.CUSTOM` / `Trait.STANDARD` | custom / standard fields |
| `Trait.NAMESPACED` | custom fields with a namespace prefix |
| `Trait.FORMULA` | formula fields |
| `Trait.OVERSIZE` / `Trait.UNDERSIZE` | text areas over 255 characters / everything else |
| a `String` | API names matching the regular expression (whole name) |
| a `Schema.SOAPType` or `DisplayType` | fields of that type |

Combine them with `FieldScope.any(scopes)` (union), `FieldScope.all(scopes)` (intersection) and `scope.exclude(other)`:

```apex
inj.IQuery scoped = App.s.model(Account.SObjectType).query();
scoped.fields().add(inj.FieldScope.make('Billing.*'));
// SELECT Id, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
//   BillingLatitude, BillingLongitude, BillingGeocodeAccuracy, BillingAddress FROM Account
```

`add(route, scope)` applies a scope to the object a route leads to.

### Fields the other clauses use

`q.addImplicitFields()` selects the fields that the query's conditions and orderings mention, plus the lookups that fields were added through:

```apex
inj.IQuery q = App.s.model(Contact.SObjectType).query();
q.filters().add(App.s.eq(new List<SObjectField>{ Contact.AccountId, Account.Industry }, 'Energy'));
q.orderings().add(App.s.ordering(Contact.LastName, true, false));
q.addImplicitFields();
// SELECT Id, LastName, Account.Industry FROM Contact WHERE (Account.Industry = 'Energy')
//   ORDER BY LastName ASC NULLS FIRST
```

This helps when the records will be tested in memory later: the condition can then read every field it needs.

---

## 3. Conditions

### Building conditions

`App.s` has one method per operator. Each takes a field (or path) and a value:

| Method | SOQL | Value |
|---|---|---|
| `eq` / `ne` | `=` / `!=` | one value, or null |
| `lt` / `le` / `gt` / `ge` | `<` / `<=` / `>` / `>=` | number, date, datetime, time or text |
| `lk` | `LIKE` | pattern with `%` and `_` |
| `iin` / `nin` | `IN` / `NOT IN` | a `Set` or `List`, or a query: a [semi-join or anti-join](#semi-joins-and-anti-joins) |
| `inc` / `exc` | `INCLUDES` / `EXCLUDES` | multi-select picklist values |

On a date or date-time field, every operator but `lk`, `inc` and `exc` also takes a [date literal](#date-literals) such as `inj.DateLiteral.lastNDays(30)`.

Combine conditions with `all` (AND), `any` (OR) and `neg` (NOT):

```apex
inj.ICondition grouped = App.s.all(new List<inj.ICondition>{
  App.s.iin(Account.Industry, new Set<String>{ 'Energy', 'Banking' }),
  App.s.any(new List<inj.ICondition>{
    App.s.gt(Account.AnnualRevenue, 1000000),
    App.s.lk(Account.Name, 'Acme%')
  }),
  App.s.neg(App.s.eq(Account.Type, 'Prospect'))
});
inj.IQuery q = App.s.model(Account.SObjectType).query();
q.filters().add(grouped);
```

`q.toSoql(true)` shows the bound form that `run()` executes:

```
SELECT Id FROM Account WHERE ((Industry IN :a0 AND (AnnualRevenue > :a1 OR Name LIKE :a2) AND (NOT Type = :a3)))
```

and `q.toSoql()` writes the values inline, escaped:

```
SELECT Id FROM Account WHERE ((Industry IN ('Energy', 'Banking') AND (AnnualRevenue > 1000000 OR Name LIKE 'Acme%') AND (NOT Type = 'Prospect')))
```

Also available:
- `cond(Enums.Comparator op, field, value)` picks the operator at run time, and its four-argument form takes a `negated` flag.
- `condId(Set<Id>)` is `Id IN :ids`.
- `condRtdn(Set<String>)` matches record type developer names.

### The field side

The first argument can be:

- a field (`Account.Industry`);
- a list of fields, for a field reached through lookups (`new List<SObjectField>{ Contact.AccountId, Account.Industry }`);
- an `IPath` or `IReference`;
- a field name, which is resolved once the condition joins a query. A name can be dotted through lookups (`'Account.Industry'`), and through a [polymorphic lookup](#polymorphic-lookups) to the fields every target has (`'What.Type'`, `'Owner.Name'`);
- an aggregate function, in a HAVING clause ([section 7](#7-aggregate-queries)).

```apex
inj.IQuery contacts = App.s.model(Contact.SObjectType).query();
contacts.filters().add(App.s.eq(new List<SObjectField>{ Contact.AccountId, Account.Industry }, 'Energy'));
// SELECT Id FROM Contact WHERE (Account.Industry = 'Energy')
```

A value that doesn't fit the field's type throws when the condition is built, with a message such as `Name holds string values, so it cannot be compared with date`.

### Date literals

A date literal is one of SOQL's relative ranges of days: `TODAY`, `THIS_WEEK`, `LAST_N_DAYS:30`, `NEXT_FISCAL_QUARTER`. `inj.DateLiteral` makes them, and one is the value of a condition on a date or date-time field:

```apex
inj.IQuery q = App.s.model(Opportunity.SObjectType).query();
q.filters().add(App.s.eq(Opportunity.StageName, 'Prospecting'));
q.filters().add(App.s.le(Opportunity.CloseDate, inj.DateLiteral.nextNDays(30)));
q.filters().add(App.s.iin(Opportunity.CreatedDate, new List<inj.IDateLiteral>{ inj.DateLiteral.today(), inj.DateLiteral.yesterday() }));
// SELECT Id FROM Opportunity
//   WHERE (StageName = :a0 AND CloseDate <= NEXT_N_DAYS:30 AND CreatedDate IN (TODAY, YESTERDAY))
```

A date literal is written into the SOQL as it is, also when the query runs: the platform takes none as a bind variable. The values around it are bound as usual.

There is a factory for every literal in the SOQL reference:

| | This one, the one before, the one after | The n before, the n after, the one n back |
|---|---|---|
| Days | `today()`, `yesterday()`, `tomorrow()` | `lastNDays(n)`, `nextNDays(n)`, `nDaysAgo(n)`, and `last90Days()`, `next90Days()` |
| Weeks | `thisWeek()`, `lastWeek()`, `nextWeek()` | `lastNWeeks(n)`, `nextNWeeks(n)`, `nWeeksAgo(n)` |
| Months | `thisMonth()`, `lastMonth()`, `nextMonth()` | `lastNMonths(n)`, `nextNMonths(n)`, `nMonthsAgo(n)` |
| Quarters | `thisQuarter()`, `lastQuarter()`, `nextQuarter()` | `lastNQuarters(n)`, `nextNQuarters(n)`, `nQuartersAgo(n)` |
| Years | `thisYear()`, `lastYear()`, `nextYear()` | `lastNYears(n)`, `nextNYears(n)`, `nYearsAgo(n)` |
| Fiscal quarters | `thisFiscalQuarter()`, `lastFiscalQuarter()`, `nextFiscalQuarter()` | `lastNFiscalQuarters(n)`, `nextNFiscalQuarters(n)`, `nFiscalQuartersAgo(n)` |
| Fiscal years | `thisFiscalYear()`, `lastFiscalYear()`, `nextFiscalYear()` | `lastNFiscalYears(n)`, `nextNFiscalYears(n)`, `nFiscalYearsAgo(n)` |

`inj.DateLiteral.of('NEXT_N_FISCAL_QUARTERS:2')` reads one from text, which suits a literal kept in configuration. Case does not matter, nor do spaces around the colon, as in SOQL. Text that is not a date literal throws an `IllegalArgumentException`, as do a number where the literal takes none (`TODAY:3`), no number where it needs one (`LAST_N_DAYS`) and a number below zero.

**What a comparison means.** A date literal is a range, so the operators read differently than with one date. This is SOQL's meaning, and `evaluate` gives the same:

| | Matches |
|---|---|
| `eq` | a day inside the range |
| `ne` | a day outside it, and an empty field |
| `lt` / `le` | a day before the range starts / before it ends |
| `gt` / `ge` | a day after the range ends / from its start on |
| `iin` / `nin` with a list of literals | a day inside one of the ranges / inside none of them (and an empty field) |

- `LAST_N_DAYS:n` and `LAST_90_DAYS` include today; `NEXT_N_DAYS:n` and `NEXT_90_DAYS` start tomorrow.
- A range counted in weeks, months, quarters or years leaves the current one out: `LAST_N_WEEKS:2` is the two whole weeks before this week.
- With a count of 0 the "ago" literals are the current unit (`N_WEEKS_AGO:0` is this week, as is `LAST_N_DAYS:0` for today), and the other counted ranges are empty: nothing equals `NEXT_N_DAYS:0`, and `gt` and `lt` still compare with the day the range would start.
- A range is whole days, for a date-time field too: `CreatedDate = TODAY` takes every moment of today.

**What the framework checks**, when the condition is built (for a field given by name, once it joins a query). Each throws a `ValidationException`:

- the field is a date or a date-time: `Name holds string values, so it cannot be compared with a date literal`;
- the operator is `eq`, `ne`, `lt`, `le`, `gt` or `ge` for one literal, and `iin` or `nin` for a `List<inj.IDateLiteral>`: `IIN takes a list of date literals, not one`. `lk`, `inc` and `exc` take none: `LK does not apply to a date literal`.

A class of your own may implement `inj.IDateLiteral`. Such a literal is read from the text its `toSoql()` gives each time it is used, in WHERE and in HAVING, so text that is not a date literal never reaches a query: it throws the `IllegalArgumentException` that `of` throws.

**The platform's rules**, checked at API version 68.0:

| Rule | What the platform does |
|---|---|
| Every literal goes with a date field and with a date-time field, and with no other | `value of filter criterion for field 'Name' must be of type string and should be enclosed in quotes` |
| A literal cannot be bound | `Invalid bind expression type of String for column of type Date` |
| `IN` and `NOT IN` take a list of literals, but not a list that mixes literals and dates | ends the transaction with an error no code can catch (`cannot mix special dates and regular dates in one IN condition`). The builders take a `List<IDateLiteral>`, so they cannot write such a list, and the parser refuses one |
| The count is a whole number from 0 to 365000, whatever the unit | `Date formula too large` for 365001 and up |
| The range lies within the years the platform's dates cover: with today in 2026, `LAST_N_YEARS:12024` and `NEXT_N_YEARS:7972` run | `Invalid date` for one more of either |
| `HAVING` takes a literal against `MIN` or `MAX` of a date, and against a grouped date field | runs |
| A search's `RETURNING` filters, a child subquery's and the inner query's of a semi-join take them too | runs |

**In memory.** `evaluate` works the range out for the running user, as the database does:

- **Today** is today in the running user's time zone, and a date-time is read as the day it falls on in that zone. A record created at 23:30 in the user's zone was created today, whatever the day is in GMT.
- **A week** starts on the first day of the week of the running user's locale: Sunday in `en_US`, Monday in `en_GB`.
- **An empty field** matches `ne` and `nin`, and nothing else, not even under `neg`: SOQL leaves a row with no close date out of `NOT (CloseDate = TODAY)`, and so does `evaluate`. See [Testing records in memory](#testing-records-in-memory).
- **Fiscal literals** follow the organization's fiscal year. For a standard fiscal year, which starts on the first day of a month chosen in Setup and has quarters of three months, the range is worked out from that month. The first fiscal literal evaluated in a transaction costs two queries: one to see that the organization has no custom fiscal years, one for the start month. They go through the scheme of the object the condition is on, like every query of the framework, so a `MockScheme` answers them with the `Organization` and `FiscalYearSettings` rows you register. An organization with custom fiscal years gets a `ConditionException` instead (`Cannot evaluate a fiscal date literal in memory: the organization has custom fiscal years`), since only the database knows its periods: filter such records with a query.
- **A count above 365000** is refused with a `ConditionException` (`Cannot evaluate LAST_N_DAYS:365001 in memory: the count is over 365000`), as the platform refuses it. Up to there the range is worked out by the calendar. The platform's own answers stop following the calendar for a range that starts thousands of years back: a task dated today is `>= LAST_N_WEEKS:200000` and is not `>= LAST_N_WEEKS:300000`.

### Semi-joins and anti-joins

Give `iin` or `nin` a query instead of a list, and the condition matches the field against the rows of that query: `Id IN (SELECT ...)` is a semi-join, `Id NOT IN (SELECT ...)` an anti-join. The database does the matching, so no Ids pass through Apex.

```apex
// The inner query: the accounts of contacts in Seattle
inj.IQuery inSeattle = App.s.model(Contact.SObjectType).query();
inSeattle.fields().add(new Set<SObjectField>{ Contact.AccountId });
inSeattle.filters().add(App.s.eq(Contact.MailingCity, 'Seattle'));

inj.IQuery accounts = App.s.model(Account.SObjectType).query();
accounts.fields().add(new Set<SObjectField>{ Account.Name });
accounts.filters().add(App.s.eq(Account.Industry, 'Energy'));
accounts.filters().add(App.s.iin(Account.Id, inSeattle));
// SELECT Id, Name FROM Account
//   WHERE (Industry = :a0 AND Id IN (SELECT AccountId FROM Contact WHERE (MailingCity = :a1)))

inj.IQuery elsewhere = App.s.model(Account.SObjectType).query();
elsewhere.filters().add(App.s.nin(Account.Id, inSeattle));
// SELECT Id FROM Account WHERE (Id NOT IN (SELECT AccountId FROM Contact WHERE (MailingCity = :a0)))
```

The inner query's values are bound together with the outer query's when it runs, and `toSoql()` writes them inline, escaped, like any other value. (`inner` and `outer` are reserved words in Apex, so the variables need other names.)

**The field the inner query selects.** An inner query selects one field, and the framework works out which from the fields you chose:

- **no field chosen:** its `Id`;
- **one lookup field chosen:** that field (a query always selects `Id` as well; here it is left out).

```apex
inj.IQuery energy = App.s.model(Account.SObjectType).query();
energy.filters().add(App.s.eq(Account.Industry, 'Energy'));

inj.IQuery theirContacts = App.s.model(Contact.SObjectType).query();
theirContacts.filters().add(App.s.iin(Contact.AccountId, energy));
// SELECT Id FROM Contact WHERE (AccountId IN (SELECT Id FROM Account WHERE (Industry = :a0)))
```

A query from the factory starts with its default fields, so clear them first:

```apex
inj.IQuery contacts = App.s.qf().make(Contact.SObjectType);
contacts.fields().clearFields().add(new Set<SObjectField>{ Contact.AccountId });
```

Anything else is refused when the outer query is written or run: two or more fields besides `Id`, a field that is not a lookup, fields through a lookup, a child subquery, a limit or an offset. The message says which, for example `Cannot use the query on Contact in a semi-join: it selects 62 fields besides Id`. Call `fields().clearFields()` on such a query, then add the one lookup field to match, or none to match its Id.

**What the framework checks, and when.**

| | Checked | Thrown |
|---|---|---|
| The value is a query, and the operator is not `IN` or `NOT IN` | when the condition is built | `ConditionException` |
| The field on the left is not an `Id` or a lookup field | when the condition is built (for a field given by name, once it joins a query) | `ConditionException` |
| The inner query does not select one `Id` or lookup field, or has a limit, an offset or `allRows(true)` | when the outer query is written or run | `UnifValidationException` |
| A semi-join inside the inner query of another | when the outer query is written or run | `UnifValidationException` |
| A semi-join in `HAVING`, on an aggregate function | when the condition is built | `ConditionException` |
| A semi-join in `HAVING`, on a field | when the aggregate query is written or run | `ConditionException` |

**What the inner query keeps.** Its object, its one field, its conditions and its scope (`usingScope`). Its ordering is left out, since the platform takes none there and it could not change the result. `withSharing`, `withSecurity`, `forUpdate`, `forView` and `forReference` on the inner query are not used: the outer query decides (see [Security](#security)). `allRows(true)` on the inner query is refused, since the platform takes `ALL ROWS` on the outer query only: ask for it there. The condition holds the query you gave it, not a copy, so a condition added to the inner query later is part of the semi-join.

**The platform's rules.** The platform has rules of its own for semi-joins. The framework leaves these to it: the query is written as you built it, and the platform refuses it with a `QueryException` when it runs. Each was checked against the platform at API version 68.0:

| Rule | The platform's message |
|---|---|
| At most two semi-joins or anti-joins in one query, counted together. One in a child subquery is not counted with the outer query's | `Maximum 2 semi join sub-selects are allowed` |
| Not under `OR` (`any`). Beside an OR group is fine: `(A OR B) AND Id IN (...)` | `Semi join sub-selects are not allowed with the 'OR' operator` |
| Not inside `NOT` (`neg`). For the opposite, use `nin` | `'NOT' operator cannot be combined with semi/anti join subqueries` |
| At the top of the WHERE clause: add the condition to `filters()` itself, not to an `all` group that sits beside other conditions | `Semi join sub-selects are only allowed at the top level WHERE expressions and not in nested WHERE expressions.` |
| The field on the left belongs to the queried object: no path through a lookup (`Account.OwnerId` from a contact) | `The left operand 'Account.OwnerId' cannot have more than one level of relationships` |
| The inner and outer queries are on different objects | `The inner and outer selects should not be on the same object type` |
| The two fields point at the same object: `Id` of an account matches a lookup to accounts | `The selected field 'Id' in the subquery and the left operand field in the where expression in the outer query 'Id' should point to the same object type` |
| `Task` and `Event` cannot be the inner object | `Entity 'Task' is not supported for semi join inner selects` |

The platform takes these as well:

- A lookup to several objects works on the left (`Task.WhatId` against account Ids) and as the inner field (`Case.OwnerId` against user Ids).
- The inner query's own WHERE clause takes `OR`, `NOT`, groups and fields through lookups as usual.
- A row whose inner field is empty rules nothing out of an anti-join: accounts are not lost because one contact has no account. An anti-join on a lookup field also returns the rows where that lookup is empty.
- A child subquery's conditions take a semi-join too (see [section 5](#5-child-subqueries)), as do `count()`, `toLocator()`, [aggregate queries](#7-aggregate-queries) in WHERE, and [searches](#8-searches-sosl).

**Not from text, not in memory.** A semi-join is built in code. `parseCondition` refuses `IN (SELECT ...)` with `A subquery at position 7 cannot be parsed: build a semi-join in code, with iin or nin`. And `evaluate` cannot test a record against a query it has not run, so it throws a `ConditionException` (`Cannot evaluate a semi-join in memory: its inner query has not been run`): run the inner query yourself and match on its Ids with an ordinary `iin`.

### Parsing conditions from text

`model.parseCondition(text)` reads a SOQL-style WHERE expression. It suits conditions stored in configuration or entered by an admin. The result is the same condition object the builders make:

```apex
inj.ICondition parsed = App.s.model(Account.SObjectType).parseCondition(
  'Industry IN (\'Energy\', \'Banking\') AND (AnnualRevenue > 1000000 OR Name LIKE \'Acme%\') AND NOT (Type = \'Prospect\')'
);
```

This renders exactly like `grouped` above. The parser accepts:

| | |
|---|---|
| Operators | `=`, `!=`, `<`, `<=`, `>`, `>=`, `LIKE`, `IN`, `NOT IN`, `INCLUDES`, `EXCLUDES` (`<>` is not supported; use `!=`) |
| Logic | `AND`, `OR`, `NOT`, parentheses |
| Fields | API names, dotted through lookups (`Account.Owner.Name`), polymorphic ones included (`What.Type`) |
| Values | `'text'`, numbers, dates (`2026-01-31`), datetimes with their zone (`2026-01-31T09:30:00Z`, `2026-01-31T09:30:00+02:00`), times of day (`09:30:00.000Z`), [date literals](#date-literals) (`TODAY`, `LAST_N_DAYS:30`), `TRUE`, `FALSE`, `NULL`, and parenthesized lists for `IN` |

So `CloseDate >= LAST_N_DAYS:30 AND What.Type = 'Account'` parses, and what `toSoql()` writes for a condition, `parseCondition` reads back. The one exception is a [semi-join](#semi-joins-and-anti-joins), which is not read from text.

- **Quoted text is text**, whatever it looks like: `BillingPostalCode = '94105'` and `Name = '2026-01-31'` compare with those characters. So a number, a date, a date-time, a time or `TRUE` goes without quotes. `CloseDate = '2026-01-31'` is refused when the condition is built (`CloseDate holds datetime values, so it cannot be compared with string`), as the platform refuses it (`value of filter criterion for field 'CloseDate' must be of type date and should not be enclosed in quotes`).
- **Text** takes SOQL's escape sequences: `\'` for a quote, `\\` for a backslash, `\"`, `\n`, `\r`, `\t`, `\b`, `\f` and `\u00e9` for a character by its code. `\%` and `\_` are kept for `LIKE`, where they mean the characters themselves. A quote may also be doubled (`'O''Brien'`), which SOQL itself does not take.
- **`NOT`** covers the condition or the bracketed group that follows it, and nothing after that: `NOT (A AND B) AND C` is `(NOT (A AND B)) AND C`. SOQL itself wants those outer brackets written; the parser does not. `NOT NOT A` is `A`. A group in brackets stays a group: `(A AND B) AND C` is written back as `((A AND B) AND C)`.
- **A date literal** may have spaces around its colon (`LAST_N_DAYS : 30`), as in SOQL.
- **A list** holds values or date literals, not both: `CloseDate IN (TODAY, 2026-01-01)` is refused, as the platform refuses it.
- **Numbers** in one list may be whole and decimal: `AnnualRevenue IN (0, 10.5)`.

A malformed expression throws an exception that gives the position, such as `Expected literal at position 7, got EOF`. Text after a complete condition is an error too, and is not dropped: `Name = 'x' ORDER BY Name` throws `Unexpected ORDER at position 11: the condition is complete before it, and only AND or OR can continue it`. Text that never closes its quote throws `The text that starts at position 7 has no closing quote`. A subquery (`IN (SELECT ...)`) is not parsed: a [semi-join](#semi-joins-and-anti-joins) is built in code, and the exception says so.

### Testing records in memory

Every condition can test records without a query, and is written to give the answer the database gives:

```apex
Account big = new Account(Name = 'Acme Energy', Industry = 'Energy', AnnualRevenue = 2000000, Type = 'Customer');
Account small = new Account(Name = 'Beta', Industry = 'Energy', AnnualRevenue = 10, Type = 'Customer');
parsed.evaluate(big);   // true
parsed.evaluate(small); // false
```

Fields read through lookups need the related record on the record you test:

```apex
Contact c = new Contact(LastName = 'X', Account = new Account(Industry = 'Energy'));
App.s.eq(new List<SObjectField>{ Contact.AccountId, Account.Industry }, 'Energy').evaluate(c); // true
```

An unloaded parent reads as null. To filter a list of records, use a domain's `filter(condition)` (see the [extension guide](extension-guide.md)). A condition that a queueable job carries is written and tested the same when the job runs.

**What "the same answer" covers.** The package's tests run each of these rules both ways, as a query and in memory, on the same records:

| | In memory, as in SOQL |
|---|---|
| Text | compared without regard to case by every operator, the ordering ones included (`'beta' > 'B'`). An empty text field reads as `''`: it equals `null`, and comes before any text |
| `lk` | `%` is any run of characters, `_` exactly one, `\%` and `\_` the characters themselves; case is ignored. An empty field matches no pattern, not even `%` |
| Numbers, dates, date-times | an empty field equals `null`, is `ne` any value, and is in no list. It is neither above nor below a value: see *Unknown*, below |
| Checkboxes | never empty. `null` on the right reads as `false`: `eq(field, null)` matches the unchecked |
| Ids | matched in their exact case, and the 15-character form matches the 18-character form |
| Times of day | compared as numbers are, by every operator |
| `iin` / `nin` | with an empty collection, never true / always true |
| `all` / `any` with no members | always true / never true, written `(Id = null OR Id != null)` / `(Id = null AND Id != null)`, and on `COUNT(Id)` in HAVING. The root of a query, `filters()`, writes no WHERE while it has no members |
| `neg` | reverses the condition it is given, so `neg(neg(c))` is `c` again |
| `inc` / `exc` | the values are alternatives, matched without regard to case. One value may name several choices (`'Email;Phone'`), and then the field must have them all. An empty field excludes every value; whether it includes one is unknown: see *Unknown*, below |
| Multi-select picklists | `eq`, `ne`, `iin` and `nin` take the choices in any order: `'Phone;Email'` equals `'Email;Phone'` |
| Whole numbers on an integer field | a `Decimal`, `Double` or `Long` that is whole is held as an `Integer`, which is the one type the platform takes there: `eq(Account.NumberOfEmployees, 5.0)` runs |
| [Date literals](#date-literals) | the same range of days, in the running user's time zone and locale |
| Lookups in a path | a parent that is not there reads as empty fields |
| A [polymorphic lookup](#polymorphic-lookups) in a path | read from what the record carries. A row a query returned for `What.Type` has it. A row from `TYPEOF`, or one put on the record in code, gives its own type, and the fields and lookups it has under the same names (`Owner.Profile.Name` from a user with its profile). With the Id alone (a record in a trigger), `Type` and `Id` are read from the Id and the rest is empty. A group, by its row or by its Id, is `Queue` |

**Unknown.** SOQL cannot say whether an empty number, date or date-time is above or below a value, and it leaves such a row out *whether or not the condition is negated*: `NOT (AnnualRevenue > 5)` does not return the accounts with no revenue. `evaluate` follows it:

- `lt`, `le`, `gt` and `ge` on an empty number, date, date-time or time are unknown, and so is every comparison of an empty date with a date literal except `ne` and `nin`;
- `inc` on an empty multi-select picklist is unknown: `NOT (Channel INCLUDES ('Email'))` does not return the rows whose channel is empty;
- `lt`, `le`, `gt`, `ge` and `lk` with a `null` value are unknown for every record (a query refuses to write them: see below);
- an `all` with an unknown member and no false one is unknown; an `any` with an unknown member and no true one is unknown; `neg` of unknown stays unknown;
- `evaluate` answers `false` for unknown.

Equality and membership always have an answer, and so has every comparison of text with a value, since empty text is `''`.

**Where the two differ, or one of them refuses.**

- **A condition on an aggregate function** (a HAVING condition) and a **[semi-join or anti-join](#semi-joins-and-anti-joins)** cannot be tested in memory, and throw a `ConditionException` if you try: the inner query of a semi-join would have to be run first.
- **A `null` value with `lt`, `le`, `gt`, `ge` or `lk`** is not SOQL: written inline the platform refuses it (`invalid operator`), and bound it runs with answers that follow no rule. The framework refuses it when the query is written or run, either way: `Cannot compare AnnualRevenue with null by GT: null goes with EQ and NE`. In memory it throws nothing and is unknown. Compare with `eq(field, null)` or `ne(field, null)` instead.
- **A value of a neighbouring type**: a `Datetime` compared with a date field, or a number that is not whole with an integer field, builds and evaluates, but the platform refuses the query (`Invalid bind expression type of Datetime for column of type Date`). A `Date` compared with a date-time field does run: it is midnight GMT, in a query and in memory. So does a whole number of another type compared with an integer field.
- **`lk` on a multi-select picklist** builds and evaluates, but is not SOQL (`invalid operator on multipicklist field`). The framework refuses it when the query is written or run: `Cannot write LK on Channel: a multi-select picklist takes INC and EXC`.
- **A fiscal date literal** in an organization with custom fiscal years, and a date literal with a count above 365000, throw a `ConditionException` in memory (see [Date literals](#date-literals)).
- **A record a query returned without a field the condition reads** throws the platform's `SObjectException` (`SObject row was retrieved via SOQL without querying the requested field`). `q.addImplicitFields()` selects what the query's own conditions read. A record built in code reads a field it was not given as empty.

### Reusing a condition through a relationship

`prepend(reference)` returns a copy of a condition that starts one relationship further out, and leaves the original unchanged:

```apex
inj.ICondition energy = App.s.eq(Account.Industry, 'Energy');
inj.ICondition contactsOfEnergy = energy.prepend(App.s.reference(Contact.AccountId));

inj.IQuery q = App.s.model(Contact.SObjectType).query();
q.filters().add(contactsOfEnergy);
// SELECT Id FROM Contact WHERE (Account.Industry = 'Energy')
```

A semi-join can be moved this way as well, but the platform then refuses the query: the field on the left of a semi-join cannot go through a lookup.

### The WHERE clause

`q.filters()` is the query's root condition, an AND that starts empty. Use `filters().add(...)` or `q.addCondition(...)`; to start over, use `filters().clear()`. While the root has no members the query writes no WHERE.

`condition.toSoql()` writes one condition on its own, with its values inline. For a group it is the bracketed text of its members, and for a group with no members the constant that stands for it: `App.s.any(new List<inj.ICondition>())`, once it is bound to an object, writes `(Id = null AND Id != null)`. It never returns null.

---

## 4. Ordering, limit and offset

```apex
q.orderings().add(App.s.ordering(Account.Name, false, true)); // route, ascending?, nulls last?
q.setLimit(10).setOffset(5);
// ... ORDER BY Name DESC NULLS LAST LIMIT 10 OFFSET 5
```

`ordering` takes any route a condition does, so `App.s.ordering(new List<SObjectField>{ Contact.AccountId, Account.Name }, true, false)` orders by the parent's name, and `App.s.ordering('What.Type', true, false)` by the type a [polymorphic lookup](#polymorphic-lookups) points at. A limit or offset of 0 or null means none.

The same `IOrdering` can sort records in memory with `ordering.apply(records)`. The sort is stable, and nulls go first or last as asked, as in SOQL.

---

## 5. Child subqueries

Build the child query as usual and attach it by relationship name or by the child's lookup field:

```apex
inj.IQuery kids = App.s.model(Contact.SObjectType).query();
kids.fields().add(new Set<SObjectField>{ Contact.LastName });
kids.filters().add(App.s.ne(Contact.Email, null));

inj.IQuery parents = App.s.model(Account.SObjectType).query();
parents.fields().add(new Set<SObjectField>{ Account.Name });
parents.addSubquery('Contacts', kids);          // or addSubquery(Contact.AccountId, kids)
// SELECT Id, Name, (SELECT Id, LastName FROM Contacts WHERE (Email != :a0)) FROM Account
```

The child's conditions are bound along with the parent's. `getSubqueryMap()` returns the subqueries by relationship name.

A child subquery keeps its ordering, its limit and its offset:

```apex
kids.orderings().add(App.s.ordering(Contact.LastName, true, false));
kids.setLimit(2);
// SELECT Id, Name, (SELECT Id, LastName FROM Contacts WHERE (Email != :a0) ORDER BY LastName ASC NULLS FIRST LIMIT 2) FROM Account
```

- The platform takes an **offset** in a child subquery only when the parent query returns one row, which `fetch()` and `setLimit(1)` on the parent see to. Otherwise it refuses the query: `SOQL OFFSET clause may not appear in a sub-query where the parent query retrieves more than one record`.
- A child takes no `ALL ROWS` and no `USING SCOPE` (the platform refuses both there), so `allRows(true)` or `usingScope(...)` on a child is refused when the parent query is written or run: `Cannot write ALL ROWS in the subquery on Contacts: it belongs to the parent query`. See [Deleted records, scopes and view marks](#deleted-records-scopes-and-view-marks).
- `forUpdate`, `forView`, `forReference`, `withSharing` and `withSecurity` on a child are not used: the parent query decides.

A child subquery's conditions can hold a [semi-join](#semi-joins-and-anti-joins) of their own:

```apex
inj.IQuery cases = App.s.model(Case.SObjectType).query();
cases.fields().add(new Set<SObjectField>{ Case.ContactId });
cases.filters().add(App.s.eq(Case.Status, 'New'));

inj.IQuery kids = App.s.model(Contact.SObjectType).query();
kids.filters().add(App.s.iin(Contact.Id, cases));

inj.IQuery parents = App.s.model(Account.SObjectType).query().addSubquery('Contacts', kids);
// SELECT Id, (SELECT Id FROM Contacts WHERE (Id IN (SELECT ContactId FROM Case WHERE (Status = :a0)))) FROM Account
```

A child subquery lists the children of each row. A semi-join does not return the inner rows: it only decides which outer rows come back.

---

## 6. Running a query

| Method | Returns |
|---|---|
| `run()` | the rows |
| `fetch()` | the first row, or null |
| `fetch(n)` | at most `n` rows, whatever the query's own limit |
| `count()` | `SELECT COUNT()` with the same WHERE clause |
| `toLocator()` | a `Database.QueryLocator`, for a batch job's `start` |
| `toSoql(true)` / `toSoql()` | the SOQL, bound / with values inline |

### Bound values

`run()`, `fetch()`, `count()` and `toLocator()` pass condition values as bind variables (`:a0`, `:a1`…), so no value becomes part of the SOQL text. `toSoql()` is for logs and display. It escapes the values it writes, but it is not what runs.

### Security

Queries run in **system mode** by default: the framework asks for it on every query, whatever the API version of your class.

- `withSharing(true)` runs the query in **user mode**: sharing rules, object permissions and field-level security all apply. Despite its name it is the whole of user mode, not sharing alone. A user with no access to the object gets a `QueryException`.
  - A field you add yourself that the user can't read makes the query fail with a `QueryException`.
  - A **default field** the user can't read is left out instead, so a query from the factory runs for any user who can read the object. That covers the fields the factory added (the trimmed default set, or your class's `getDefaultFields()`), in the query and in its subqueries. A field that is both a default and added by name counts as a default.
  - The inner query of a [semi-join](#semi-joins-and-anti-joins) is read in the mode of the query it filters, whatever its own setting. In user mode the user needs access to the inner object as well, or the platform refuses the query.
  - `toSoql()` shows the query as it would run for the current user.
- In system mode, **sharing follows the class that builds the query**, as it does for a query written in that class: built in a class declared `without sharing` it reads every record, and built in one declared `with sharing` it reads the records the running user can see.
  - The application's scheme is the class that runs every query. A scheme with a sharing keyword of its own overrides the builder's: through a scheme declared `without sharing`, a query reads every record even when a `with sharing` class built it. The scheme the package uses when you give none inherits, so it never overrides.
  - User mode applies sharing whatever the scheme and whoever built the query.
- `withSecurity(true)` checks **read permissions only, and leaves sharing as it is**. Before the query runs, the framework checks that the running user may read the object and every field the `SELECT` names: its own fields, fields reached through lookups, the lookup fields themselves, the fields of subqueries, and what the inner query of a semi-join selects. In an aggregate query it checks the fields aggregated and grouped by. If any is not readable the query is not run, and a `QueryException` names what was refused:

```apex
IQuery q = App.s.model(Account.SObjectType).query().withSecurity(true);
q.fields().add(new Set<SObjectField>{ Account.Name, Account.Rating });
q.run();
// System.QueryException: Insufficient permissions: the running user cannot read Account.Rating
```

  - It does not check the fields in `WHERE` or `ORDER BY`; user mode does.
  - `count()` checks the object alone, since it names no field.
  - For a [semi-join or anti-join](#semi-joins-and-anti-joins) it checks the inner query's object and the one field it selects, in `count()` and in aggregate queries too. The fields in the inner query's own `WHERE` are not checked, as in the outer query.
  - A search (`ISearchQuery`) does not apply it; use `withSharing(true)` on its queries.
  - It writes nothing into the SOQL. Up to API version 66 it added `WITH SECURITY_ENFORCED`; the platform no longer accepts that clause, so the framework makes the same check itself.

### Locking rows

`forUpdate(true)` adds `FOR UPDATE`: the rows the query returns stay locked until the transaction ends, so nothing else can change them between your read and your write.

```apex
inj.IQuery parents = App.s.model(Account.SObjectType).query().forUpdate(true);
parents.addCondition(App.s.condId(accountIds));
// SELECT Id FROM Account WHERE (Id IN :a0) FOR UPDATE
```

- It applies to `run()` and `fetch()`. `count()` and `toLocator()` leave it out, since a count returns no rows and a locator cannot lock.
- The platform refuses `FOR UPDATE` together with `ORDER BY`: the query throws a `QueryException`.

### Deleted records, scopes and view marks

Four more options sit on the query beside `forUpdate`. Each takes `true` or `false` (`usingScope` takes a scope, or `null` for none), and `toSoql()` shows them.

| Option | Adds | `run()`, `fetch()` | `count()` | `toLocator()` |
|---|---|---|---|---|
| `allRows(true)` | `ALL ROWS`, at the very end | yes | yes | yes |
| `usingScope(inj.Enums.FilterScope.MINE)` | `USING SCOPE mine`, after `FROM` | yes | yes | yes |
| `forView(true)` | `FOR VIEW`, after `LIMIT` and `OFFSET` | yes | left out | yes |
| `forReference(true)` | `FOR REFERENCE`, in the same place | yes | left out | yes |
| `forUpdate(true)` | `FOR UPDATE`, after those two | yes | left out | left out |

```apex
inj.IQuery mine = App.s.model(Account.SObjectType).query()
  .usingScope(inj.Enums.FilterScope.MINE)
  .allRows(true)
  .forView(true)
  .setLimit(10);
mine.addCondition(App.s.eq(Account.Industry, 'Energy'));
// SELECT Id FROM Account USING SCOPE mine WHERE (Industry = :a0) LIMIT 10 FOR VIEW ALL ROWS
```

- **`allRows`** reads the records in the recycle bin, and archived activities, as well. Add `App.s.eq(Account.IsDeleted, true)` for the deleted ones alone.
- **`usingScope`** narrows the records to a scope the platform knows. `inj.Enums.FilterScope` has the ones the SOQL reference lists: `DELEGATED`, `EVERYTHING`, `MINE`, `MINE_AND_MY_GROUPS`, `MY_TERRITORY`, `MY_TEAM_TERRITORY`, `SCOPING_RULE` and `TEAM`. (It is not `inj.Enums.SearchScope`, which names the fields a search looks in.)
- **`forView`** marks the records returned as viewed by the running user: it sets `LastViewedDate` and `LastReferencedDate`. **`forReference`** sets `LastReferencedDate` alone. Either way the records show among the user's `RecentlyViewed`. A count returns no records, so it marks none, and the records of a child subquery are not marked either. In a test a record has both dates from the moment it is inserted, so the marks show only outside tests.

**An object supports only some scopes, and the platform does not refuse the others politely.** For a scope the queried object does not support, it ends the transaction with an error no code can catch (`System.UnexpectedException: Invalid query scope: delegated`). Apex has no call that lists an object's scopes (the REST describe of the object does, as `supportedScopes`), so the framework cannot check for you. In an org without territories, `Account` takes `EVERYTHING`, `MINE`, `TEAM` and `SCOPING_RULE` and ends the transaction for the other four; `Task` takes `DELEGATED`, `MINE` and `TEAM`; `MINE_AND_MY_GROUPS` runs on `ProcessInstanceWorkitem` and ends the transaction on `Account` and `Case`.

**What the framework checks.** Each is refused with a `UnifValidationException` when the query is written or run, in place of the platform's `unexpected token`:

| | |
|---|---|
| `forView(true)` together with `forReference(true)` | `Cannot write FOR VIEW with FOR REFERENCE on Account: a query takes one or the other` |
| `forUpdate(true)` together with `allRows(true)`, where the lock is written (`run()`, `fetch()`, `toSoql()`) | `Cannot write FOR UPDATE with ALL ROWS on Account: a query takes one or the other` |
| `allRows(true)` or `usingScope(...)` on a [child subquery](#5-child-subqueries) | `Cannot write ALL ROWS in the subquery on Contacts: it belongs to the parent query` |
| `allRows(true)` on the inner query of a [semi-join](#semi-joins-and-anti-joins) | `Cannot use the query on Contact in a semi-join: it asks for ALL ROWS` |

**The platform's rules**, checked at API version 68.0, which the framework leaves to it:

| Rule | What the platform does |
|---|---|
| `FOR UPDATE` with `ORDER BY` | `Explicit ORDER BY not allowed when locking rows (Id order is implied)` |
| `FOR UPDATE` with `OFFSET` | `FOR UPDATE cannot be used in conjunction with the OFFSET clause` |
| `FOR VIEW` or `FOR REFERENCE` with `FOR UPDATE` | runs |
| `USING SCOPE` with any of the others, and in the inner query of a semi-join | runs |
| `USING SCOPE` on a query that has a child subquery | runs (the SOQL reference says it does not) |
| A scope the object does not support | ends the transaction, as above |

### Copies

`q.deepClone()` copies the fields, subqueries, conditions and options, so conditions added to the copy don't touch the original. The inner queries of its semi-joins are copied too. `condition.clone(true)` does the same for one condition.

### Testing

Every query runs through the application's scheme (`IScheme`). In tests, build the application with a `inj.MockScheme` to return rows you choose, without inserting data, and to see the SOQL and bind values each query ran. See the [testing guide](testing-guide.md#mocking-queries-with-mockscheme).

---

## 7. Aggregate queries

Start from the model:

```apex
inj.IAggregateQuery agg = App.s.model(Opportunity.SObjectType).aggregateQuery();
agg.aggregates().add(App.s.sum(Opportunity.Amount));
agg.aggregates().add(App.s.count(Opportunity.Id));
agg.groupBys().add(App.s.path(Opportunity.StageName));
agg.filters().add(App.s.eq(Opportunity.IsClosed, false));
agg.havingFilters().add(App.s.gt(App.s.sum(Opportunity.Amount), 100000));
agg.orderings().add(App.s.ordering(Opportunity.StageName, true, false));

List<AggregateResult> rows = agg.run();
// SELECT StageName, SUM(Amount) Amount_sum, COUNT(Id) Id_cnt FROM Opportunity
//   WHERE (IsClosed = :a0) GROUP BY StageName HAVING (SUM(Amount) > :a1) ORDER BY StageName ASC NULLS FIRST
```

The functions are `count`, `countDistinct`, `sum`, `avg`, `min` and `max`. Each function gets an alias of the field name plus a suffix, which is how you read it from a row (`rows[0].get('Amount_sum')`):

| Function | Alias |
|---|---|
| `count(field)` / `count(null)` (rows, written `COUNT(Id)`) | `Field_cnt` / `cnt` |
| `countDistinct` | `Field_dis` |
| `sum`, `avg`, `min`, `max` | `Field_sum`, `Field_avg`, `Field_min`, `Field_max` |

`setAlias('total')` overrides an alias.

`aggregate(function, field)` chooses the function at run time, as `cond` chooses a comparison. It suits a function named in configuration:

```apex
inj.Enums.Aggregate chosen = inj.Enums.Aggregate.valueOf('SUM');
agg.aggregates().add(App.s.aggregate(chosen, Opportunity.Amount)); // the same as App.s.sum(Opportunity.Amount)
```

The values are `COUNT`, `COUNT_DISTINCT`, `SUM`, `AVG`, `MIN` and `MAX`.

`rollup()` and `cube()` add subtotal rows, for at most three grouped fields. Each grouped field also gets a `GROUPING()` column named `Field_grp`.

WHERE and HAVING values are bound when the query runs, as in `IQuery`. `withSharing` and `withSecurity` work the same way too.

`filters()` takes a [semi-join or anti-join](#semi-joins-and-anti-joins), and its values are bound with the rest:

```apex
inj.IAggregateQuery byIndustry = App.s.model(Account.SObjectType).aggregateQuery();
byIndustry.aggregates().add(App.s.count(Account.Id));
byIndustry.groupBys().add(App.s.path(Account.Industry));
byIndustry.filters().add(App.s.iin(Account.Id, inSeattle)); // the inner query from section 3
// SELECT Industry, COUNT(Id) Id_cnt FROM Account
//   WHERE (Id IN (SELECT AccountId FROM Contact WHERE (MailingCity = :a0))) GROUP BY Industry
```

`havingFilters()` does not: the platform refuses a semi-join in HAVING, so the framework throws a `ConditionException` before the query is sent: `Cannot write a semi-join in HAVING: it belongs in filters()`.

A [date literal](#date-literals) goes in `filters()` and in `havingFilters()`, written as it is in both:

```apex
agg.filters().add(App.s.ge(Opportunity.CloseDate, inj.DateLiteral.lastNYears(1)));
agg.havingFilters().add(App.s.le(App.s.max(Opportunity.CloseDate), inj.DateLiteral.nextNDays(30)));
// ... WHERE (CloseDate >= LAST_N_YEARS:1) GROUP BY StageName HAVING (MAX(CloseDate) <= NEXT_N_DAYS:30)
```

HAVING compares an aggregate function with one value: a list of date literals is refused when the condition is built, and a `null` goes with `eq` and `ne` only. A `Date` compared with `min` or `max` of a date-time field is written as midnight GMT, as it is for the field itself: `HAVING (MAX(CreatedDate) > 2026-01-15T00:00:00.000Z)`.

An aggregate query takes two of the [statement options](#deleted-records-scopes-and-view-marks): `allRows(true)` counts the recycle bin too, and `usingScope(...)` narrows the records counted. It has no `forView` or `forReference`: the platform fails on either in an aggregate query, with an error no code can catch.

Rows can be grouped by a path through a [polymorphic lookup](#polymorphic-lookups): `agg.groupBys().add(App.s.model(Task.SObjectType).path('What.Type'))` writes `GROUP BY What.Type`.

---

## 8. Searches (SOSL)

A search runs one search term across several objects. Each object's query supplies its fields and filters:

```apex
inj.IQuery accounts = App.s.model(Account.SObjectType).query();
accounts.fields().add(new Set<SObjectField>{ Account.Name });
accounts.filters().add(App.s.eq(Account.Industry, 'Energy'));

inj.IQuery contacts = App.s.model(Contact.SObjectType).query();
contacts.fields().add(new Set<SObjectField>{ Contact.Email });

inj.ISearchQuery s = App.s.searchQuery(new List<inj.IQuery>{ accounts, contacts });
s.searchScope().add(inj.Enums.SearchScope.NAME);
s.setLimit(20);
// FIND {Acme} IN NAME FIELDS RETURNING Account(Id, Name WHERE (Industry = 'Energy')), Contact(Id, Email) LIMIT 20

List<List<SObject>> found = s.run('Acme');                    // one list per object, in order
Map<SObjectType, List<SObject>> byType = s.runAsMap('Acme');  // only the objects with hits
```

- **Scope:** `searchScope()` is a live set (`ALL`, `NAME`, `EMAIL`, `PHONE`); left empty, SOSL's default applies.
- **WITH clause:** `setWith(text)` adds one (`DIVISION='Global'`, `SNIPPET`, and so on). That text is used as written, so never build it from user input.
- **The search term:** backslashes, braces and quotes in it are escaped, so a term can't close `FIND {...}` early. SOSL wildcards (`*`, `?`) and operators still work.
- **Filter values:** SOSL has no bind variables, so values in the objects' filters are written inline, escaped. A [date literal](#date-literals) is written as it is: `RETURNING Opportunity(Id WHERE (CloseDate = NEXT_N_DAYS:30))`.
- **Limit and offset per object:** `setLimit` and `setOffset` on an object's query are written inside its brackets: `Account(Id WHERE (...) LIMIT 5)`. `s.setLimit` limits the search as a whole.
- **Paths through a polymorphic lookup** filter and order as in a query: `RETURNING Task(Id WHERE (What.Type = 'Account') ORDER BY Owner.Name ASC NULLS FIRST)`.
- **Queries of the framework:** a search takes queries the framework made, which covers every class that extends `inj.BaseQuery`. A class of your own that only implements `inj.IQuery` is refused with a `SearchException` when the search is written: `A search needs queries made by the framework`.
- **Options:** `RETURNING` has no place for `ALL ROWS` or `USING SCOPE`, so a query with `allRows(true)` or `usingScope(...)` throws a `SearchException` when the search is written: `Cannot write ALL ROWS in a search: the query on Account asks for it`. `forUpdate`, `forView` and `forReference` on a query are not used by a search.
- **Semi-joins:** an object's filters can hold a [semi-join or anti-join](#semi-joins-and-anti-joins). Its inner query is written inline too: `RETURNING Account(Id, Name WHERE (Id IN (SELECT AccountId FROM Contact WHERE (MailingCity = 'Seattle'))))`.
- **Security:** a search runs in system mode, and in user mode as soon as one of its queries was set to `withSharing(true)`. Default fields the user can't read are left out, as in a query.
- **Testing:** a search runs through the scheme of its first query. With `inj.MockScheme` it returns the rows registered for each object and records the SOSL (see the [testing guide](testing-guide.md#mocking-queries-with-mockscheme)); against the database, use `Test.setFixedSearchResults`.
- **Your own scheme:** implement `inj.ISearchScheme` beside `inj.IScheme` to receive searches. A scheme that does not is skipped, and the search goes straight to the platform.

---

## 9. Custom query classes

To give an object its own default fields or helper methods, extend `inj.BaseQuery` and register the class in your `App`:

```apex
global class AccountQuery extends inj.BaseQuery {
  global override Set<SObjectField> getDefaultFields() {
    return new Set<SObjectField>{ Account.Id, Account.Name, Account.Type };
  }
}

// In App: the query registry maps the object to the class
inj.Application.make(null, services, new Map<Type, Type>{ Account.class => AccountQuery.class }, domains);
```

`App.s.qf().make(Account.SObjectType)` then returns an `AccountQuery` with those defaults. The [extension guide](extension-guide.md) covers the initialization hook (`onInitialized`) and calling base methods across the namespace.
