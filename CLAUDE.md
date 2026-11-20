# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Injectify** is a Salesforce unlocked package (namespace: `inj`) that provides a comprehensive Apex framework for rapid application development. It uses factory patterns, dependency injection, and interface-based abstractions to provide unified access to SOQL queries, DML operations, trigger handlers, async operations, and domain logic.

**Current Version:** 0.3.0 (released as `Injectify@0.3.0-2`, `04tgK000000aq05QAA`, promoted 2026-11-18; `s-unify` runs the beta `Injectify@0.4.0-1`, `04tgK000000bMZRQA2`, since 2026-11-20; the next release is 0.4.0, because the new methods on `IQuery` and `IAggregateQuery` break a class that implements them directly; new changes go under Unreleased in CHANGELOG.md)
**Source API Version:** 68.0
**Package Alias:** Injectify

**Versioning Convention:** The `versionName` in `sfdx-project.json` should match the actual version number (e.g., "ver 0.2.0" for version 0.1.3). Update both `versionName` and `versionNumber` together when incrementing versions.

## Common Commands

### Development & Testing

```powershell
# Deploy all metadata to default org
sf project deploy start -d force-app --ignore-conflicts

# Deploy specific Apex classes (no quotes, space-separated)
sf project deploy start -m ApexClass:QueryFactory ApexClass:Query ApexClass:QueryTest --ignore-conflicts

# Run all local tests after deployment
sf apex test run -l RunLocalTests -c

# Run specific test class
sf apex test run -t QueryFactoryTest -c
```

### Package Management

```powershell
# Create new package version
sf package version create --package "Injectify" --path force-app --wait 10 --installation-key-bypass --code-coverage

# Install package to target org
sf package install --package "Injectify@0.3.0-2" --target-org <alias> --wait 10
```

### Analysis & Verification

```powershell
# Analyze package API surface (what's exposed globally)
py scripts/py/package_api.py
# Output: docs/documentation/package_api.apex

# Static analysis (local, no org): Recommended plus AppExchange security-review rules
sf code-analyzer run -w force-app -r Recommended -r AppExchange -f analyzer.json
```

### Scratch Org Management

```powershell
# Create new scratch org
sf org create scratch --definition-file config/project-scratch-def.json --alias <alias> --description <alias> --duration-days 30

# Delete scratch org
sf org delete scratch -o <alias>
```

## Architecture Overview

### Component Hierarchy

```
Application (entry point; extends Core)
├── Core (ICore) - schema modeling, conditions, orderings, aggregates, work creation
├── QueryFactory (IQueryFactory) - SOQL query builders
├── DomainFactory (IDomainFactory) - domain layer & trigger handlers
├── ServiceFactory (IServiceFactory) - service layer instances
└── TriggeredFactory (ITriggeredFactory) - trigger execution & bypass
```

### Key Components

#### 1. Application / App (Entry Point)

- **Inside the package:** `Application.s` is a lazily made default instance with empty registries. It is `public`, so subscribers cannot reach it
- **In a subscriber org:** `inj.Application.make(...)` builds an instance with the subscriber's registries; by convention it is held in the subscriber's own `App` class as `App.s` (see `unify`). The guides are written that way
- **Extends:** Core (inherits modeling, filtering, condition building)
- **Manages:** Four primary factories (query, domain, service, triggered)

The examples below are written as code inside this repository, so they use `Application.s`.

```apex
// The package's default instance
Application app = Application.s;

// Use factories
IQueryFactory qf = app.qf();
IDomainFactory df = app.df();
IServiceFactory sf = app.sf();
ITriggeredFactory tf = app.tf();
```

#### 2. Core Layer (ICore)

Foundation providing:

- **Schema modeling:** `IModel`, `IPath`, `IReference` for SObject introspection
- **Condition builders:** `eq()`, `ne()`, `gt()`, `lt()`, `ge()`, `le()`, `lk()`, `iin()`, `nin()`, `inc()`, `exc()`; `iin()` and `nin()` also take an `IQuery` as the value, which makes a semi-join or anti-join; on a date or date-time field the value may be a date literal (`DateLiteral.lastNDays(30)`, or a `List<IDateLiteral>` for `iin`/`nin`)
- **Orderings and aggregates:** `ordering()`, `count()`, `countDistinct()`, `sum()`, `avg()`, `min()`, `max()`, and `aggregate(Enums.Aggregate, field)` to choose the function at run time
- **Work creation:** `work()` returns `IWork` for DML operations
- **Search:** `searchQuery(List<IQuery>)` returns `ISearchQuery`

