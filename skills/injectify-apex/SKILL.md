---
name: injectify-apex
description: Write and review Apex that uses the Injectify framework (namespace `inj`) in a Salesforce subscriber org - queries and conditions, domain classes and triggers, the unit of work, async jobs, and tests. Use when code references `inj.`, `App.s`, `BaseQuery`, `BaseDomain`, `IWork` or `inj.Async`.
---

# Writing Apex with Injectify

Injectify is an unlocked package. Your code lives outside its namespace, so it sees only the package's
`global` types, always with the `inj.` prefix. Everything below is written from that side.

When a detail is not covered here, read the guide rather than guess; the signatures are in
`docs/documentation/package_api.apex`.

| Topic | Guide |
| --- | --- |
| Entry point, query and domain classes, triggers | `docs/documentation/extension-guide.md` |
| Fields, conditions, subqueries, aggregates, SOSL | `docs/documentation/query-guide.md` |
| Inserts, updates, deletes, related records | `docs/documentation/work-guide.md` |
| Queueable, batch and schedulable jobs | `docs/documentation/async-guide.md` |
| Tests and `MockScheme` | `docs/documentation/testing-guide.md` |
| Utility classes | `docs/documentation/utilities-guide.md` |

## The entry point

An org has one class of its own, by convention `App`, that builds the application once:

```apex
public class App {
  public static inj.IApplication s {
    get {
      if (s == null) {
        s = inj.Application.make(
          null, // scheme: null uses the default
          new Map<Type, Type>(), // services
          new Map<Type, Type>{ Account.class => AccountQuery.class }, // query classes
          new Map<Type, Type>{ Account.class => Accounts.class } // domains and triggers
        );
      }
      return s;
    }
    private set;
  }
}
```

Look for an existing `App` before writing one. `App.s` gives the factories (`qf()`, `df()`, `sf()`,
`tf()`), the condition builders, `model(...)` and `work()`.

## Everything goes through the framework

In an org that uses Injectify, code that is not a test reads and writes records through `App.s`:

- **Every query is an `inj.IQuery`** (`App.s.qf().make(...)` or `App.s.model(...).query()`), an
  aggregate query or a search. No `[SELECT ...]` and no `Database.query`.
- **Every save is a unit of work** (`App.s.work()`). No `insert`, `update`, `delete`, `upsert` and no
  `Database.insert`.

The reason is not style. A query written inline never reaches the application's scheme, so its
sharing and user-mode settings do not apply to it, `MockScheme` cannot answer it in a test, and its
conditions cannot be reused to test records in memory. DML written inline skips the work's ordering,
its partial-success reporting and its user mode.

Inline SOQL and DML are right in three places only:

1. **Tests**, to set records up and to check what the code saved. A test that asserts with the
   framework's own query is checking the framework with itself.
2. **A scheme class** (`inj.IScheme`): that is where the framework's queries are executed.
3. **A query the framework cannot express.** Write it inline with a comment that says why. In
   versions after 0.3.0 these are not among them (see the query guide):
   - a semi-join: `App.s.iin(Account.Id, contactQuery)` writes `Id IN (SELECT AccountId FROM Contact ...)`;
   - a date literal: `App.s.ge(Account.CreatedDate, inj.DateLiteral.lastNDays(30))` writes
     `CreatedDate >= LAST_N_DAYS:30`;
   - `ALL ROWS`, `USING SCOPE`, `FOR VIEW` and `FOR REFERENCE`: `allRows(true)`,
     `usingScope(inj.Enums.FilterScope.MINE)`, `forView(true)`, `forReference(true)`;
   - a filter on what a polymorphic lookup points at: `App.s.eq('What.Type', 'Account')`.

Fields and conditions reach through lookups without falling back to SOQL text:
`q.fields().add(Contact.AccountId, new Set<SObjectField>{ Account.Name })` selects `Account.Name`,
and `App.s.eq(new List<SObjectField>{ Contact.AccountId, Account.Industry }, 'Energy')` filters on
it. Setup objects (`Group`, `User`) and share objects (`AccountShare`) are queried the same way.

## Rules that do not bend

1. **Registry keys are types.** `Account.class => Accounts.class`. `Account.SObjectType` as a key
   does not compile.
2. **Query and domain classes are `global`**, with a `global` no-argument constructor (or no
   constructor). Services and handlers that only implement `inj.ITriggered` may be `public`. Overrides of framework hooks are `public` or `global`. `protected override` does
   not compile across the namespace.
3. **Inherited methods are called directly** inside a query or domain class: `records()`,
   `fields()`, `addCondition(...)`. (`base()`, needed before 0.3.0-2, still works.)
4. **Only `global` types can be named.** `inj.Work`, `inj.QueryFactory`, `inj.Filtering` are not visible;
   use `inj.IQuery`, `inj.IDomain`, `inj.IWork`.
5. **Catch `Exception`** for framework errors. Only `inj.Application.FactoryException` and the
   utility classes' exceptions are global.

## Queries

```apex
inj.IQuery q = App.s.qf().make(Account.SObjectType); // starts with the default fields
q.fields().add(new Set<SObjectField>{ Account.Name, Account.Industry });
q.fields().add('Owner', new Set<SObjectField>{ User.Name }); // through a lookup
q.filters().add(App.s.eq(Account.Industry, 'Energy'));
q.orderings().add(App.s.ordering(Account.Name, true, false)); // ascending, nulls first
q.setLimit(50);
List<Account> rows = (List<Account>) q.run();
```

- `App.s.model(Account.SObjectType).query()` starts from `Id` alone; `qf().make(...)` adds the
  default field set, or the registered class's `getDefaultFields()`.
