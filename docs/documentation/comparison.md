# How It Compares

Most of what this framework does exists elsewhere in the Apex ecosystem, often in more mature form. This page says where each idea already lives, what is different here, and when another library is the better choice. The comparisons reflect each project's public code and documentation as of November 2026; corrections are welcome.

## At a glance

| Area | Established options | What is different here |
|---|---|---|
| SOQL builder, typed relationship paths, `TYPEOF` | [Nebula Query & Search](https://github.com/jongpie/NebulaQueryAndSearch), [SOQL Lib](https://soql.beyondthecloud.dev/), fflib's `QueryFactory` | One path object serves SELECT, WHERE, ORDER BY and reading values from records |
| One condition for SOQL and for records in memory | [`fflib_Criteria`](https://github.com/wimvelzeboer/fflib-apex-extensions/blob/main/docs/criteria-based-filter.md), [apex-rollup](https://github.com/jamessimone/apex-rollup), [Moxygen](https://github.com/ZackFra/Salesforce-Moxygen), [Trigger Actions Framework](https://github.com/mitchspano/trigger-actions-framework) formula filters | Builders, a text parser and the in-memory evaluator all share one schema-checked condition model |
| Trigger handling | [Trigger Actions Framework](https://github.com/mitchspano/trigger-actions-framework), [fflib-apex-common](https://github.com/apex-enterprise-patterns/fflib-apex-common) domains, [sfdc-trigger-framework](https://github.com/kevinohara80/sfdc-trigger-framework) | Domain classes double as record utilities (filter, sort, catalog, aggregate) using the same conditions and paths |
| Unit of work | fflib's `UnitOfWork`, [DML Lib](https://dml.beyondthecloud.dev/), [kerndx](https://github.com/JVB-Consulting/kerndx) | Deletes ordered per record from the lookups actually populated, with no registration |
| Async chains | [Async Lib](https://async.beyondthecloud.dev/), [apex-chainable](https://github.com/rsoesemann/apex-chainable) (which this framework's chain builds on) | Jobs started inside a job are captured by mode, and several queueables can run as one bundle |
| Test doubles | [ApexMocks](https://github.com/apex-enterprise-patterns/fflib-apex-mocks), [apex-mockery](https://github.com/salesforce/apex-mockery) | A scheme seam for describes and queries only (`MockScheme`); not a general mocking library |

## Queries and paths

**Elsewhere.**
- **Nebula Query & Search** has built queries from typed field chains (`List<Schema.SObjectField>`) since 2019, and writes `TYPEOF` for polymorphic fields.
- **SOQL Lib** added a typed `SOQL.TypeOf` in v6.13.0 (October 2026). It has a full documentation site with a playground.
- fflib's `QueryFactory` resolves related fields by name and does not write `TYPEOF`.

**Here.** A path such as `Contact → Account → Owner.Name` is one object, checked against the schema when it is built. The same path:
- selects the field (`fields().add(...)`);
- filters on it (`App.s.eq(path, value)`);
- orders by it (`App.s.ordering(path, ...)`);
- reads its value from a record in memory (`path.getFieldValue(record)`).

Lookups with one target and polymorphic lookups are different types (`MonoPath` and `PolyPath`), so only the first can be extended into a longer path. See the [query guide](query-guide.md#2-selecting-fields).

## Conditions in SOQL and in memory

**Elsewhere.** This idea has prior art:
- **`fflib_Criteria`** (fflib-apex-extensions, 2021) evaluates criteria against records at run time or renders them as a SOQL condition. It also takes formula-style criteria (`'(1 OR 2) AND 3'`), and Salesforce.org's NPSP includes it.
- **apex-rollup** applies a text WHERE clause to child records in memory.
- **Moxygen** parses and answers most SOQL queries against an in-memory database.
- **Trigger Actions Framework** evaluates formula strings against trigger records.

**Here.**
- Conditions built in code (`App.s.eq`, `all`, `any`) and conditions parsed from text (`model.parseCondition('Industry = ...')`) are the same objects.
- They are checked against the schema when created: a value of the wrong type throws then, not at query time.
- When a query runs, each condition value is a bind variable (`:a0`). The same condition can also write itself inline, escaped, for display.
- `prepend()` moves a condition one relationship out, so a condition on Account can filter Contacts by their Account.

See the [query guide](query-guide.md#3-conditions).

## Trigger handling

**Elsewhere.** The **Trigger Actions Framework** configures trigger actions in custom metadata and runs Apex and Flow actions in a defined order. Admins can manage it, and it has its own documentation site. fflib's domain layer is the established pattern, with Trailhead modules and a book behind it.

**Here.** One domain class per object handles its trigger events, with bypass switches in code, bypass rules that can read a custom permission (so an admin can switch triggers off for a user without a deployment), and an optional object-permission check. The same class is a set of record utilities (`filter`, `sort`, `segment`, `catalog`, `aggregate`, change detection), using the framework's conditions and paths. There is no Flow integration and no metadata-driven ordering. If admins need to configure trigger behavior, the Trigger Actions Framework fits better.

## Unit of work

**Elsewhere.**
- fflib's `UnitOfWork` needs the object types registered in dependency order.
- **DML Lib** v3.0 (January 2026) orders inserts record by record in dependency "waves". Records can be registered in any order, and a custom order switches the dependency graph off.
- **kerndx** (2026) orders object types topologically, in reverse for deletes.

**Here.**
- `track()` decides between insert and update from the Id.
- New parents and children are linked with `track(child, lookupField, parent)` and inserted level by level.
- Deletes are ordered per record from the lookup fields actually populated across the records being deleted. Nothing needs to be registered, and `setOrder()` overrides it.

For inserts, DML Lib does the same job. The delete ordering is the narrow difference. See the [work guide](work-guide.md).

## Async chains

**Elsewhere.**
- **apex-chainable** provides the chain this framework builds on: `then()` and a value map shared along the chain.
- **Async Lib** (2025) handles jobs started inside a running job by adding them to that chain, and spills over to a scheduled batch near the platform's enqueue limit.

**Here.** A job started inside another job is captured, and what happens to it is decided by a capture mode: run now, release, bundle, prepend, append or ignore. The default depends on both job types. Bundling runs several captured queueables inside a single queueable, which gets around the platform's limit of one enqueue from an asynchronous context. The trade-off is real: bundled jobs share one transaction's governor limits. We are not aware of another library that bundles this way. See the [async guide](async-guide.md).

## Test doubles

**ApexMocks** and **apex-mockery** mock any interface through the Stub API, and this framework doesn't try to replace them. Its own seam is narrower. Every describe and query goes through an `IScheme`, and `MockScheme` returns rows you register (typed to the queried object), recording the SOQL and bind values. Code under test can then query without inserting data. See the [testing guide](testing-guide.md#mocking-queries-with-mockscheme).

## When to choose something else

- **You want trigger orchestration that admins can configure, including Flow:** use the Trigger Actions Framework.
- **You want the established enterprise patterns with the largest community, training and books:** use fflib-apex-common.
- **You only need a query builder, with excellent documentation:** use SOQL Lib.
- **You need logging:** use [Nebula Logger](https://github.com/jongpie/NebulaLogger). This framework has none.
- **You need a long track record:** this version is new, with one maintainer and no CI yet.

## Status

The framework is at 0.3.0, its first release as the unlocked package Injectify (namespace `inj`). The API may change before 1.0. A community, a documentation site and CI are still to come. The [changelog](../../CHANGELOG.md) lists what has changed.
