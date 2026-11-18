# Extension Guide

How a subscriber org plugs its own classes into the framework: the entry point that registers them, custom query classes, domain classes that handle triggers, and services.

Examples are written from a subscriber org, so package types carry the `unif.` prefix. `App.s` is the subscriber's own entry point, built in the first section.

## Contents

1. [Your entry point](#your-entry-point)
2. [Custom query classes](#custom-query-classes)
3. [Domain classes](#domain-classes)
4. [Triggers](#triggers)
5. [Services](#services)
6. [Working across the namespace](#working-across-the-namespace)

---

## Your entry point

The package does not give subscribers a ready-made application. You build one, once, and keep it in a class of your own:

```apex
public class App {
  public static unif.IApplication s {
    get {
      if (s == null) {
        s = unif.Application.make(
          null, // scheme: null uses the default
          new Map<Type, Type>{ IInvoicing.class => Invoicing.class }, // services
          new Map<Type, Type>{ Account.class => AccountQuery.class }, // queries
          new Map<Type, Type>{ Opportunity.class => Opportunities.class } // domains, also used for triggers
        );
      }
      return s;
    }
    private set;
  }
}
```

Each registry maps a key to the class the matching factory creates:

| Registry | Key | The class must implement |
| --- | --- | --- |
| Services | an interface or class of yours | the key (it must be assignable to it) |
| Queries | the object's class, `Account.class` | `unif.IQuery` (extend `unif.BaseQuery`) |
| Domains | the object's class | `unif.IDomain` (extend `unif.BaseDomain`) |
| Triggers | the object's class | `unif.ITriggered` (`unif.BaseDomain` does) |

- The key for an object is its class (`Account.class`), not its token (`Account.SObjectType`).
- A pair that breaks these rules throws `unif.Application.FactoryException` when the application is made.
- The four-argument `make` uses the domain registry for triggers as well. To handle an object's triggers with a class that is not its domain, use the five-argument form, which takes a separate trigger registry.
- `unif.Application.make()` and `make(scheme)` start with empty registries. Any factory takes more pairs later: `App.s.qf().register(new Map<Type, Type>{ Contact.class => ContactQuery.class })`.
- The factories create your classes with `Type.newInstance()`, so each registered class needs a constructor without arguments.

An object with no registered query or domain class still works: `App.s.qf().make(Contact.SObjectType)` returns a plain query with the default field set, and `App.s.df().make(records)` a plain domain.

---

## Custom query classes

Extend `unif.BaseQuery` to give an object its own default fields, conditions that always apply, or helper methods.

```apex
global class AccountQuery extends unif.BaseQuery {
  global override Set<SObjectField> getDefaultFields() {
    return new Set<SObjectField>{ Account.Id, Account.Name, Account.Industry, Account.AnnualRevenue };
  }

  public AccountQuery inIndustry(String industry) {
    base().addCondition(App.s.eq(Account.Industry, industry));
    return this;
  }

  public AccountQuery overRevenue(Decimal floor) {
    base().addCondition(App.s.gt(Account.AnnualRevenue, floor));
    return this;
  }
}
```

Once the class is registered, the query factory returns it for the object:

```apex
AccountQuery big = ((AccountQuery) App.s.qf().make(Account.SObjectType)).inIndustry('Energy').overRevenue(1000000);
List<Account> rows = (List<Account>) big.base().run();
// SELECT Id, Name, Industry, AnnualRevenue FROM Account WHERE (Industry = :a0 AND AnnualRevenue > :a1)
```

`base()` returns the query as a `unif.IQuery`. Everything a query can do is called through it; see [Working across the namespace](#working-across-the-namespace).

### Default fields

`getDefaultFields()` is read by the query factory, once per object per transaction.

- Return a set of fields and the factory selects exactly those.
- **Leave it out (or return null) and the factory selects every field of the object.** That is wider than the trimmed default set an unregistered object gets, so a registered query class should normally say which fields it wants.

### The initialization hook

`onInitialized` runs when the query is bound to its object, before anyone else sees it. Use it for conditions and orderings that every query of the class should carry:

```apex
global class OpenCaseQuery extends unif.BaseQuery {
  global override Set<SObjectField> getDefaultFields() {
    return new Set<SObjectField>{ Case.Id, Case.Subject, Case.Priority };
  }

  global override void onInitialized(unif.IModel source) {
    base().addCondition(App.s.eq(Case.IsClosed, false));
    base().orderings().add(App.s.ordering(Case.CreatedDate, false, true));
  }
}

// App.s.qf().make(Case.SObjectType).toSoql()
// SELECT Id, Subject, Priority FROM Case WHERE (IsClosed = false) ORDER BY CreatedDate DESC NULLS LAST
```

Keep the hook to configuring the query. The factory also makes a short-lived instance of the class to read its default fields, so the hook can run more often than you ask for queries.

### Creating one directly

The factory is the usual way in. To write `new AccountQuery()` as well, give the class a constructor that names its object:

```apex
global AccountQuery() {
  super(App.s.model(Account.SObjectType));
}
```

A query made this way has not been through the factory, so `getDefaultFields()` is not applied: it selects `Id` plus whatever `onInitialized` adds. The factory can still create the class; binding it to the same object twice does nothing.

`super(otherQuery)` copies another query of the class: its fields, subqueries, conditions, orderings, limit, offset and security settings. `onInitialized` runs for the copy as well, but the conditions, orderings and limits it sets are then replaced by the original's, so nothing is doubled.

---

## Domain classes

A domain class holds the logic for a set of records of one object: trigger handling, and whatever helper methods you add. Extend `unif.BaseDomain`.

```apex
global class Opportunities extends unif.BaseDomain {
  global Opportunities() {
    super();
  }

  // For use outside triggers: new Opportunities(records)
  public Opportunities(List<Opportunity> records) {
    super(App.s.model(Opportunity.SObjectType), records);
  }

  public List<Opportunity> items() {
    return (List<Opportunity>) base().records();
  }

  public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
    for (Opportunity row : items()) {
      if (String.isBlank(row.NextStep)) {
        row.NextStep = 'Qualify';
      }
    }
  }

  public override void onAfterUpsert(Map<Id, SObject> oldMap) {
    Set<SObjectField> stage = new Set<SObjectField>{ Opportunity.StageName };
    unif.IWork work = App.s.work();
    for (Opportunity row : (List<Opportunity>) base().getChangedRecords(oldMap, stage)) {
      if (row.StageName == 'Closed Won') {
        work.track(new Task(WhatId = row.Id, Subject = 'Send the welcome pack'));
      }
    }
    work.apply();
  }
}
```

Declare the class `global`, with a `global` no-argument constructor for the factory, and the hook overrides `public` (or `global`).

### Trigger hooks

| Hook | Runs on | `oldMap` |
| --- | --- | --- |
| `onBeforeUpsert(oldMap)` | before insert, before update | null on insert |
| `onAfterUpsert(oldMap)` | after insert, after update | null on insert |
| `onBeforeDelete()` | before delete | |
| `onAfterDelete()` | after delete | |
| `onAfterUndelete()` | after undelete | |

Insert and update share a hook because most logic (defaults, validation) is the same for both. Test `oldMap == null` where it differs.

In the delete hooks the records are the ones being deleted (`Trigger.old`); everywhere else they are `Trigger.new`.

`onInitialized(source, records)` is a sixth hook, called once when the domain is first given its records, whether by a trigger, the domain factory or your own constructor.

### Working with the records

All of these are called through `base()`, which returns the domain as a `unif.IDomain`.

| Method | Returns |
| --- | --- |
| `records()` | A copy of the list. The records in it are the domain's own, so setting a field in a before hook changes the record being saved. |
| `size()` | How many records. |
| `toMap()` | The records by Id; empty when they have no Ids yet (before insert). |
| `source()` | The object's `unif.IModel`: describe, field map, record types, paths. |
| `filter(condition)` | The records that meet a condition, tested in memory. |
| `sort(ordering)` | A sorted copy. |
| `getChangedRecords(oldMap, fields)` | The records whose value in any of the fields differs from `oldMap`. Fields are a `Set<SObjectField>` or a `Set<String>` of API names. |
| `segment(route)` | The records grouped by a field's value as text; null values group under `'null'`. |
| `segmentId(route)` | The records grouped by an Id field; records with no Id there are left out. |
| `catalog(route)`, `catalogId(route)` | The same groupings, remembered until the records change or `forget(route)` is called. |
| `collectRecords(route)` | The loaded parent records along a lookup, by Id. |
| `aggregate(function)` | COUNT, COUNT_DISTINCT, SUM, AVG, MIN or MAX over the records in memory; nulls are skipped. |
| `updateBlank(template, work)` | Copies the template's populated fields into the records' blank fields and tracks the records that changed. |
| `updateDifferent(template, work)` | The same, into every field that differs. |

A route is a field (`Opportunity.StageName`), a field API name, a list of fields that walks lookups, or a `unif.IPath`.

Two things to know about `getChangedRecords`:

- When `oldMap` is null (an insert), every record counts as changed. That is usually what you want: "the stage is now Closed Won" covers both new and edited records.
- A field read through a lookup needs the parent loaded; trigger records never have parents loaded.

```apex
// In a domain method
List<SObject> large = base().filter(App.s.gt(Opportunity.Amount, 100000));
Map<Id, List<SObject>> byAccount = base().catalogId(Opportunity.AccountId);
Decimal total = (Decimal) base().aggregate(App.s.sum(Opportunity.Amount));
```

### One instance for before and after

By default one instance handles the before and the after phase of the same operation, so a value kept in a field of your class during `onBeforeUpsert` is still there in `onAfterUpsert`. The records are refreshed between the two phases.

To get a new instance for each phase, or to switch on the permission check, override the settings:

```apex
public override Boolean shouldRecycleInstance() {
  return false;
}

public override Boolean shouldEnforceSecurity() {
  return true;
}
```

With `shouldEnforceSecurity()` returning true, the trigger first checks that the running user has the object permission the operation needs (create, edit, delete; undelete for undelete) and throws an exception if not. Field-level security is not checked. It is off by default.

### Using a domain outside triggers

```apex
// The registered class (or a plain domain), from the factory
unif.IDomain deals = App.s.df().make(records);

// Your class, with its helper methods
Opportunities mine = new Opportunities(records);
```

`App.s.df().make(records)` returns null for a null or empty list. `App.s.model(Opportunity.SObjectType).domain(records)` always gives a plain domain, whatever is registered.

---

## Triggers

One line per trigger:

```apex
trigger OpportunityTrigger on Opportunity(
  before insert, after insert, before update, after update, before delete, after delete, after undelete
) {
  App.s.tf().execute();
}
```

`execute()` finds the class registered for the object, creates it (or reuses the before-phase instance) and calls the hook for the operation. An object with nothing registered is left alone.

### Switching triggers off

```apex
App.s.tf().disable(); // every object
App.s.tf().disable(new List<SObjectType>{ Opportunity.SObjectType }); // one object
App.s.tf().disable(
  new Map<SObjectType, Set<TriggerOperation>>{
    Opportunity.SObjectType => new Set<TriggerOperation>{ TriggerOperation.AFTER_UPDATE }
  }
); // one operation
```

Each `disable` has a matching `enable`. They count: after two calls to `disable()`, triggers stay off until `enable()` has been called twice, so code that switches triggers off and on again can be nested safely. The switches belong to the application they were called on and last for the transaction.

### Switching triggers off for some users

`disable` is called from code. To let an administrator switch triggers off for a user, such as the one a data load or an integration runs as, give the application a rule that reads a custom permission:

```apex
public class BypassTriggers implements unif.ITriggeredBypass {
  public Boolean bypasses(SObjectType token, TriggerOperation operation) {
    return FeatureManagement.checkPermission('Bypass_Triggers');
  }
}
```

```apex
// in App, after Application.make(...)
s.tf().disableWhen(new BypassTriggers());
```

Create the custom permission `Bypass_Triggers`, add it to a permission set and assign the permission set to the user. That user's saves then skip every trigger the application runs. Nothing is deployed to switch it on or off: remove the assignment and the triggers are back.

- The rule is asked each time a trigger is about to run, and is given the object and the operation. It can answer for one object (`token == Opportunity.SObjectType && FeatureManagement.checkPermission('Bypass_Opportunity_Triggers')`) or one operation.
- Rules add up: a trigger is skipped when any rule says yes.
- A rule is not asked when the trigger is already off in code, or when no class is registered for the object.
- A custom permission that does not exist counts as not held.
- The rule is a class of yours on purpose. It runs in your namespace, so it finds the permission you created; a check made from inside the package's namespace may not.
- A rule can read anything else instead: a custom setting, a feature flag, or the kind of transaction (`System.isBatch()`).

### A handler that is not a domain

Anything that implements `unif.ITriggered` can handle an object's triggers. Register it in the trigger registry (the fifth argument of `make`):

```apex
public class AuditTrail implements unif.ITriggered {
  public void handleTrigger(
    TriggerOperation operation,
    List<SObject> newRecords,
    List<SObject> oldRecords,
    Map<Id, SObject> oldMap,
    unif.IModel model
  ) {
    // called for every operation the trigger is declared for
  }
}
```

---

## Services

The service factory maps an interface to the class that implements it, so callers depend on the interface and tests can register a stand-in.

```apex
public interface IInvoicing {
  void invoice(Set<Id> opportunityIds);
}

public class Invoicing implements IInvoicing {
  public void invoice(Set<Id> opportunityIds) {
    // ...
  }
}

IInvoicing invoicing = (IInvoicing) App.s.sf().get(IInvoicing.class);
invoicing.invoice(wonIds);
```

- `get(key)` returns one shared instance per application, created on first use.
- `make(key)` returns a new instance each time.
- Both throw for a key that was never registered.

---

## Working across the namespace

The package's own classes (`Query`, `Domain`, the factories) are not visible outside its namespace. A subscriber sees the global interfaces (`unif.IQuery`, `unif.IDomain`, `unif.IWork`...), the two base classes, and the static entry points (`unif.Application`, `unif.Async`, `unif.FieldScope`, `unif.MockScheme`). The full list is in [package_api.apex](package_api.apex).

Three rules follow from that:

**Call inherited methods through `base()`.** Your class extends `BaseQuery` or `BaseDomain`, but the methods it inherits from `Query` and `Domain` are not global, so they cannot be called directly, even on `this`:

```apex
setLimit(100); // does not compile in a subscriber org
base().setLimit(100); // works: base() is this object as a unif.IQuery
```

The same goes for callers holding your type: `accountQuery.base().run()`, not `accountQuery.run()`. A variable typed as `unif.IQuery` or `unif.IDomain` needs no `base()`.

**Query and domain classes are `global`.** They extend a class of the package, so they are declared `global`, with a `global` no-argument constructor or no constructor at all. A service, or a trigger handler that only implements `unif.ITriggered`, extends nothing from the package and can be `public`. The methods they override (`getDefaultFields`, `onInitialized`, the trigger hooks, `shouldRecycleInstance`, `shouldEnforceSecurity`) are global in the base class; declare the overrides `public` or `global`.

**Framework exceptions are caught as `Exception`.** Apart from `unif.Application.FactoryException`, the framework's exception types are not global, so a subscriber cannot name them in a `catch`.

See also: [query guide](query-guide.md), [work guide](work-guide.md), [async guide](async-guide.md), [testing guide](testing-guide.md).
