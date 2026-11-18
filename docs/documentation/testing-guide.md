# Testing Guide

How to test code built on the framework: queries, domain classes and triggers, work, and async jobs. It covers what is specific to the framework, not Apex testing in general.

Examples are written from a subscriber org, so package types carry the `inj.` prefix. `App.s` is the subscriber's own entry point (a class that holds `inj.Application.make(...)`; see the [extension guide](extension-guide.md#your-entry-point)). `AccountQuery` and `Opportunities` are the example classes from that guide.

## Contents

1. [Testing queries](#testing-queries)
2. [Mocking queries with MockScheme](#mocking-queries-with-mockscheme)
3. [Testing domain classes](#testing-domain-classes)
4. [Testing work](#testing-work)
5. [Testing async jobs](#testing-async-jobs)
6. [What a subscriber test cannot do](#what-a-subscriber-test-cannot-do)

---

## Testing queries

### Assert on the SOQL

A query can be checked without running it. `toSoql()` writes values inline; `toSoql(true)` shows the placeholders `run()` binds.

```apex
@IsTest
static void filtersByIndustryAndRevenue() {
  AccountQuery big = ((AccountQuery) App.s.qf().make(Account.SObjectType)).inIndustry('Energy').overRevenue(1000000);

  Assert.areEqual(
    'SELECT Id, Name, Industry, AnnualRevenue FROM Account WHERE (Industry = \'Energy\' AND AnnualRevenue > 1000000)',
    big.base().toSoql()
  );
}
```

This is the quickest test of a custom query class: it shows that the class is registered, that its default fields are applied and that its helper methods add the conditions they should.

### Run it against records

To prove a query returns the right rows, insert records and run it:

```apex
@IsTest
static void returnsOnlyLargeEnergyAccounts() {
  insert new List<Account>{
    new Account(Name = 'Big Energy', Industry = 'Energy', AnnualRevenue = 5000000),
    new Account(Name = 'Small Energy', Industry = 'Energy', AnnualRevenue = 1000),
    new Account(Name = 'Big Retail', Industry = 'Retail', AnnualRevenue = 5000000)
  };

  AccountQuery big = ((AccountQuery) App.s.qf().make(Account.SObjectType)).inIndustry('Energy').overRevenue(1000000);
  List<Account> rows = (List<Account>) big.base().run();

  Assert.areEqual(1, rows.size());
  Assert.areEqual('Big Energy', rows[0].Name);
}
```

### Check a condition in memory

A condition gives the same answer in memory as in SOQL, so a rule can be tested on records that were never inserted:

```apex
@IsTest
static void theRuleMatchesLargeEnergyAccounts() {
  inj.ICondition rule = App.s.model(Account.SObjectType)
    .parseCondition('Industry = \'Energy\' AND AnnualRevenue > 1000000');

  Assert.isTrue(rule.evaluate(new Account(Industry = 'Energy', AnnualRevenue = 5000000)));
  Assert.isFalse(rule.evaluate(new Account(Industry = 'Retail', AnnualRevenue = 5000000)));
}
```

---

## Mocking queries with MockScheme

`inj.MockScheme` is a scheme for tests: describes are real, but queries return the rows you register instead of reading the database, and every query is recorded with its bind values. Inject it when you build the application under test:

```apex
@IsTest
static void flagsLargeAccounts() {
  List<Account> canned = new List<Account>{
    new Account(Name = 'Acme', AnnualRevenue = 5000000) // canned rows need no Id
  };
  inj.MockScheme scheme = new inj.MockScheme().returning(Account.SObjectType, canned);
  inj.IApplication app = inj.Application.make(scheme);

  List<Account> flagged = new AccountReview(app).largeAccounts(); // queries through app; no inserts needed

  Assert.areEqual(1, flagged.size());
  Assert.areEqual(1, scheme.queries().size());
  Assert.areEqual(1000000, scheme.bindMaps()[0].get('a0'));
}
```

The code under test has to query through the application it is given, so pass the application in rather than reaching for `App.s` inside:

```apex
public class AccountReview {
  private inj.IApplication app;

  public AccountReview(inj.IApplication app) {
    this.app = app;
  }

  public List<Account> largeAccounts() {
    inj.IQuery large = app.qf().make(Account.SObjectType);
    large.addCondition(app.gt(Account.AnnualRevenue, 1000000));
    return (List<Account>) large.run();
  }
}
```

What the mock does:

- A query returns the rows registered for its outermost FROM object, as a list of that object's type (empty if nothing was registered), so casts such as `(List<Account>) q.run()` work.
- The rows come back as registered. Conditions, ordering and limits are recorded but not applied.
- `count()` returns the number of registered rows.
- Aggregate queries return no rows: Apex cannot build an `AggregateResult`.
- `toLocator()` still reads the database, since a query locator can only come from a real query.
- `queries()` lists the SOQL of every query so far; `bindMaps()` the bind values of each, in the same order.

Searches are mocked the same way. A search returns one list per object named after `RETURNING`, in that order, holding the rows registered for that object, and its SOSL is recorded with the queries (with no bind values):

```apex
inj.MockScheme scheme = new inj.MockScheme().returning(Account.SObjectType, canned);
inj.IApplication app = inj.Application.make(scheme);
inj.IQuery accounts = app.qf().make(Account.SObjectType);
inj.IQuery contacts = app.qf().make(Contact.SObjectType);

List<List<SObject>> found = app.searchQuery(new List<inj.IQuery>{ accounts, contacts }).run('Acme');
// found[0] is the canned accounts; found[1] is an empty List<Contact>
// scheme.queries()[0] starts with FIND {Acme} RETURNING Account(
```

An application made with `inj.Application.make(scheme)` has empty registries. To use your registered classes with a mock, call the longer `make` with the same registries your `App` uses.

---

## Testing domain classes

### Through the trigger

The end-to-end test: do the DML and assert on what the trigger left behind.

```apex
@IsTest
static void aWonDealGetsAWelcomeTask() {
  Opportunity deal = new Opportunity(Name = 'Big deal', StageName = 'Prospecting', CloseDate = Date.today());
  insert deal;
  Assert.areEqual('Qualify', [SELECT NextStep FROM Opportunity WHERE Id = :deal.Id].NextStep);

  deal.StageName = 'Closed Won';
  update deal;

  Assert.areEqual(1, [SELECT COUNT() FROM Task WHERE WhatId = :deal.Id AND Subject = 'Send the welcome pack']);
}
```

### Calling a hook directly

A hook is an ordinary method, so a before hook can be tested with no DML at all. Build the domain on records in memory and call it:

```apex
@IsTest
static void aBlankNextStepIsDefaulted() {
  List<Opportunity> deals = new List<Opportunity>{
    new Opportunity(Name = 'One'),
    new Opportunity(Name = 'Two', NextStep = 'Negotiate')
  };

  new Opportunities(deals).onBeforeUpsert(null); // null oldMap: an insert

  Assert.areEqual('Qualify', deals[0].NextStep);
  Assert.areEqual('Negotiate', deals[1].NextStep);
}
```

For an update, pass the earlier versions as `oldMap`. The records need Ids to be matched to it; a test can make them up:

```apex
@IsTest
static void onlyStageChangesCount() {
  Id fakeId = Opportunity.SObjectType.getDescribe().getKeyPrefix() + '000000000001';
  Opportunity before = new Opportunity(Id = fakeId, StageName = 'Prospecting', Amount = 100);
  Opportunity after = new Opportunity(Id = fakeId, StageName = 'Prospecting', Amount = 500);

  List<SObject> changed = new Opportunities(new List<Opportunity>{ after })
    .base()
    .getChangedRecords(new Map<Id, SObject>{ fakeId => before }, new Set<SObjectField>{ Opportunity.StageName });

  Assert.areEqual(0, changed.size());
}
```

### Switching triggers off

Setup data often should not run through your trigger logic. Switch it off around the insert:

```apex
@TestSetup
static void makeData() {
  App.s.tf().disable();
  insert new Opportunity(Name = 'Seed', StageName = 'Closed Won', CloseDate = Date.today());
  App.s.tf().enable();
}
```

`disable(new List<SObjectType>{ Opportunity.SObjectType })` switches off one object. Static state does not carry from `@TestSetup` into test methods, but within one method remember to switch triggers back on before the code under test runs.

---

## Testing work

A work does real DML, so its tests insert, update and delete for real and assert on the database:

```apex
@IsTest
static void theContactIsLinkedToItsNewAccount() {
  Account company = new Account(Name = 'Acme');
  Contact person = new Contact(LastName = 'Lovelace');

  App.s.work().track(person, Contact.AccountId, company).apply();

  Assert.areEqual(company.Id, [SELECT AccountId FROM Contact WHERE Id = :person.Id].AccountId);
}
```

Things that behave differently in a test:

- **Emails are not sent.** A tracked email is accepted and skipped, so `Limits.getEmailInvocations()` stays at zero.
- **Platform events** are published to the test event bus and delivered at `Test.stopTest()` or `Test.getEventBus().deliver()`.

To check that code decided to do nothing, ask the work before applying it:

```apex
inj.IWork work = App.s.work();
new Renewals(work).prepare(noRecords);
Assert.isFalse(work.hasWork());
```

That needs the code under test to take the work as a parameter instead of making its own, which is also what lets several pieces of logic share one `apply()`.

---

## Testing async jobs

The platform runs async jobs started in a test when `Test.stopTest()` is reached, one level deep: a job enqueued by a job does not run, and a batch runs a single `execute`.

```apex
@IsTest
static void stampsTheAccounts() {
  Account row = new Account(Name = 'Acme');
  insert row;

  Test.startTest();
  inj.Async.queueable(new StampAccounts(new Set<Id>{ row.Id })).run();
  Test.stopTest();

  Assert.isTrue([SELECT Description FROM Account WHERE Id = :row.Id].Description.startsWith('Stamped'));
}
```

To test a handler's logic on its own, call it directly: `new StampAccounts(ids).queueableExecute();`.

To test a whole chain, set `inj.Async.synchronousInTests = true` first. Every job then runs in the test's own transaction, in chain order:

```apex
@IsTest
static void theWholeChainRuns() {
  inj.Async.synchronousInTests = true;

  inj.Async.queueable(new CountAccounts()).then(inj.Async.queueable(new ReportCount())).run();

  // every job has run; assert on the results
}
```

The [async guide](async-guide.md#testing) has the details, including values shared along a chain.

---

## What a subscriber test cannot do

- **Subclass `Query`, `DomainRecords` or the factories.** They are not visible outside the package. Test doubles extend `inj.BaseQuery` or `inj.BaseDomain`, or implement a global interface such as `inj.ITriggered` or `inj.IScheme`.
- **Fake an `AggregateResult`.** Put aggregate logic behind a method of your own that returns plain values, and stand that method in.
- **Replace `App.s` from outside.** Its setter is private in the example `App`. Either pass the application into the code under test (as `AccountReview` does above), or give `App` a `@TestVisible` way to set it.

See also: [query guide](query-guide.md), [work guide](work-guide.md), [extension guide](extension-guide.md).
