# Injectify

An Apex framework for Salesforce that gives queries, conditions, triggers, DML and async jobs one consistent model. Fields are addressed as paths (`Contact` → `Account` → `Owner.Name`); a condition built from those paths can both compile into a SOQL `WHERE` clause and test records in memory, with the same answer.

> **Status:** pre-release (0.3.x). An unlocked package in the namespace `inj`. The API may change before 1.0.

## What it does

- **Queries**: a fluent SOQL builder with fields across lookups, `TYPEOF` for polymorphic lookups, child subqueries, aggregates (with `ROLLUP`/`CUBE`) and SOSL. Values are bound (`:a0`) when the query runs.
- **Conditions**: `eq`, `ne`, `gt`, `ge`, `lt`, `le`, `lk` (LIKE), `iin`, `nin`, `inc`, `exc`, combined with `all`/`any`, or parsed from text such as `Industry = 'Energy' AND AnnualRevenue > 1000000`. The same condition renders as SOQL or evaluates records in memory.
- **Domains and triggers**: one class per object for trigger logic, with switches in code, bypass rules that can read a custom permission, optional permission checks, and in-memory helpers (`filter`, `sort`, `catalog`, `aggregate`, change detection).
- **Unit of work**: `IWork` collects inserts, updates, upserts, deletes, emails and platform events, links new parents and children, and applies them in dependency order with as few DML statements as possible. It can run as the user, and it can save what it can and tell you, record by record, what it could not: a child is never saved without the new parent it depends on.
- **Async**: queueable, batch and schedulable jobs from small handler classes, chained with `then()`, with shared values along the chain and rules for jobs started inside jobs.
- **Testable seams**: inject a scheme (`IScheme`) to control describes and queries; `MockScheme` returns canned rows without inserting data.

## Sixty-second tour

Give your org one entry point:

```apex
public class App {
  public static inj.IApplication s {
    get {
      if (s == null) {
        s = inj.Application.make(
          null, // scheme: null uses the default
          new Map<Type, Type>(), // services
          new Map<Type, Type>(), // custom queries
          new Map<Type, Type>{ Account.class => Accounts.class } // domains and triggers
        );
      }
      return s;
    }
    private set;
  }
}
```

Query, with bound values:

```apex
inj.IQuery q = App.s.qf().make(Account.SObjectType);
q.fields().add(new Set<SObjectField>{ Account.Name, Account.Industry });
q.fields().add('Owner', new Set<SObjectField>{ User.Name });
q.filters().add(App.s.eq(Account.Industry, 'Energy'));
q.orderings().add(App.s.ordering(Account.Name, true, false));
q.setLimit(50);

List<Account> energy = (List<Account>) q.run();
// SELECT Id, <default fields>, Owner.Name FROM Account WHERE (Industry = :a0)
//   ORDER BY Name ASC NULLS FIRST LIMIT 50
```

`qf().make()` starts from a default field set: every field except long text areas, formulas, fields from managed packages, user preference and permission flags, and fields no user can be given access to. A custom query class sets its own defaults with `getDefaultFields()` (see the extension guide); `App.s.model(Account.SObjectType).query()` starts from `Id` alone.

Test records in memory with the same condition:

```apex
inj.ICondition bigEnergy = App.s.model(Account.SObjectType)
  .parseCondition('Industry = \'Energy\' AND AnnualRevenue > 1000000');
Boolean matches = bigEnergy.evaluate(someAccount);
```

Write parents and children together:

```apex
Account company = new Account(Name = 'Acme');
Contact person = new Contact(LastName = 'Lovelace');
App.s.work()
  .track(company)
  .track(person, Contact.AccountId, company) // filled in once Acme has an Id
  .apply();
```

Save what can be saved, and learn what could not:

```apex
inj.IWork work = App.s.work();
work.options().optAllOrNone = false;
work.track(company).track(person, Contact.AccountId, company).apply();

for (inj.IWorkFailure failure : work.failures()) {
  System.debug(failure.getRecord() + ': ' + failure.getMessage());
}
// If Acme is refused, Lovelace is not inserted without it. Both are listed.
```

Handle triggers in a domain class:

```apex
global class Accounts extends inj.BaseDomain {
  public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
    // oldMap is null on insert
  }
}

trigger AccountTrigger on Account (before insert, before update, after insert, after update) {
  App.s.tf().execute();
}
```

Chain async work:

```apex
inj.Async.queueable(new PrepareData())
  .then(inj.Async.queryable(new ProcessRows()))
  .then(inj.Async.queueable(new NotifyOwners()))
  .run();
```

## What it does not do yet

- **Logging.** There is none. Use it beside a logger such as [Nebula Logger](https://github.com/jongpie/NebulaLogger).
- **Triggers configured by admins.** Trigger logic for an object lives in one class and runs in the order that class gives it. There is no ordering in custom metadata and no Flow action in the chain.
- **Async operations.** No built-in retries (the async guide has a recipe for writing one), no finalizer hooks, no Apex cursors and no monitoring screen.
- **Queries.** No semi-joins (`WHERE Id IN (SELECT ...)`) and no result caching.
- **A track record for this version.** An earlier version runs in a production org. This rewrite has run in scratch orgs only, it has one maintainer, and it has no CI yet.

[How it compares](docs/documentation/comparison.md) says when another library is the better choice.

## Install

The unlocked package (namespace `inj`) is in beta: `Injectify@0.3.0-2`. A beta version installs in a scratch org or a sandbox, not in production; no version is promoted yet.

```bash
sf package install --package 04tgK000000aq05QAA --target-org <alias> --wait 20
```

Or deploy the source to a scratch org:

```bash
sf org create scratch --definition-file config/project-scratch-def.json --alias framework-dev
sf project deploy start -d force-app -o framework-dev
sf apex test run -l RunLocalTests -c -o framework-dev
```

Deployed as source, the classes have no namespace: write `IQuery` where the guides, which are written for the package, write `inj.IQuery`.

## Documentation

- [Query guide](docs/documentation/query-guide.md): fields, lookups and TYPEOF, conditions, subqueries, aggregates, search
- [Extension guide](docs/documentation/extension-guide.md): custom queries and domains, registration
- [Async guide](docs/documentation/async-guide.md): handlers, chaining, capture modes, testing
- [Work guide](docs/documentation/work-guide.md): DML ordering, relationships, merging
- [Testing guide](docs/documentation/testing-guide.md): testing queries, domains, async and work; `MockScheme`
- [Utilities guide](docs/documentation/utilities-guide.md): test data, CSV, field and record helpers, persistent values, limits
- For coding agents: [llms.txt](llms.txt) indexes these guides, and [skills/injectify-apex](skills/injectify-apex/SKILL.md) is a skill with the rules for writing subscriber code
- [API surface](docs/documentation/package_api.apex): every global type and member
- [How it compares](docs/documentation/comparison.md): prior art, what is different here, and when to choose another library

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## Credits

- The application layout (query, domain and service factories, a trigger-handling domain layer, a unit of work) follows [fflib-apex-common](https://github.com/apex-enterprise-patterns/fflib-apex-common) and the Apex Enterprise Patterns; no fflib code is included.
- The async chain builds on [apex-chainable](https://github.com/rsoesemann/apex-chainable) by Robert Sösemann (MIT).

See [NOTICE](NOTICE).

## License

[MIT](LICENSE)
