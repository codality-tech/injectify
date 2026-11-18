@IsTest
private class ModelingTest {
  private static Core core = new Core();

  private static Modeling.Model modelOf(SObjectType token) {
    return (Modeling.Model) core.model(token);
  }

  @IsTest
  static void modelsAreSharedAndDescribeTheirObject() {
    Modeling.Model accounts = modelOf(Account.SObjectType);

    Assert.isTrue(accounts === core.model('account'), 'one model per type, found by name too');
    Assert.areEqual(Account.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap().keySet(), accounts.fieldMap().keySet());
    Assert.areEqual('Account', accounts.describe().getLabel());
    Assert.areEqual(Account.Name, accounts.nameField());
    Assert.areEqual(accounts.getChildRelationship(Account.ParentId), accounts.getChildRelationship('ChildAccounts'));
    Assert.isNull(core.model('No_Such_Object__c'));
    Assert.isNull(core.model((SObjectType) null));
    Assert.areEqual('Account', accounts.toString());
    Assert.areEqual('Account'.hashCode(), accounts.hashCode());
  }

  @IsTest
  static void aModelIsAReferenceToItself() {
    Modeling.Model accounts = modelOf(Account.SObjectType);
    Account row = new Account(Name = 'Acme');

    Assert.isTrue(accounts.source() === accounts && accounts.target() === accounts);
    Assert.areEqual(0, accounts.size());
    Assert.isTrue(accounts.fieldSequence().isEmpty());
    Assert.isTrue(accounts.getRecordValue(row) === row);
    Assert.isNull(accounts.toPath());
    Assert.areEqual('Name', accounts.toSoql(Account.Name));
    Assert.isTrue(accounts.getReference('') === accounts, 'a blank route is the model itself');
    Assert.isTrue(accounts.getReference(accounts) === accounts);
  }

  @IsTest
  static void unknownRecordTypesThrow() {
    Modeling.Model accounts = modelOf(Account.SObjectType);
    List<RecordType> anyType = [SELECT Id, DeveloperName, SobjectType FROM RecordType LIMIT 1];
    if (!anyType.isEmpty()) {
      Modeling.Model owner = (Modeling.Model) core.model(anyType[0].SobjectType);
      Assert.areEqual(anyType[0].Id, owner.recordTypeId(anyType[0].DeveloperName));
      Assert.areEqual(anyType[0].DeveloperName, owner.recordTypeName(anyType[0].Id));
    }

    for (Integer attempt = 0; attempt < 2; attempt++) {
      try {
        if (attempt == 0) {
          accounts.recordTypeId('No_Such_Type');
        } else {
          accounts.recordTypeName(IdUtil.generateId(RecordType.getSObjectType()));
        }
        Assert.fail('attempt ' + attempt);
      } catch (Modeling.ModelException expected) {
        Assert.isTrue(expected.getMessage().contains('has no record type'), expected.getMessage());
      }
    }
  }

  @IsTest
  static void pathsResolveFromEveryKindOfRoute() {
    Modeling.Model opportunities = modelOf(Opportunity.SObjectType);
    List<SObjectField> walk = new List<SObjectField>{
      Opportunity.AccountId,
      Account.ParentId,
      Account.ParentId,
      Account.Name
    };
    List<Object> routes = new List<Object>{
      'Account.Parent.Parent.Name',
      'account.parent.parent.name',
      'AccountId.ParentId.ParentId.Name',
      walk,
      core.path(walk)
    };

    for (Object route : routes) {
      IPath found = opportunities.path(route);
      Assert.areEqual('Account.Parent.Parent.Name', found.name(), String.valueOf(route));
      Assert.areEqual(walk, found.fieldSequence());
      Assert.areEqual(4, found.size());
      Assert.areEqual(Opportunity.SObjectType, found.source().token());
    }
    IPath deep = opportunities.path(walk);
    Assert.areEqual('Opportunity:Account.Parent.Parent.Name', deep.toString());
    Assert.isTrue(deep.label().contains('.'), deep.label());
    Assert.areEqual(Account.Name, deep.terminus());
    Assert.areEqual(1, core.path(Account.Name).size());
  }

  @IsTest
  static void routesThatLeadNowhere() {
    Modeling.Model opportunities = modelOf(Opportunity.SObjectType);

    Assert.isNull(opportunities.path('Account.Wobbegong'), 'unknown fields give null');
    Assert.isNull(opportunities.path(42, false, false), 'unsupported kinds give null when allowed');
    Map<String, Object> strictRoutes = new Map<String, Object>{ 'unsupported route type' => 42, 'leads nowhere' => 'Account.Wobbegong' };
    for (String expectedText : strictRoutes.keySet()) {
      try {
        opportunities.path(strictRoutes.get(expectedText), true, true);
        Assert.fail(expectedText);
      } catch (Modeling.PathException expected) {
        Assert.isTrue(expected.getMessage().contains(expectedText), expected.getMessage());
      }
    }
  }