- Conditions: `eq ne lt le gt ge lk iin nin inc exc`, combined with `all`, `any`, `neg`. A model
  also parses text: `App.s.model(Account.SObjectType).parseCondition('Industry = \'Energy\'')`.
- `neg(c)` reverses `c` itself and returns it, so a second `neg` on the same condition undoes the
  first. An empty `any` matches nothing and an empty `all` everything, in a query and in memory.
  Compare with `null` by `eq` and `ne` only: a query refuses `null` with `lt le gt ge lk`.
- A date literal is a value, not text: `inj.DateLiteral.thisWeek()`, `inj.DateLiteral.lastNDays(30)`,
  `inj.DateLiteral.of('NEXT_N_FISCAL_QUARTERS:2')`. It goes with `eq ne lt le gt ge` on a date or
  date-time field, and as a `List<inj.IDateLiteral>` with `iin` and `nin`.
- `What.Type`, `Owner.Name` and the other fields every target of a polymorphic lookup has are
  paths: `App.s.eq('What.Type', 'Account')`, `q.fields().add(new Set<String>{ 'What.Name' })`.
  A field of one target (`What.Industry`) needs `TYPEOF`: `q.fields().add(Task.WhatId, fields)`.
  One SELECT reads a lookup one way: `What.Type` beside `TYPEOF What` is refused, while a filter on
  `What.Type` beside it is fine.
- `usingScope(...)`: use only a scope you know the object supports. For any other the platform
  ends the transaction with an error that cannot be caught.
- `evaluate` answers as SOQL does, including for empty fields: an empty number or date is neither
  above nor below a value, also under `neg`. The query guide lists the few places where a condition
  in memory and the same condition in a query differ.
- `run()`, `fetch()`, `count()` and `toLocator()` bind values. `toSoql()` writes them inline for
  logs and assertions; never execute its output with values from a user.
- System mode is the default. `withSharing(true)` is user mode: sharing, object and field
  permissions apply. A field added by name that the user cannot read fails the query; default
  fields the user cannot read are left out.
- `ordering` always takes three arguments.

## Domain classes and triggers

```apex
global class Accounts extends inj.BaseDomain {
  global Accounts() {
    super();
  }

  public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
    for (Account row : (List<Account>) records()) {
      // oldMap is null on insert
    }
  }
}
```

```apex
trigger AccountTrigger on Account(before insert, before update, after insert, after update) {
  App.s.tf().execute();
}
```

Hooks: `onBeforeUpsert(oldMap)`, `onAfterUpsert(oldMap)`, `onBeforeDelete()`, `onAfterDelete()`,
`onAfterUndelete()`. Insert and update share a hook. `getChangedRecords(oldMap, fields)`
returns the records where one of the fields changed (every record on insert).

Switch triggers off with `App.s.tf().disable(...)` and back on with the matching `enable(...)`;
the calls count, so they nest. To switch them off for some users, write a class implementing
`inj.ITriggeredBypass` (for example returning `FeatureManagement.checkPermission('Bypass_Triggers')`)
and register it once with `App.s.tf().disableWhen(rule)`.

## Saving records

Build one unit of work, track everything, apply once:

```apex
inj.IWork work = App.s.work();
work.track(account); // no Id: insert; Id: update
work.track(contact, Contact.AccountId, account); // sets the lookup after the parent is inserted
work.purge(stale); // delete
work.apply();
```

- A work is applied once. Make a new one for the next set of changes.
- `track(child, lookupField, parent)` tracks the parent too, so an existing parent is updated. To
  avoid that, set the lookup yourself and track only the child.
- DML runs in system mode. `withSharing(true)` runs it in user mode, and the platform then refuses
  a statement the user lacks permission for.
- In a trigger hook, apply the work at the end of the hook, not inside a loop.
- A failed record throws a `DmlException`. To save what can be saved, set
  `work.options().optAllOrNone = false` before `apply()` and read `work.failures()` after it: each
  `inj.IWorkFailure` has `getRecord()`, `getMessage()` and `getErrors()`.

## Async jobs

Write a handler, hand it to a factory, chain with `then`:

```apex
public class StampAccounts implements inj.IQueueableHandler {
  public void queueableExecute() {
    // the work
  }
}

inj.Async.queueable(new StampAccounts()).then(inj.Async.queryable(new SweepHandler())).run();
```

Factories: `queueable`, `queryable` (batch over an `IQuery`), `iterable` (batch over an iterable),
`schedulable`. Call `run()` wherever the need arises; a job started inside another job is held and
started in a way the platform allows.

## Tests

- Assert on `toSoql()` to test a query's shape without data.
- `inj.MockScheme` returns rows you register instead of reading the database:
  `inj.Application.make(new inj.MockScheme().returning(Account.SObjectType, rows))`.
- `inj.Async.synchronousInTests = true` runs a whole chain inside the test.
- `inj.IdUtil.generateId(Account.SObjectType)` makes an Id for a record that is never inserted.
- Tests that insert records fire the org's triggers; `App.s.tf().disable()` turns the framework's
  off for the transaction.

## Before finishing

- Is there a `[SELECT`, a `Database.query` or a bare `insert`/`update`/`delete` outside a test or a
  scheme class? Replace it, or leave a comment saying what the framework could not express.
- Does every registry key use `.class`?
- Is every query and domain class `global`, with `public` or `global` overrides?
- Is anything in the package named without `inj.`, or named that is not in `package_api.apex`?
- Is each unit of work applied exactly once, outside loops?
- Does a query that takes user input bind it (`run()`), rather than execute `toSoql()`?
