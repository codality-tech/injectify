# Query Guide

Queries are built from the same pieces as the rest of the framework: a **model** for each object, **paths** for fields (including fields reached through lookups), and **conditions** that can render as SOQL or test records in memory. This guide covers SOQL queries (`IQuery`), aggregate queries (`IAggregateQuery`) and searches (`ISearchQuery`).

The examples are written as subscriber code: framework types carry the `unif.` namespace, and `App.s` is your org's entry point (see the [README](../../README.md#sixty-second-tour)). Every SOQL string shown was produced by the code above it.

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
unif.IQuery accounts = App.s.qf().make(Account.SObjectType);

// From the model: a plain query that selects only Id until you add fields.
unif.IQuery bare = App.s.model(Account.SObjectType).query();
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
App.s.qf().defaultFieldScope(unif.FieldScope.make(unif.FieldScope.Trait.CUSTOM));
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
unif.IQuery q = App.s.qf().make(Account.SObjectType, new List<Object>{
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
unif.IQuery q = App.s.model(Account.SObjectType).query();
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
unif.IQuery c = App.s.model(Contact.SObjectType).query();
c.fields().add(new Set<SObjectField>{ Contact.LastName });
c.fields().add('Account', new Set<SObjectField>{ Account.Name });
c.fields().add(new List<SObjectField>{ Contact.AccountId, Account.OwnerId }, new Set<SObjectField>{ User.Email });
c.fields().add(new Set<String>{ 'Account.Industry', 'Owner.Name' });
// SELECT Id, LastName, Account.Name, Account.Industry, Account.Owner.Email, Owner.Name FROM Contact
```

The fields must belong to the object the route leads to; a field of another object throws. `addAll(route)` selects every field there.

### Polymorphic lookups (TYPEOF)

A lookup that can point at several objects, such as `Task.WhatId`, takes fields of any of its targets. Each target you name fields for gets a `WHEN` branch, and its Id is added:

```apex
unif.IQuery t = App.s.model(Task.SObjectType).query();
t.fields().add(new Set<SObjectField>{ Task.Subject });
t.fields().add(Task.WhatId, new Set<SObjectField>{ Account.Name, Opportunity.Amount });
// SELECT Id, Subject, TYPEOF What WHEN Account THEN Id, Name WHEN Opportunity THEN Id, Amount END FROM Task
```

Use field tokens here, not names: a name such as `'Name'` could belong to any of the targets.

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
unif.IQuery scoped = App.s.model(Account.SObjectType).query();
scoped.fields().add(unif.FieldScope.make('Billing.*'));
// SELECT Id, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
//   BillingLatitude, BillingLongitude, BillingGeocodeAccuracy, BillingAddress FROM Account
```

`add(route, scope)` applies a scope to the object a route leads to.

### Fields the other clauses use

`q.addImplicitFields()` selects the fields that the query's conditions and orderings mention, plus the lookups that fields were added through:

```apex
unif.IQuery q = App.s.model(Contact.SObjectType).query();
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
| `iin` / `nin` | `IN` / `NOT IN` | a `Set` or `List`. There is no semi-join (`IN (SELECT ...)`): run the inner query first and pass its Ids |
| `inc` / `exc` | `INCLUDES` / `EXCLUDES` | multi-select picklist values |

Combine conditions with `all` (AND), `any` (OR) and `neg` (NOT):

```apex
unif.ICondition grouped = App.s.all(new List<unif.ICondition>{
  App.s.iin(Account.Industry, new Set<String>{ 'Energy', 'Banking' }),
  App.s.any(new List<unif.ICondition>{
    App.s.gt(Account.AnnualRevenue, 1000000),
    App.s.lk(Account.Name, 'Acme%')
  }),
  App.s.neg(App.s.eq(Account.Type, 'Prospect'))
});
unif.IQuery q = App.s.model(Account.SObjectType).query();
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
- a field name, which is resolved once the condition joins a query;
- an aggregate function, in a HAVING clause ([section 7](#7-aggregate-queries)).

```apex
unif.IQuery contacts = App.s.model(Contact.SObjectType).query();
contacts.filters().add(App.s.eq(new List<SObjectField>{ Contact.AccountId, Account.Industry }, 'Energy'));
// SELECT Id FROM Contact WHERE (Account.Industry = 'Energy')
```

A value that doesn't fit the field's type throws when the condition is built, with a message such as `Name holds string values, so it cannot be compared with date`.

### Parsing conditions from text

`model.parseCondition(text)` reads a SOQL-style WHERE expression. It suits conditions stored in configuration or entered by an admin. The result is the same condition object the builders make:

```apex
unif.ICondition parsed = App.s.model(Account.SObjectType).parseCondition(
  'Industry IN (\'Energy\', \'Banking\') AND (AnnualRevenue > 1000000 OR Name LIKE \'Acme%\') AND NOT (Type = \'Prospect\')'
);
```

This renders exactly like `grouped` above. The parser accepts:

| | |
|---|---|
| Operators | `=`, `!=`, `<`, `<=`, `>`, `>=`, `LIKE`, `IN`, `NOT IN`, `INCLUDES`, `EXCLUDES` (`<>` is not supported; use `!=`) |
| Logic | `AND`, `OR`, `NOT`, parentheses |
| Fields | API names, dotted through lookups (`Owner.Name`) |
| Values | `'text'` (a quote inside is written `''`), numbers, dates (`2026-01-31`), datetimes (`2026-01-31T09:30:00Z`), `TRUE`, `FALSE`, `NULL`, and parenthesized lists for `IN` |

A malformed expression throws an exception that gives the position, such as `Expected literal at position 7, got EOF`.

### Testing records in memory

Every condition can test records without a query, and gives the answer SOQL would:

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

An unloaded parent reads as null. To filter a list of records, use a domain's `filter(condition)` (see the [extension guide](extension-guide.md)).

### Reusing a condition through a relationship

`prepend(reference)` returns a copy of a condition that starts one relationship further out, and leaves the original unchanged:

```apex
unif.ICondition energy = App.s.eq(Account.Industry, 'Energy');
unif.ICondition contactsOfEnergy = energy.prepend(App.s.reference(Contact.AccountId));

unif.IQuery q = App.s.model(Contact.SObjectType).query();
q.filters().add(contactsOfEnergy);
// SELECT Id FROM Contact WHERE (Account.Industry = 'Energy')
```

### The WHERE clause

`q.filters()` is the query's root condition, an AND that starts empty. Use `filters().add(...)` or `q.addCondition(...)`; to start over, use `filters().clear()`.

---

## 4. Ordering, limit and offset

```apex
q.orderings().add(App.s.ordering(Account.Name, false, true)); // route, ascending?, nulls last?
q.setLimit(10).setOffset(5);
// ... ORDER BY Name DESC NULLS LAST LIMIT 10 OFFSET 5
```

`ordering` takes any route a condition does, so `App.s.ordering(new List<SObjectField>{ Contact.AccountId, Account.Name }, true, false)` orders by the parent's name. A limit or offset of 0 or null means none.

The same `IOrdering` can sort records in memory with `ordering.apply(records)`. The sort is stable, and nulls go first or last as asked, as in SOQL.

---

## 5. Child subqueries

Build the child query as usual and attach it by relationship name or by the child's lookup field:

```apex
unif.IQuery kids = App.s.model(Contact.SObjectType).query();
kids.fields().add(new Set<SObjectField>{ Contact.LastName });
kids.filters().add(App.s.ne(Contact.Email, null));

unif.IQuery parents = App.s.model(Account.SObjectType).query();
parents.fields().add(new Set<SObjectField>{ Account.Name });
parents.addSubquery('Contacts', kids);          // or addSubquery(Contact.AccountId, kids)
// SELECT Id, Name, (SELECT Id, LastName FROM Contacts WHERE (Email != :a0)) FROM Account
```

The child's conditions are bound along with the parent's. `getSubqueryMap()` returns the subqueries by relationship name.

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

Queries run in **system mode** by default, as Apex does.

- `withSharing(true)` runs the query in **user mode**: sharing rules, object permissions and field-level security all apply. Despite its name it is the whole of user mode, not sharing alone. A user with no access to the object gets a `QueryException`.
  - A field you add yourself that the user can't read makes the query fail with a `QueryException`.
  - A **default field** the user can't read is left out instead, so a query from the factory runs for any user who can read the object. That covers the fields the factory added (the trimmed default set, or your class's `getDefaultFields()`), in the query and in its subqueries. A field that is both a default and added by name counts as a default.
  - `toSoql()` shows the query as it would run for the current user.
- In system mode, **sharing follows the class that builds the query**, as it does for a query written in that class: built in a class declared `without sharing` it reads every record, and built in one declared `with sharing` it reads the records the running user can see.
  - The application's scheme is the class that runs every query. A scheme with a sharing keyword of its own overrides the builder's: through a scheme declared `without sharing`, a query reads every record even when a `with sharing` class built it. The scheme the package uses when you give none inherits, so it never overrides.
  - User mode applies sharing whatever the scheme and whoever built the query.
- `withSecurity(true)` adds `WITH SECURITY_ENFORCED`, which the framework places where SOQL requires it:

```apex
// SELECT Id FROM Account WITH SECURITY_ENFORCED ORDER BY Name DESC NULLS LAST LIMIT 10 OFFSET 5
```

### Locking rows

`forUpdate(true)` adds `FOR UPDATE`: the rows the query returns stay locked until the transaction ends, so nothing else can change them between your read and your write.

```apex
unif.IQuery parents = App.s.model(Account.SObjectType).query().forUpdate(true);
parents.addCondition(App.s.condId(accountIds));
// SELECT Id FROM Account WHERE (Id IN :a0) FOR UPDATE
```

- It applies to `run()` and `fetch()`. `count()` and `toLocator()` leave it out, since a count returns no rows and a locator cannot lock.
- The platform refuses `FOR UPDATE` together with `ORDER BY`: the query throws a `QueryException`.

### Copies

`q.deepClone()` copies the fields, subqueries and conditions, so conditions added to the copy don't touch the original.

### Testing

Every query runs through the application's scheme (`IScheme`). In tests, build the application with a `unif.MockScheme` to return rows you choose, without inserting data, and to see the SOQL and bind values each query ran. See the [testing guide](testing-guide.md#mocking-queries-with-mockscheme).

---

## 7. Aggregate queries

Start from the model:

```apex
unif.IAggregateQuery agg = App.s.model(Opportunity.SObjectType).aggregateQuery();
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
unif.Enums.Aggregate chosen = unif.Enums.Aggregate.valueOf('SUM');
agg.aggregates().add(App.s.aggregate(chosen, Opportunity.Amount)); // the same as App.s.sum(Opportunity.Amount)
```

The values are `COUNT`, `COUNT_DISTINCT`, `SUM`, `AVG`, `MIN` and `MAX`.

`rollup()` and `cube()` add subtotal rows, for at most three grouped fields. Each grouped field also gets a `GROUPING()` column named `Field_grp`.

WHERE and HAVING values are bound when the query runs, as in `IQuery`. `withSharing` and `withSecurity` work the same way too.

---

## 8. Searches (SOSL)

A search runs one search term across several objects. Each object's query supplies its fields and filters:

```apex
unif.IQuery accounts = App.s.model(Account.SObjectType).query();
accounts.fields().add(new Set<SObjectField>{ Account.Name });
accounts.filters().add(App.s.eq(Account.Industry, 'Energy'));

unif.IQuery contacts = App.s.model(Contact.SObjectType).query();
contacts.fields().add(new Set<SObjectField>{ Contact.Email });

unif.ISearchQuery s = App.s.searchQuery(new List<unif.IQuery>{ accounts, contacts });
s.searchScope().add(unif.Enums.SearchScope.NAME);
s.setLimit(20);
// FIND {Acme} IN NAME FIELDS RETURNING Account(Id, Name WHERE (Industry = 'Energy')), Contact(Id, Email) LIMIT 20

List<List<SObject>> found = s.run('Acme');                    // one list per object, in order
Map<SObjectType, List<SObject>> byType = s.runAsMap('Acme');  // only the objects with hits
```

- **Scope:** `searchScope()` is a live set (`ALL`, `NAME`, `EMAIL`, `PHONE`); left empty, SOSL's default applies.
- **WITH clause:** `setWith(text)` adds one (`DIVISION='Global'`, `SNIPPET`, and so on). That text is used as written, so never build it from user input.
- **The search term:** backslashes, braces and quotes in it are escaped, so a term can't close `FIND {...}` early. SOSL wildcards (`*`, `?`) and operators still work.
- **Filter values:** SOSL has no bind variables, so values in the objects' filters are written inline, escaped.
- **Security:** a search runs in system mode, and in user mode as soon as one of its queries was set to `withSharing(true)`. Default fields the user can't read are left out, as in a query.
- **Testing:** a search runs through the scheme of its first query. With `unif.MockScheme` it returns the rows registered for each object and records the SOSL (see the [testing guide](testing-guide.md#mocking-queries-with-mockscheme)); against the database, use `Test.setFixedSearchResults`.
- **Your own scheme:** implement `unif.ISearchScheme` beside `unif.IScheme` to receive searches. A scheme that does not is skipped, and the search goes straight to the platform.

---

## 9. Custom query classes

To give an object its own default fields or helper methods, extend `unif.BaseQuery` and register the class in your `App`:

```apex
global class AccountQuery extends unif.BaseQuery {
  global override Set<SObjectField> getDefaultFields() {
    return new Set<SObjectField>{ Account.Id, Account.Name, Account.Type };
  }
}

// In App: the query registry maps the object to the class
unif.Application.make(null, services, new Map<Type, Type>{ Account.class => AccountQuery.class }, domains);
```

`App.s.qf().make(Account.SObjectType)` then returns an `AccountQuery` with those defaults. The [extension guide](extension-guide.md) covers the initialization hook (`onInitialized`) and calling base methods across the namespace.
