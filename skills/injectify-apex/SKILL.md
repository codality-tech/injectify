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

## Rules that do not bend

1. **Registry keys are types.** `Account.class => Accounts.class`. `Account.SObjectType` as a key
   does not compile.
2. **Query and domain classes are `global`**, with a `global` no-argument constructor (or no
   constructor). Services and handlers that only implement `inj.ITriggered` may be `public`. Overrides of framework hooks are `public` or `global`. `protected override` does
   not compile across the namespace.
3. **Inherited methods go through `base()`** inside a query or domain class: `base().records()`,
   `base().fields()`, `base().addCondition(...)`.
4. **Only `global` types can be named.** `inj.Query`, `inj.Domain`, `inj.Work` are not visible;
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
    for (Account row : (List<Account>) base().records()) {
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
`onAfterUndelete()`. Insert and update share a hook. `base().getChangedRecords(oldMap, fields)`
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

- Does every registry key use `.class`?
- Is every query and domain class `global`, with `public` or `global` overrides?
- Is anything in the package named without `inj.`, or named that is not in `package_api.apex`?
- Is each unit of work applied exactly once, outside loops?
- Does a query that takes user input bind it (`run()`), rather than execute `toSoql()`?