  @IsTest
  static void singleTargetLookupsAreReferences() {
    IReference toAccount = core.model('Opportunity').getReference('AccountId');
    IReference toParent = core.model('Account').getReference('ParentId');
    IReference toGrandparent = toAccount.getReference(toParent);

    Assert.areEqual(core.path(Opportunity.AccountId), toAccount);
    Assert.areEqual(core.path(new List<SObjectField>{ Opportunity.AccountId, Account.ParentId }), toGrandparent);
    Assert.areEqual('Account.ParentId', ((IPath) toGrandparent).toReference().toPath().name(), 'a lookup path is named by its field');
    Assert.areEqual('Account.Parent', ((ILookupPath) toGrandparent).relationshipName());
    Assert.areEqual(Account.SObjectType, toGrandparent.target().token());
    Assert.areEqual('Account.Parent.Name', toGrandparent.toSoql(Account.Name));
    Assert.areEqual(
      2,
      new Set<IReference>{ toAccount, core.path(Opportunity.AccountId).toReference(), toGrandparent }.size(),
      'equal references collapse in a set'
    );
  }

  @IsTest
  static void plainFieldsAndPolymorphicLookupsAreNotReferences() {
    IPath plain = core.path(Account.Name);
    IPath polymorphic = core.path(Task.WhatId);

    Assert.isTrue(polymorphic instanceof Modeling.PolyPath);
    Assert.isTrue(((ILookupPath) polymorphic).targets().size() > 1);
    Assert.areEqual('What', ((ILookupPath) polymorphic).relationshipName());
    for (IPath notReference : new List<IPath>{ plain, polymorphic }) {
      try {
        notReference.toReference();
        Assert.fail(notReference.name());
      } catch (Modeling.ReferenceException expected) {
        Assert.isTrue(expected.getMessage().startsWith(notReference.name()), expected.getMessage());
      }
    }
    try {
      ((Modeling.Path) plain).relationshipName();
      Assert.fail('Name is not a lookup');
    } catch (Modeling.PathException expected) {
      Assert.isTrue(expected.getMessage().contains('not a lookup'), expected.getMessage());
    }
  }

  @IsTest
  static void pathsReadThroughLoadedParents() {
    IPath accountName = core.model('Contact').path('Account.Name');
    Account parent = new Account(Name = 'Acme');
    Contact linked = new Contact(LastName = 'Lovelace', Account = parent);
    Contact orphan = new Contact(LastName = 'Solo');

    Assert.areEqual('Acme', accountName.getFieldValue(linked));
    Assert.isNull(accountName.getFieldValue(orphan));
    Assert.isNull(accountName.getFieldValue(null));
    Assert.isTrue(((ILookupPath) core.path(Contact.AccountId)).getRecordValue(linked) === parent);
  }

  @IsTest
  static void orderingsRenderOnceRealized() {
    IOrdering byCreated = core.ordering('CreatedDate', true, true);
    IOrdering byName = core.ordering(Account.Name);

    try {
      byCreated.toSoql();
      Assert.fail('a named ordering needs an object first');
    } catch (Modeling.OrderingRealizeException expected) {
      Assert.isNotNull(expected.getMessage());
    }
    byCreated.realize(Account.SObjectType);
    Assert.areEqual('CreatedDate ASC NULLS LAST', byCreated.toSoql());
    Assert.areEqual('Name ASC NULLS FIRST', byName.toSoql(), 'ascending, nulls first by default');
    Assert.areEqual('Name DESC NULLS FIRST', core.ordering(core.path(Account.Name), false, false).toSoql());
    Assert.areEqual(Account.SObjectType, byName.source().token());
    try {
      byCreated.realize(Contact.SObjectType);
      Assert.fail('already realized for Account');
    } catch (Modeling.OrderingRealizeException expected) {
      Assert.isTrue(expected.getMessage().contains('Upstream SObjectType'), expected.getMessage());
    }
  }

  @IsTest
  static void modelsMakeDomainsQueriesAndRecords() {
    Modeling.Model accounts = modelOf(Account.SObjectType);
    List<Account> rows = new List<Account>{ new Account(Name = 'Acme'), new Account(Name = 'Globex') };

    IDomain domain = accounts.domain(rows);
    IQuery plain = accounts.query();
    IQuery filtered = accounts.query(new List<ICondition>{ core.eq('Name', 'Acme') });
    Account spawned = (Account) accounts.spawnRecord(new Map<String, Object>{ 'Name' => 'Spawned' });

    Assert.areEqual(2, domain.records().size());
    Assert.areEqual('SELECT Id FROM Account', plain.toSoql());
    Assert.areEqual('SELECT Id FROM Account WHERE (Name = \'Acme\')', filtered.toSoql());
    Assert.isNotNull(accounts.aggregateQuery());
    Assert.areEqual('Spawned', spawned.Name);
    Assert.isTrue(accounts.spawnRecordList() instanceof List<Account>);
  }