#### 3. Query System

- **QueryFactory** creates Query instances; a query class is registered against the object's type (`Account.class => AccountQuery.class`)
- **Query** provides fluent API for SOQL building (fields, filters, orderings, limits)
- **Default fields** from the registered query class, or else every field except long text areas, formulas, namespaced fields, view dates, preference/permission flags and fields no user can be granted (`QueryFactory.defaultFieldScope`)
- **Security:** system mode by default, with the sharing of the class that builds the query (the query classes declare `inherited sharing`) unless the scheme has a sharing keyword of its own; `withSharing(true)` runs the query in user mode (sharing, object and field permissions), leaving out default fields the user cannot read; `withSecurity(true)` keeps the mode and refuses the query (`QueryException`) unless the running user may read the object and every field the SELECT names
- **Locking:** `forUpdate(true)` adds `FOR UPDATE` to `run()` and `fetch()`
- **Statement options:** `allRows(true)` (`ALL ROWS`), `usingScope(Enums.FilterScope.MINE)` (`USING SCOPE mine`), `forView(true)`, `forReference(true)`, written in the one order the platform takes (`... LIMIT n OFFSET n FOR VIEW|FOR REFERENCE` then `FOR UPDATE` or `ALL ROWS`). `count()` takes `ALL ROWS` and the scope; `toLocator()` all but the lock. `AggregateQuery` has `allRows` and `usingScope` only (the platform fails on the view marks there). Refused with the query's own `Query.UnifValidationException`, because the platform's message is `unexpected token`: view with reference, lock with all rows, all rows or a scope on a child subquery, all rows on a semi-join's inner query; a search refuses all rows and a scope with its `SearchException`, and takes only queries that are a `Query`. Left to the platform: a scope the object does not support ends the transaction with an uncatchable error, and Apex has no describe for it
- **Date literals:** `DateLiteral` (global; factories return `IDateLiteral`, the implementation is the public inner class `DateLiteral.Value`). Written inline and never bound (`Typing.bindable`), by `Typing.Comparison` for a field and by `Filtering.FieldCondition.aggregateLiteral` for a HAVING condition; both write through `DateLiteral.checked`, which reads a literal of another class from its text, so only a date literal reaches the SOQL. `ConditionParser` tokenizes them as `DATE_LITERAL` (`2026-01-31` is a `DATE_VALUE`). In memory `DateLiteral.Value.test` compares a day with the range `[firstDay, dayAfter)`, in the running user's time zone and locale. The global `startDate()` and `endDate()` on `IDateLiteral` give the first and last day, inclusive, through the default scheme. Fiscal ranges come from `Organization.FiscalYearStartMonth`, read through the scheme the comparison passes in (two queries, cached for the transaction); custom fiscal years throw, and so does a count over 365000, the platform's ceiling
- **Polymorphic lookups:** a path goes through one to the fields of `Schema.Name` (`What.Type`, `Owner.Name`): `Modeling.PolyPath.nameReference()` is the reference such paths start from (`Modeling.NameReference`), and `Modeling.beyond()` picks the model after a lookup. In memory `NameReference.read` and `follow` take a `Name` row, a row of the target itself or the Id alone; a group of any kind is `Queue`, as in SOQL. A target's own fields are selected with `TYPEOF` (`QueryFields.TypeofFields`); a path and `TYPEOF` through one lookup are refused when the SELECT is written (`QueryFields.checkOneReading`)
- **Child subqueries** keep their conditions, ordering, limit and offset (`Statement.nested`)
- **Semi-joins and anti-joins:** `iin(field, innerQuery)` / `nin(field, innerQuery)` write `field IN (SELECT ...)` / `NOT IN`. The inner query selects one field (the lookup field chosen, or Id when none is; a factory query needs `fields().clearFields()` first) and takes no limit or offset (`Query.checkJoinable` refuses anything else with a `UnifValidationException`); its values share the outer query's binds. `Query.semiJoinSoql` writes it, for `Query`, `AggregateQuery` (WHERE only: HAVING refuses with a `ConditionException`) and `Filtering.FieldCondition.toSoql()` (which SOSL uses). `withSecurity(true)` checks the inner object and field. It cannot be evaluated in memory or parsed from text. The platform's own rules (two per query, not under OR/NOT, top level of WHERE, different objects) are left to the platform; the query guide lists them. `inner` and `outer` are reserved words in Apex
- **The three faces:** a condition is written as SOQL (`toSoql`, `Query.Statement`), read from text (`ConditionParser`) and tested in memory (`ICondition.evaluate`). A condition feature needs all three, or a clear exception and a line in the query guide where one is impossible. In memory the answer has three values inside the package (`FieldCondition.test` and `LogicalCondition.test` return null for SOQL's "unknown", as for an empty number compared with `>`), so that NOT leaves such rows out as SOQL does; `evaluate` turns unknown into false. An empty `any` or `all` is a constant on every face (`Typing.constantSoql`, written on `COUNT(Id)` for HAVING, which `ConditionCompilation` is told with `grouped`), `neg` flips, and the parser types a value by its token, so quoted text stays text. What builds but is not SOQL (null with an ordering operator or `lk`, `lk` on a multi-select picklist) is refused when it is written (`Typing.Comparison.checkWritable`) and is unknown in memory. The guide's section "Testing records in memory" lists what was checked against the database and where the faces still differ

```apex
IQuery q = Application.s.qf().make(Account.SObjectType);
q.fields().add(new Set<SObjectField>{ Account.Name, Account.Industry });
q.filters().add(Application.s.eq(Account.BillingCity, 'Seattle'));
q.orderings().add(Application.s.ordering(Account.Name, true, false)); // ascending, nulls first
q.setLimit(100);

List<SObject> results = q.run(); // values bound as :a0, :a1...
String soql = q.toSoql(); // values written inline (escaped), for display

// Semi-join: accounts that have a contact in Seattle
IQuery inSeattle = Application.s.model(Contact.SObjectType).query();
inSeattle.fields().add(new Set<SObjectField>{ Contact.AccountId });
inSeattle.filters().add(Application.s.eq(Contact.MailingCity, 'Seattle'));
q.filters().add(Application.s.iin(Account.Id, inSeattle));
// ... AND Id IN (SELECT AccountId FROM Contact WHERE (MailingCity = :a1))
```

#### 4. Aggregate Query System

- **AggregateQuery** provides fluent API for SOQL aggregate queries (COUNT, SUM, AVG, MIN, MAX, COUNT_DISTINCT)
- **Auto-aliasing** with concise suffixes: `cnt`, `sum`, `avg`, `min`, `max`, `dis`
- **Manual override** via `setAlias()` for custom alias names
- **ROLLUP/CUBE** support with automatic GROUPING() indicators (max 3 fields)
- **Compositional design** - alias logic lives in `IAggregateFunction`, not the query

**Auto-Generated Alias Pattern:**

- `{fieldname}_{suffix}` - e.g., `Amount_sum`, `Id_cnt`
- No-field `count(null)` → `COUNT(Id) cnt` (a bare `COUNT()` cannot take an alias)
- COUNT_DISTINCT → `{fieldname}_dis` (e.g., `AccountId_dis`)
- GROUPING() → `{fieldname}_grp` (e.g., `Type_grp`)

```apex
// Basic aggregate with auto-aliasing
IAggregateQuery q = Application.s.model(Opportunity.SObjectType).aggregateQuery();
q.aggregates().add(Application.s.sum(Opportunity.Amount));      // → Amount_sum
q.aggregates().add(Application.s.count(Opportunity.Id));        // → Id_cnt
q.aggregates().add(Application.s.countDistinct(Opportunity.AccountId)); // → AccountId_dis
q.groupBys().add(Application.s.path(Opportunity.StageName));

List<AggregateResult> results = q.run();
// SELECT StageName, SUM(Amount) Amount_sum, COUNT(Id) Id_cnt,
//        COUNT_DISTINCT(AccountId) AccountId_dis
// FROM Opportunity
// GROUP BY StageName

// Manual alias override
q.aggregates().add(Application.s.sum(Opportunity.Amount).setAlias('total_revenue'));

// ROLLUP with automatic GROUPING() indicators
IAggregateQuery rollupQuery = Application.s.model(Opportunity.SObjectType)
    .aggregateQuery()
    .rollup();
rollupQuery.aggregates().add(Application.s.sum(Opportunity.Amount));
rollupQuery.groupBys().add(Application.s.path(Opportunity.Type));
rollupQuery.groupBys().add(Application.s.path(Opportunity.StageName));

// SELECT Type, StageName, SUM(Amount) Amount_sum,
//        GROUPING(Type) Type_grp, GROUPING(StageName) StageName_grp
// FROM Opportunity
// GROUP BY ROLLUP(Type, StageName)

// HAVING clause for post-aggregation filtering
q.havingFilters().add(Application.s.gt(Application.s.sum(Opportunity.Amount), 100000));
```

**Key Features:**

- Aliases never return null - always auto-generated or manually set
- Same aggregate with different aliases = different Set members
- ROLLUP/CUBE automatically add GROUPING() indicators
- Validation: ROLLUP/CUBE limited to max 3 fields
- `run()` binds WHERE and HAVING values (`:a0`, `:a1`...) and goes through the scheme; `toSoql()` writes them inline, escaped

#### 5. Search Query System

- **SearchQuery** provides fluent API for SOSL (Salesforce Object Search Language)
- **Simplified WITH clause** via `setWith(String)` - just pass raw SOQL
- **Multi-object search:** one `IQuery` per object supplies its fields and filters
- **Scheme:** a search runs through the scheme of its first query when the scheme implements `ISearchScheme` (`SchemeDefault` and `MockScheme` do); user mode when any of its queries is in user mode
- **Search scopes:** `searchScope()` is a set of `Enums.SearchScope` (ALL, NAME, EMAIL, PHONE)
- **Escaping:** the search term's backslashes, braces and quotes are escaped (SOSL wildcards and operators still work); filter values inside RETURNING are escaped inline literals, since SOSL has no bind variables

```apex
// One query per object to search
IQuery accountQuery = Application.s.qf().make(Account.SObjectType);
accountQuery.fields().add(new Set<SObjectField>{ Account.Name, Account.Industry });
accountQuery.filters().add(Application.s.eq(Account.Type, 'Customer'));

IQuery contactQuery = Application.s.qf().make(Contact.SObjectType);
contactQuery.fields().add(new Set<SObjectField>{ Contact.Name, Contact.Email });

ISearchQuery customSearch = Application.s.searchQuery(new List<IQuery>{
    accountQuery,
    contactQuery
});

Map<SObjectType, List<SObject>> resultMap = customSearch.runAsMap('Acme');
// FIND {Acme} IN ALL FIELDS
// RETURNING Account(Name, Industry WHERE Type = 'Customer'),
//          Contact(Name, Email)

// WITH clause (raw SOSL)
customSearch.setWith('DIVISION=\'Global\' NETWORK=\'0DBxxx\' SNIPPET(target_length=100)');
```

See the [query guide](docs/documentation/query-guide.md) for the exact text each call produces.

**Simplified WITH Clause:**

- No validation, no ceremony - just pass the raw SOQL string (it is trusted text: never build it from user input)
- Perfect for making tables searchable without method bloat
- Examples: `DIVISION='value'`, `NETWORK='id'`, `SNIPPET`, `SPELL_CORRECTION=true`, `DATA CATEGORY`

#### 6. Domain System

- **DomainFactory** creates Domain instances; a domain class is registered against the object's type (`Account.class`)
- **DomainRecords** (behind `IDomain` and `BaseDomain`) encapsulates business logic and implements ITriggered for trigger handling
- **Trigger hooks:** `onBeforeUpsert()`, `onAfterUpsert()`, `onBeforeDelete()`, `onAfterDelete()`, `onAfterUndelete()`
- **Utilities:** filter(), sort(), segment(), catalog(), collectRecords(), getChangedRecords(), updateBlank(), updateDifferent(), and aggregate() for COUNT/COUNT_DISTINCT/SUM/AVG/MIN/MAX over the loaded records (nulls skipped)

```apex
// Register domain in Application setup: the key is the object's type, not its SObjectType token
Map<Type, Type> domainRegistry = new Map<Type, Type>{
    Account.class => AccountDomain.class
};

// Domain handles triggers automatically via TriggeredFactory
global class AccountDomain extends BaseDomain {
    public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
        // Custom business logic
    }
}
```

#### 7. Triggered System

- **TriggeredFactory** orchestrates trigger execution
- **Bypass management:** disable/enable per SObjectType and TriggerOperation; `disableWhen(ITriggeredBypass)` takes a subscriber's rule, asked before each trigger runs (e.g. one that reads a custom permission, so an admin can switch triggers off for a user)
- **Instance recycling:** Same Domain instance reused in BEFORE/AFTER phases
- **CRUD security:** Optional check of the running user's object permission per operation (create/update/delete/undelete); no field-level check

```apex
// In a subscriber's trigger file (the package ships no triggers)
trigger AccountTrigger on Account (before insert, after insert, before update, after update) {
    App.s.tf().execute();
}

// Disable specific triggers programmatically
Application.s.tf().disable(new Map<SObjectType, Set<TriggerOperation>>{
    Account.SObjectType => new Set<TriggerOperation>{ TriggerOperation.BEFORE_INSERT }
});
```

#### 8. Work Layer (IWork)

Unified DML transaction management with:

- **Operations:** track (insert/update), purge (delete), upsert (by external ID)
- **Relationship resolution:** Automatic parent-child linking
- **Dependency ordering:** Topological sort for purges (prevents FK violations)
- **Email/events:** Send emails and publish platform events
- **Access:** DML runs in system mode; `withSharing(true)` runs it in user mode
- **Partial success:** with `options().optAllOrNone = false`, `failures()` and `failureOf(record)` say which records were not saved and why (`IWorkFailure`); a record is not saved without the new record it depends on

```apex
Application.s.work()
    .track(newAccount)
    .track(contact, Contact.AccountId, newAccount) // Relationship; tracks the parent too
    .purge(oldRecord)
    .apply(); // Execute all operations (returns nothing; a work is applied once)
```

#### 9. Async System

Unified async operations using handler pattern and chaining:

- **Handler Pattern:** Implement `IQueueableHandler`, `IBatchQueryableHandler`, `IBatchIterableHandler`, or `ISchedulableHandler`
- **Factory Methods:** `Async.queueable()`, `Async.queryable()`, `Async.iterable()`, `Async.schedulable()`
- **Chaining:** `.then()` adds a job to the end of a singly linked chain (`IJob`); a job may appear once per chain, and chains are capped (20 waiting, 40 in a lineage)
- **Capture Modes:** SYNCHRONOUS, RELEASE, IMMEDIATE, PREPEND, APPEND, IGNORE
- **Shared Variables:** one map shared by every job in a chain (`IJob.setShared`/`getShared`); handlers implementing `IJobAware` get their job during each call
- **Test Mode:** `Async.synchronousInTests = true` (global) runs chains inline in tests; ignored outside tests

```apex
// Handler pattern with chaining
Async.queueable(new ProcessHandler())
    .then(Async.queryable(new BatchHandler()))
    .then(Async.queueable(new CleanupHandler()))
    .run();
```

**Job Types:** `QueueableJob`, `BatchQueryable`, `BatchIterable`, `SchedulableJob` (the `Job` suffix keeps the two names clear of `System.Queueable` and `System.Schedulable`)

## Extension Patterns & Documentation

### Extending the Framework

Subscribers can extend the framework by creating custom query and domain classes:

**BaseQuery Extension:**

- Extend `inj.BaseQuery` for custom query classes
- Override `onInitialized(IModel source)` hook for custom initialization
- Override `getDefaultFields()` to specify default field sets (leave it out and the factory selects every field)
- Declare the class `global`; overrides are `public` or `global`, never `protected`
- Call inherited `IQuery` methods directly (they are `global` on `Query` since 0.3.0-2); `base()` remains for older code

**BaseDomain Extension:**

- Extend `inj.BaseDomain` for custom domain/trigger classes
- Override `onBeforeUpsert(Map<Id, SObject> oldMap)` for INSERT/UPDATE logic
- Override `onAfterUpsert(Map<Id, SObject> oldMap)` for post-processing
- Check `oldMap == null` to distinguish INSERT from UPDATE
- Call inherited `IDomain` methods directly (they are `global` on `DomainRecords` since 0.3.0-2); `base()` remains for older code

**Example:**

```apex
global class AccountQuery extends inj.BaseQuery {
    global override Set<SObjectField> getDefaultFields() {
        return new Set<SObjectField>{ Account.Id, Account.Name, Account.Type };
    }
}

global class Accounts extends inj.BaseDomain {
    public override void onBeforeUpsert(Map<Id, SObject> oldMap) {
        if (oldMap == null) {
            // INSERT logic
        } else {
            // UPDATE logic
        }
    }
}
```

### Comprehensive Guides

For detailed information on using and extending the framework, see:

- **[Extension Guide](docs/documentation/extension-guide.md)** - How to extend BaseQuery and BaseDomain, cross-namespace patterns, factory registration
- **[Async Guide](docs/documentation/async-guide.md)** - Handler pattern, chaining, capture modes, testing async code
- **[Work Guide](docs/documentation/work-guide.md)** - DML operations, relationship handling, automatic ordering, performance characteristics
- **[Testing Guide](docs/documentation/testing-guide.md)** - Testing queries, domains, async operations, test data patterns, mocking
- **[Query Guide](docs/documentation/query-guide.md)** - Fields, lookups and polymorphic lookups, conditions (built, parsed, evaluated in memory), date literals, semi-joins and anti-joins, subqueries, statement options, aggregates, SOSL
- **[Utilities Guide](docs/documentation/utilities-guide.md)** - The twelve `global` utility classes in `util/` (test data, CSV, fields, records, persistent values, limits, UUIDs)

## Package API Design Principles

The package is unlocked. Subscribers reach only what is `global`, and a production org builds on it. This codebase follows strict API exposure rules so the implementation can change without breaking them:

### Golden Rules

1. **CRITICAL: Every return type = interface or standard type (NO concrete classes)**
   - Global methods must return: Salesforce standard types OR global interfaces
   - NEVER return public/concrete implementations from global methods

2. **Expose abstractions (interfaces), hide implementations (classes)**
   - Interfaces are `global` (define contracts)
   - Implementations are `public` (evolve freely). The two exceptions are `Query` and `DomainRecords`: they are `global`, with the interface's methods `global` on them, so a subscriber's subclass of `BaseQuery` or `BaseDomain` can call what it inherits without `base()`. Nothing beyond the interface's methods is `global` on them
   - Static methods are entry points

3. **Global = a promise to subscribers**
   - Subscriber code that calls a `global` stops compiling if its signature changes or it is removed, whatever the package type allows; a managed package would not allow the change at all
   - Add a `global` where a subscriber needs one; change or remove one only with a CHANGELOG entry that says it breaks

4. **Extension hooks are `global virtual`**
   - Hooks such as `onInitialized()`, `getDefaultFields()` and the trigger hooks are `global virtual` on `BaseQuery` and `BaseDomain`; subscribers override them as `public` or `global`
   - `protected` is used for inheritance inside the package only (e.g. `Application.Factory.isValidPair`)

5. **Value classes with nothing to hide may be `global`**
   - e.g. `LimitsUtil.Snapshot`, `UuidUtil.Converter`; a class that has an interface stays `public` behind it (`CharUtil.Charset`, `DebugUtil.Printer`, `IdUtil.Tracker`, `Persistent.Namespace`)

### API Change Workflow

**REQUIRED: ALWAYS run API analysis when making API changes**

Whenever you add, modify, or remove any `global` or `public` API surface (interfaces, classes, methods), you MUST run the API analysis script:

```powershell
py scripts/py/package_api.py
```

This generates `docs/documentation/package_api.apex` which shows the complete exposed API surface.

**When to run this:**

- Before deploying changes that touch global/public APIs
- After adding new global interfaces or methods
- After modifying method signatures
- Before creating a new package version

**What to verify:**

1. Review `docs/documentation/package_api.apex` for unintended exposures
2. Ensure all return types are interfaces or standard types (NOT public classes)
3. Verify method signatures match intended contracts
4. Check that deprecated APIs are properly marked

### Common Patterns

#### Pattern 1: Static Factory (No Type Relationship)

```apex
// Factory class (global) - NOT related to interface
global class FieldScope {
  global static IFieldScope make(Trait trait) {
    return new TraitScope(trait); // private impl
  }

  private class TraitScope implements IFieldScope {
    // Hidden implementation
  }
}
```

#### Pattern 2: Deep Tree Factory

```apex
// Entry point returns global type
global class Application {
    global static Application make() { return new Application(); }

    // Accessors return global interfaces (NOT implementations)
    public IQueryFactory qf() { return this.query; }
}

// Every node in tree returns interface or standard type
Application → IQueryFactory → IQuery → IQueryFields → Set<SObjectField>
```

#### Pattern 3: Base Classes for Extension

```apex
global abstract class BaseQuery extends Query implements IQuery {
  global BaseQuery(IModel model) {
    super();
    init(model);
  }

  // Template method: runs the hook the first time the query is bound to its object
  global override void init(IModel source) {
    Boolean wasInitialized = this.source() != null;
    super.init(source);
    if (!wasInitialized) {
      onInitialized(source);
    }
  }

  // Hook for subscriber override
  global virtual void onInitialized(IModel source) {
  }

  // Cross-namespace access
  global IQuery base() {
    return (IQuery) this;
  }
}
```

### API Design Decision Tree

When designing new APIs, use this decision tree:

- Need abstraction/contract? → `global interface`
- Concrete implementation? → `public class` + `global interface`
- Extension base class? → `global abstract class` with `global virtual` hooks
- Static utility? → `global class` with `global static` methods

**Remember:** Always run `py scripts/py/package_api.py` after making changes (see API Change Workflow above)

## File Organization

```
force-app/classes/
├── application/            # Application class (entry point, Application.s) + 4 factories
├── core/                   # Foundation (modeling, filtering, DI)
├── query/                  # Query builders & SOQL compilation
├── domain/                 # Domain layer & trigger handlers
├── work/                   # DML transaction management
├── async/                  # Async operations & chaining
└── util/                   # Utilities (CSV, Field, Id, String, etc.); global, with implementations behind interfaces
```

Each component directory contains:

- Implementation classes (public)
- Interface definitions (global interfaces in `interfaces/` subdirectory)
- Test classes (\*Test.cls)

## Testing Requirements

- Every Apex class has a corresponding test class (e.g., `QueryFactory.cls` → `QueryFactoryTest.cls`)
- When changing a class, update its test to match
- After deploying Apex, run all tests: `sf apex test run -l RunLocalTests -c`
- Package version creation requires code coverage

## Deployment Rules

### When to Deploy

Deploy when finished with the whole feature (not after each individual edit)

### Target Org Strategy

**CRITICAL: Repository-to-Org Mappings**

Each repository has its dedicated scratch org (`.sf/config.json` sets it as the target):

- this repository → `s-injectify` (package development)
- `../unify`, the subscriber repository → `s-unify` (subscriber org)

**NEVER deploy code from one repository to another repository's org!**

**Additional Rules:**

- ✅ **DO deploy to:** `s-injectify` from this repo (and `s-unify` from the subscriber repo)
- ❌ **DO NOT deploy to:** the `ns-*` namespace orgs (`ns-unif`, `ns-ify`, `ns-ij`, `ns-inj`, `ns-gly`)
- **Packaging orgs should remain empty** - they are only used for creating package versions
- The target org comes from `.sf/config.json` (read the file; never run `sf org list`)
- Scratch orgs automatically track local source changes

### Before Deployment

If you made changes to global/public APIs (interfaces, classes, methods):

```powershell
# REQUIRED: Analyze API exposure
py scripts/py/package_api.py
```

Review `docs/documentation/package_api.apex` to verify no unintended API exposure.

### Deployment Commands

**Always deploy to the default connected org (no -o flag needed):**

```powershell
# Multiple classes (space-separated, no quotes)
sf project deploy start -m ApexClass:Class1 ApexClass:Class2 ApexClass:Class3 --ignore-conflicts

# Entire directory
sf project deploy start -d force-app/classes --ignore-conflicts

# Always include --ignore-conflicts flag
# No namespace prefix required (e.g., no "inj")
# No -o/--target-org flag needed (uses default org automatically)
```

### After Deployment

If Apex was deployed, run all tests:

```powershell
sf apex test run -l RunLocalTests -c
```

Wait for successful deployment/test completion before proceeding.

## Important Notes

- **Namespace:** `inj` (used in subscriber orgs accessing package)
- **API Version:** All new metadata should use sourceApiVersion from `sfdx-project.json` (currently 68.0)
- **Initialization:** Application can be initialized empty (uses defaults) or with custom registries
- **Schemes:** `SchemeDefault` (describes cached per transaction) is used unless one is injected; `MockScheme` returns registered rows instead of querying, for tests
- **Trigger Setup:** Register Domain classes in domainRegistry (`Account.class => Accounts.class`), call `App.s.tf().execute()` in the subscriber's triggers
- **Work ordering:** Automatically uses topological sort for purges, can override with `.setOrder()`

## Subscriber Repository (Usage Examples)

The sibling repository `../unify` consumes the package from a subscriber org (`s-unify`): its own `App` class holding `inj.Application.make(...)`, custom queries and domains, trigger setup, and cross-namespace use of `inj.` types.
