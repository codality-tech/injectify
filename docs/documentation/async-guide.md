# Async Guide

Queueable, batch and schedulable jobs, built from small handler classes, chained in sequence, and kept within the platform's rules about which job may start which.

Examples are written from a subscriber org, so package types carry the `unif.` prefix. `App.s` is the subscriber's own entry point (a class that holds `unif.Application.make(...)`).

## Contents

1. [Job types](#job-types)
2. [Handlers](#handlers)
3. [Running and chaining](#running-and-chaining)
4. [Jobs started inside jobs: capture](#jobs-started-inside-jobs-capture)
5. [Shared values](#shared-values)
6. [Testing](#testing)
7. [Platform limits the engine works around](#platform-limits-the-engine-works-around)

---

## Job types

| Type | Factory | Handler interface | Returns |
| --- | --- | --- | --- |
| Queueable | `unif.Async.queueable(handler)` | `IQueueableHandler` | `IQueueable` |
| Batch over a query | `unif.Async.queryable(handler)` | `IBatchQueryableHandler` | `IBatchQueryable` |
| Batch over an iterable | `unif.Async.iterable(handler)` | `IBatchIterableHandler` | `IBatchIterable` |
| Schedulable | `unif.Async.schedulable(handler)` | `ISchedulableHandler` | `ISchedulable` |

Every factory returns an `IJob`: `then(next)`, `run()` and `getJobId()`.

---

## Handlers

A handler holds only your logic; the framework supplies the platform plumbing.

### IQueueableHandler

```apex
global interface IQueueableHandler extends IHandler {
  void queueableExecute();
}
```

```apex
public class StampAccounts implements unif.IQueueableHandler {
  private Set<Id> accountIds;

  public StampAccounts(Set<Id> accountIds) {
    this.accountIds = accountIds;
  }

  public void queueableExecute() {
    List<Account> rows = [SELECT Id FROM Account WHERE Id IN :accountIds];
    for (Account row : rows) {
      row.Description = 'Stamped ' + System.now();
    }
    update rows;
  }
}

unif.Async.queueable(new StampAccounts(ids)).run();
```

`IQueueable.setMinuteDelay(n)` delays the enqueue by 0 to 10 minutes; other values are ignored.

### IBatchQueryableHandler

```apex
global interface IBatchQueryableHandler extends IHandler {
  IQuery batchStart(); // the records to process
  void batchExecute(List<SObject> scope);
  void batchFinish();
  Integer batchDefaultSize(); // records per execute; null or under 1 means 200
}
```

```apex
public class ArchiveInactive implements unif.IBatchQueryableHandler {
  public unif.IQuery batchStart() {
    unif.IQuery inactive = App.s.qf().make(Account.SObjectType);
    inactive.addCondition(App.s.eq(Account.Active__c, 'No'));
    return inactive;
  }

  public void batchExecute(List<SObject> scope) {
    for (Account row : (List<Account>) scope) {
      row.Status__c = 'Archived';
    }
    update scope;
  }

  public void batchFinish() {
  }

  public Integer batchDefaultSize() {
    return 200;
  }
}

unif.Async.queryable(new ArchiveInactive()).run();
```

The query's filters run as bind variables. `IBatch.setBatchSize(n)` overrides the handler's size for one run; it must be positive.

### IBatchIterableHandler

For data that does not come from a query: callout results, generated work items, and so on.

```apex
global interface IBatchIterableHandler extends IHandler {
  Iterable<Object> batchStart();
  void batchExecute(Iterable<Object> scope);
  void batchFinish();
  Integer batchDefaultSize();
}
```

### ISchedulableHandler

```apex
global interface ISchedulableHandler extends IHandler {
  void schedulableExecute();
  String name(); // the scheduled job's name; blank uses the handler's class name
  String cronExpression(); // when to run; blank means one minute from now
}
```

```apex
public class NightlyReport implements unif.ISchedulableHandler {
  public void schedulableExecute() {
    ReportService.sendNightly();
  }
  public String name() {
    return 'Nightly report';
  }
  public String cronExpression() {
    return '0 0 2 * * ?';
  }
}

unif.ISchedulable nightly = unif.Async.schedulable(new NightlyReport());
nightly.run(); // schedules it: System.schedule(name(), cronExpression(), job)
nightly.unschedule(); // aborts every scheduled job with this name
```

`ISchedulable.toCronExpression(datetime)` builds a one-time expression for a given moment.

---

## Running and chaining

`run()` starts a job. `then(next)` adds a job to the end of the chain; when a job finishes, the next one starts. `then` returns the job it was called on, so a chain reads in order:

```apex
unif.Async.queueable(new PrepareData())
  .then(unif.Async.queryable(new ProcessRows()))
  .then(unif.Async.queueable(new NotifyOwners()))
  .run();
```

- A queueable hands over when its `execute` ends, a batch when `finish` ends, and a schedulable when its scheduled run ends. So the batch above runs to completion before `NotifyOwners` is enqueued.
- A job can appear in a chain only once. Adding it twice throws `Chainable.ChainableException`.
- Chains are guarded against runaways (for example, a job that keeps starting itself): at most 20 jobs may wait behind a running job, and a chain's whole lineage may hold at most 40. Going past either throws `ChainableException`.

---

## Jobs started inside jobs: capture

When code running inside a job calls `run()` on another job (in a queueable's `execute`, or a batch's `start`, `execute` or `finish`), the platform's rules decide what can start from there. The engine does not start the inner job straight away. The running job *captures* it, and acts on it when the current step finishes successfully. If the step throws, everything it captured is discarded.

### Modes

```apex
global enum CaptureMode {
  SYNCHRONOUS, // run it now, in this transaction
  RELEASE, // start it as a job of its own
  IMMEDIATE, // bundle it into one queueable that starts as soon as possible
  PREPEND, // run it before the rest of the chain
  APPEND, // run it after the rest of the chain
  IGNORE // drop it
}
```

When the step finishes, captured jobs are handled in this order:

1. **SYNCHRONOUS** jobs run, in the current transaction.
2. The chain is rebuilt as: **RELEASE** jobs (in tests only; outside tests they start on their own right away), then one queueable bundling every **IMMEDIATE** job, then **PREPEND** jobs, then the jobs that were already waiting, then **APPEND** jobs.
3. **IGNORE** jobs are dropped.

Bundling is what lets a queueable start several queueables even though the platform allows it to enqueue only one: the bundle is that one, and it runs each job inside it. When the capturing job is a batch, the bundle starts at once rather than waiting its turn.

A batch released while another batch is in its start or execute step cannot start there: the platform allows a batch to start a batch only from finish. It rides in the same bundle instead, and the bundle starts it a moment later as a job of its own.

### Defaults

Unless you say otherwise, the mode depends on the two job types:

| Running job ↓ \ started job → | Queueable | Batch | Schedulable |
| --- | --- | --- | --- |
| Queueable | IMMEDIATE | RELEASE | RELEASE |
| Batch | IMMEDIATE | RELEASE | RELEASE |
| Schedulable | RELEASE | RELEASE | RELEASE |

### Choosing the mode yourself

A handler that also implements `IHandlerCapturing` decides for the jobs started inside it. Return null to fall back to the defaults.

```apex
global interface IHandlerCapturing extends IHandler {
  Enums.CaptureMode getCaptureMode(IJob parentJob, IJob childJob);
}
```

```apex
// Retries up to three times, each retry waiting behind the rest of the chain.
public class SyncWithRetry implements unif.IQueueableHandler, unif.IHandlerCapturing {
  private Integer attempt;

  public SyncWithRetry(Integer attempt) {
    this.attempt = attempt;
  }

  public void queueableExecute() {
    try {
      ExternalSystem.sync();
    } catch (CalloutException failure) {
      unif.Async.queueable(new SyncWithRetry(attempt + 1)).run();
    }
  }

  public unif.Enums.CaptureMode getCaptureMode(unif.IJob parentJob, unif.IJob childJob) {
    return attempt < 3 ? unif.Enums.CaptureMode.APPEND : unif.Enums.CaptureMode.IGNORE;
  }
}

unif.Async.queueable(new SyncWithRetry(1)).run();
```

Inside the package, a job class can also override `Chainable.captureModeFor(child)`; it is asked before the handler.

---

## Shared values

Every job in a chain shares one map of values. Set them on any job with `setShared(key, value)`, before or after chaining, and read them with `getShared(key)`. Values set by one job are there for the jobs after it, across transactions. `getShared` of a key nobody has set is null.

A batch job is stateful (`Database.Stateful`), and it holds its handler: what a handler keeps in its own fields carries from one `batchExecute` to the next and into `batchFinish`.

A handler that implements `IJobAware` is handed its job while it runs:

```apex
public class CountAccounts implements unif.IQueueableHandler, unif.IJobAware {
  private unif.IJob job;

  public void setJob(unif.IJob job) {
    this.job = job;
  }

  public void queueableExecute() {
    job.setShared('accountCount', [SELECT COUNT() FROM Account]);
  }
}

public class ReportCount implements unif.IQueueableHandler, unif.IJobAware {
  private unif.IJob job;

  public void setJob(unif.IJob job) {
    this.job = job;
  }

  public void queueableExecute() {
    Integer counted = (Integer) job.getShared('accountCount');
    // ...
  }
}

unif.IJob chain = unif.Async.queueable(new CountAccounts()).then(unif.Async.queueable(new ReportCount()));
chain.setShared('requestedBy', UserInfo.getUserId());
chain.run();
```

The job is set just before each handler call (every phase of a batch) and cleared right after, so keep it in a field only for the duration of the call. Shared values travel with the jobs, so keep them small and serializable.

---

## Testing

The platform runs async jobs started in a test when `Test.stopTest()` is reached, one level deep: a job enqueued by a job does not run, and a batch runs a single `execute`.

```apex
@IsTest
static void stampsTheAccounts() {
  Account row = new Account(Name = 'Acme');
  insert row;

  Test.startTest();
  unif.Async.queueable(new StampAccounts(new Set<Id>{ row.Id })).run();
  Test.stopTest();

  Assert.isTrue([SELECT Description FROM Account WHERE Id = :row.Id].Description.startsWith('Stamped'));
}
```

To test a handler's logic on its own, call it directly: `new StampAccounts(ids).queueableExecute();`.

To test a whole chain, set `unif.Async.synchronousInTests = true`: every job then runs in the test's own transaction, in chain order, with captured jobs handled as described above. The switch only takes effect while a test is running.

```apex
@IsTest
static void theWholeChainRuns() {
  unif.Async.synchronousInTests = true;

  unif.Async.queueable(new CountAccounts()).then(unif.Async.queueable(new ReportCount())).run();

  // every job has run; assert on the results
}
```

---

## Platform limits the engine works around

- A queueable may enqueue only one queueable: captured queueables are bundled into one.
- A job started inside a queueable or batch waits until the step that started it has finished, then starts on its own.
- A batch cannot start another batch from its start or execute step: a queueable carries the new batch out and starts it.
- Not covered: a batch started from inside a batch class of your own (one that is not a framework job). Nothing is capturing there, so the platform's refusal reaches your code. Start it from that batch's finish.
- A test runs only one level of async work: `unif.Async.synchronousInTests = true` runs the whole chain inline.

For other limits (jobs per transaction, concurrent batches, scheduled jobs per org), see Salesforce's Apex governor limits.

## See also

- [Extension guide](extension-guide.md): extending `BaseQuery` and `BaseDomain`
- [Work guide](work-guide.md): DML through `IWork`
- [Testing guide](testing-guide.md)