  @IsTest
  static void conditionsParseAndCompileAgainstTheModel() {
    Modeling.Model accounts = modelOf(Account.SObjectType);

    ICondition parsed = accounts.parseCondition('Name = \'Acme\'');
    IConditionCompilation compiled = accounts.compileCondition(parsed);

    Assert.isTrue(parsed.evaluate(new Account(Name = 'Acme')));
    Assert.areEqual(1, compiled.getFieldConditions().size());
    Assert.isTrue(compiled.getPaths().contains(core.path(Account.Name)));
  }

  @IsTest
  static void setCoreForgetsBuiltModels() {
    Modeling fresh = new Modeling(null, core);
    Modeling.Model before = fresh.model(Account.SObjectType);

    fresh.setCore(core);
    Modeling.Model after = fresh.model(Account.SObjectType);

    Assert.isTrue(fresh.scheme() instanceof SchemeDefault, 'a null scheme falls back to the default');
    Assert.isFalse(before === after, 'rebuilt');
    Assert.areEqual(before, after, 'but equal, being for the same type');
    Assert.isTrue(fresh.core() === core);
  }

  @IsTest
  static void exceptionsCarryTheirMessage() {
    List<Exception> raised = new List<Exception>{
      new Modeling.ModelException('model'),
      new Modeling.FieldException('field'),
      new Modeling.ReferenceException('reference'),
      new Modeling.PathException('path')
    };

    for (Exception each : raised) {
      Assert.isFalse(String.isBlank(each.getMessage()));
    }
    String mismatch = new Modeling.OrderingRealizeException(Account.SObjectType, Contact.SObjectType).getMessage();
    Assert.isTrue(mismatch.contains('does not match current SObjectType'), mismatch);
  }

  @IsTest
  static void recordTypesResolveBothWays() {
    Modeling.Model accounts = modelOf(Account.SObjectType);
    // Every object has at least its master record type, so this needs none set up in the org.
    Schema.RecordTypeInfo known = Account.SObjectType.getDescribe().getRecordTypeInfos()[0];

    Assert.areEqual(known.getRecordTypeId(), accounts.recordTypeId(known.getDeveloperName()));
    Assert.areEqual(known.getDeveloperName(), accounts.recordTypeName(known.getRecordTypeId()));
    Assert.areEqual(known.getRecordTypeId(), accounts.recordTypeIdByName().get(known.getDeveloperName()));

    // The RecordTypeId field only exists once an object has record types of its own.
    if (accounts.fieldMap().containsKey('RecordTypeId')) {
      ICondition ofThatType = accounts.condRtdn(new Set<String>{ known.getDeveloperName() });
      Assert.isTrue(ofThatType.toSoql().contains(String.valueOf(known.getRecordTypeId())), ofThatType.toSoql());
    }
  }

  @IsTest
  static void orderingsDefaultToAscendingWithNullsFirst() {
    Modeling modeling = modelOf(Account.SObjectType).modeler();

    IOrdering byName = modeling.ordering(Account.Name);
    Assert.isTrue(byName.isAscending());
    Assert.isFalse(byName.nullsLast());
    Assert.areEqual('Name ASC NULLS FIRST', byName.toSoql());

    IOrdering named = modeling.ordering('Name', false);
    Assert.isFalse(named.isAscending());
    try {
      named.toSoql();
      Assert.fail('a route given by name has no path until it is realized');
    } catch (Modeling.OrderingRealizeException expected) {
      Assert.isTrue(expected.getMessage().contains('must be realized'), expected.getMessage());
    }
    try {
      named.realize(null);
      Assert.fail('a null object');
    } catch (Modeling.OrderingRealizeException expected) {
      Assert.isTrue(expected.getMessage().contains('must not be null'), expected.getMessage());
    }
    named.realize(Account.SObjectType);
    Assert.areEqual('Name DESC NULLS FIRST', named.toSoql());
    Assert.areEqual(Account.Name, named.path().terminus());
    Assert.areEqual(Account.SObjectType, named.source().token());
  }

  @IsTest
  static void aSingleTargetLookupResolvesPathsStrictlyOrNot() {
    Modeling.MonoPath parent = (Modeling.MonoPath) modelOf(Account.SObjectType).path(Account.ParentId);

    Assert.areEqual('Parent.Name', parent.path(Account.Name, true, true).name());
    Assert.isNull(parent.path('No_Such_Field__c', true, false));
    try {
      parent.path('No_Such_Field__c', true, true);
      Assert.fail('a route that leads nowhere, asked for strictly');
    } catch (Modeling.PathException expected) {
      Assert.isTrue(expected.getMessage().contains('leads nowhere'), expected.getMessage());
    }
  }
}
