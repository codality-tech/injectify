# Work Guide

`IWork` is a unit of work: you tell it which records to insert, update, upsert and delete, which emails to send and which platform events to publish, and `apply()` does it all in dependency order with as few DML statements as it can.

Examples are written from a subscriber org, so package types carry the `inj.` prefix. `App.s` is the subscriber's own entry point (a class that holds `inj.Application.make(...)`; see the [extension guide](extension-guide.md#your-entry-point)).

## Contents

1. [The basics](#the-basics)
2. [Inserting related records](#inserting-related-records)
3. [Deleting](#deleting)
4. [Upserting](#upserting)
5. [Emails and platform events](#emails-and-platform-events)
6. [Tracking a record more than once](#tracking-a-record-more-than-once)
7. [DML options and partial success](#dml-options-and-partial-success)
8. [Running as the user](#running-as-the-user)
9. [What apply() does, in order](#what-apply-does-in-order)
10. [Errors and limits](#errors-and-limits)

---

## The basics

```apex
inj.IWork work = App.s.work();
```

`track()` takes a record to save. A record without an Id is inserted; a record with one is updated.

```apex
Account fresh = new Account(Name = 'Acme');
Account known = [SELECT Id FROM Account WHERE Name = 'Globex' LIMIT 1];
known.Rating = 'Hot';

App.s.work().track(fresh).track(known).apply();
// fresh.Id is now set
```

`purge()` takes a record to delete:

```apex
App.s.work().purge(staleContacts).apply();
```

Both take one record or a list, and every method except `apply()` returns the work, so calls chain. Null records and null lists are ignored.

Nothing touches the database until `apply()`. With nothing tracked, `apply()` does nothing; `hasWork()` tells you beforehand.

**A work is applied once.** It keeps what it was given, so a second `apply()` would try to insert the same records again. Make a new work for the next set of changes.

**Access.** Work runs its DML in system mode and inherits the sharing of the class that calls it. It asks the platform for system mode on every statement, so this does not depend on what an API version does when no mode is given. The running user's object and field permissions are not checked unless you ask: `withSharing(true)` runs the work in user mode, where the platform checks them (see [Running as the user](#running-as-the-user)).

---

## Inserting related records

### A new child of a new parent

Neither record has an Id yet, so name the lookup and the parent, and the work fills the lookup in once the parent has been inserted:

```apex
Account company = new Account(Name = 'Acme');
Contact person = new Contact(LastName = 'Lovelace');
Case question = new Case(Subject = 'Where is my order?');

App.s.work()
  .track(person, Contact.AccountId, company)
  .track(question, Case.ContactId, person)
  .track(question, Case.AccountId, company)
  .apply();
// company, then person, then question: three inserts, no updates
```

`track(record, lookupField, parent)` tracks both records, so the parent needs no `track()` call of its own.

How the order is worked out:

1. Each new record gets a level: one more than the deepest new parent it was related to. Records with no new parent are level 0.
2. Levels are inserted in turn, one insert statement per object type in the level.
3. Just before a level goes in, its records' lookups are filled from parents that have an Id by then. So a child is inserted with its lookup already set, which is what required lookups and master-detail fields need.

The parent can also be a record that already exists; the lookup is then filled before the child's insert in the same way. Because `track(record, lookupField, parent)` tracks the parent as well, an existing parent is also updated (one more statement, and its triggers run). To avoid that, set the lookup yourself (`person.AccountId = company.Id`) and track only the child.

New records that depend on each other in a circle (A's parent is B and B's parent is A) cannot be ordered: `apply()` throws before inserting anything.

### A parent known by its external Id

When the parent exists and you hold its external Id rather than its record Id:

```apex
Contact person = new Contact(LastName = 'Hopper');

App.s.work()
  .track(person, Contact.AccountId, Account.External_Id__c, 'ACME-001')
  .apply();
```

The field must be marked as an external Id on the parent object, or `track` throws. The child is inserted first and the lookup is set by an update straight after, so this form does not suit a required lookup or a master-detail field.

When no parent has that external Id, the update fails with `Foreign key external ID: ... not found for field ...`, and the child has already been inserted:

- With `optAllOrNone` true, `apply()` throws a `DmlException`. Left uncaught, it rolls the transaction back, child included. If you catch it, the child stays, without its parent, unless you roll back to a savepoint.
- With `optAllOrNone` false, the child stays without its parent and is listed in `failures()` with that message.

---

## Deleting

```apex
App.s.work()
  .purge(accounts) // any order
  .purge(contacts)
  .purge(cases)
  .apply();
// deletes cases, then contacts, then accounts
```

The work reads the lookup fields that are populated on the records it was given. Where a record points at another record that is also being deleted, the pointing record's object is deleted first. There is one delete statement per object type.

- Only loaded fields count. `[SELECT Id FROM Contact ...]` carries no `AccountId`, so the work sees no link between those contacts and their accounts, and may delete the accounts first; the contacts' own delete then fails, because they went with their accounts. Select the lookup fields you want the ordering to respect.
- Only records in the same work count. Children you did not purge are left to the platform (cascade delete, or an error for a restricted lookup).
- A record without an Id cannot be purged; `purge` throws.

### Setting the order yourself

When object types point at each other in a circle, there is no safe automatic order. Give one:

```apex
App.s.work()
  .setOrder(new List<SObjectType>{ Case.SObjectType, Contact.SObjectType, Account.SObjectType })
  .purge(accounts)
  .purge(contacts)
  .purge(cases)
  .apply();
```

`setOrder` replaces the automatic ordering entirely. The list must name exactly the object types being purged, each once; otherwise `apply()` throws. It affects deletes only.

---

## Upserting

Pass a list and the external Id field to match on:

```apex
List<Account> incoming = new List<Account>{
  new Account(External_Id__c = 'ACME-001', Name = 'Acme'),
  new Account(External_Id__c = 'GLOBEX-7', Name = 'Globex')
};

App.s.work().track(incoming, Account.External_Id__c).apply();
```

Records whose external Id matches an existing record update it; the rest are inserted. The list holds records of one object type, and the field must be marked as an external Id, or `track` throws. There is one upsert statement per object type and field.

- A record that was inserted has its `Id` afterwards.
- With `optAllOrNone` false, the records that match or insert cleanly are saved and the rest are listed in `failures()`, as for an insert.

---

## Emails and platform events

```apex
Messaging.SingleEmailMessage note = new Messaging.SingleEmailMessage();
note.setToAddresses(new List<String>{ 'owner@example.com' });
note.setSubject('Order shipped');
note.setPlainTextBody('Your order is on its way.');

App.s.work()
  .track(shippedOrder)
  .track(note)
  .track(new Order_Shipped__e(Order_Number__c = '00012'))
  .apply();
```

- **Emails** are sent after all DML has succeeded. They are not sent while a test is running.
- **Platform events** are recognized by their type (`__e`) and published with `EventBus.publish`, last of all. Whether an event is held until the transaction commits or published at once is the event's own *Publish Behavior* setting, not something the work controls.

Because both come after the DML, a DML failure means no email is sent and no event is handed to the event bus.

---

## Tracking a record more than once

It is safe to track the same record from several places; the work sorts it out.

| What is tracked again | Result |
| --- | --- |
| The same new record (same instance) | Kept once. |
| Another new record with the same field values | Both are inserted: new records are told apart by instance, not by value. |
| The same existing record (same instance) | Kept once. Changes you make to it before `apply()` are saved. |
| Another instance with the same Id and a different set of populated fields | Merged: the later instance's fields are copied onto the first one tracked. |
| Another instance with the same Id and the same set of populated fields | The later instance replaces the earlier. |

Either way there is one update per record:

```apex
inj.IWork work = App.s.work();
work.track(new Account(Id = accountId, Rating = 'Hot'));
work.track(new Account(Id = accountId, Industry = 'Energy'));
work.apply(); // one update, setting both fields
```

The same is not done for deletes or upserts: purge a record once.

---

## DML options and partial success

`options()` returns the work's `Database.DMLOptions`, used for its inserts and updates:

```apex
inj.IWork work = App.s.work();
work.options().duplicateRuleHeader.allowSave = true;
work.options().assignmentRuleHeader.useDefaultRule = true;
work.track(leads).apply();
```

`optAllOrNone` starts as true: any failed record throws a `DmlException` and, unless you catch it, the transaction rolls back. Deletes and upserts take only this one setting from the options.

Setting `optAllOrNone = false` lets the records that can be saved go through. Nothing is thrown for the ones that cannot; the work lists them afterwards:

```apex
inj.IWork work = App.s.work();
work.options().optAllOrNone = false;
work.track(accounts).apply();

for (inj.IWorkFailure failure : work.failures()) {
  failure.getRecord();   // the instance you tracked; its Id is null if it was new
  failure.getMessage();  // the platform's messages, joined by '; '
  failure.getErrors();   // the platform's Database.Error list: status code, fields
}

inj.IWorkFailure mine = work.failureOf(accounts[0]); // null when that record was saved
```

- `failures()` covers inserts, updates, upserts and deletes, in the order the work met them. It is empty before `apply()`, and whenever `optAllOrNone` is true (a failure throws instead).
- `failureOf(record)` answers for the instance you tracked, not for a record that looks like it. Ask before you change the record again.
- **A record is not saved without the new record it depends on.** When a new parent fails, the children tracked with `track(child, lookupField, parent)` are not inserted, and so on down. An existing record that was to be related to the failed parent is not updated at all, its other changes included. Each is in `failures()` with the message `Not saved: the Account it is related to was not saved` and an empty `getErrors()`.
- To save every record or none and still learn what is wrong with each, set a savepoint, apply with `optAllOrNone = false`, and roll back when `failures()` is not empty.

---

## Running as the user

A work saves in **system mode**: the running user's permissions are not checked. `withSharing(true)` runs its inserts, updates, upserts and deletes in **user mode** instead, the same switch as on a query:

```apex
App.s.work().withSharing(true).track(account).apply();
```

In user mode the platform checks the user's object permissions, field permissions and sharing, and refuses a statement that breaks them:

| What the user lacks | What `apply()` throws |
| --- | --- |
| Any access to the object | `SecurityException`: `Access to entity 'Account' denied` |
| Create, edit or delete on an object they can read | `TypeException`: `DML operation INSERT not allowed on Account` |
| Edit on a field the record sets | `DmlException`: `Operation failed due to fields being inaccessible on Sobject Account` |

An upsert is refused in the same ways. One case is the work's own doing: on its own, an all-or-none upsert on an external Id by a user with no access to the object ends the transaction with an error Apex cannot catch, so the work checks first and throws the `SecurityException` of the table's first row.

Nothing is trimmed for you: a record that sets a field the user may not write is refused whole. Leave such fields off the record (`inj.FieldUtil.crop` keeps a named set) or check them first. With `optAllOrNone = false` the refused record is left out and listed in `failures()`, like any other failed record. Emails and platform events are not affected by the mode.

---

## What apply() does, in order

1. Deletes, one statement per object type, children first.
2. Inserts, level by level, one statement per object type per level.
3. One update for records whose lookups could only be set after the inserts (external Id relationships, and existing records related to a new parent).
4. Updates, one statement per object type.
5. Upserts, one statement per object type and external Id field.
6. Emails.
7. Platform events.

The number of DML statements depends on how many object types and levels are involved, not on how many records.

In a trigger hook, build one work, track everything, and apply it once at the end:

```apex
public override void onAfterUpsert(Map<Id, SObject> oldMap) {
  inj.IWork work = App.s.work();
  for (Opportunity row : (List<Opportunity>) base().records()) {
    if (row.StageName == 'Closed Won') {
      work.track(new Task(WhatId = row.Id, Subject = 'Send the welcome pack'));
    }
  }
  work.apply();
}
```

---

## Errors and limits

- **DML failures** surface as the platform's `DmlException`, from whichever statement failed. Nothing is caught or rolled back by the work itself: the transaction rolls back if the exception is not caught, as with any DML. With `optAllOrNone = false` they are listed by `failures()` instead (see [DML options and partial success](#dml-options-and-partial-success)).
- **Misuse** (purging a record with no Id, an external Id field that is not one, a null lookup field, an incomplete `setOrder`, a circle of new records) throws the framework's `WorkException`. From a subscriber org catch it as `Exception`; the type is not global.
- **Governor limits** are the platform's: 150 DML statements and 10,000 DML rows per transaction, shared with everything else in the transaction. The work reduces statements; it does not split rows across transactions. For volumes beyond that, apply works inside a batch job (see the [async guide](async-guide.md)).
- **Circular lookups between object types** on delete are not detected as an error. The automatic order is then arbitrary for the types in the circle; use `setOrder`.

See also: [extension guide](extension-guide.md) for domain classes, [testing guide](testing-guide.md#testing-work) for testing code that uses a work.
