// Auto-generated summary of global classes and their global methods.
// Do not edit manually; regenerate by running scripts/py/package_api.py

interface IAggregateFunction {
  String functionName();
  Object field();
  String toSoql();
  Boolean equals(Object other);
  Integer hashCode();
  String getAlias();
  IAggregateFunction setAlias(String alias);
  String toString();
}

interface IAggregateQuery {
  IAggregateQuery deepClone();
  IModel source();
  Set<IAggregateFunction> aggregates();
  List<IPath> groupBys();
  IAggregateQuery rollup();
  IAggregateQuery cube();
  ILogicalCondition havingFilters();
  ILogicalCondition filters();
  List<IOrdering> orderings();
  IAggregateQuery setLimit(Integer limitCount);
  IAggregateQuery setOffset(Integer offsetCount);
  IAggregateQuery withSecurity(Boolean enforceSecurity);
  IAggregateQuery withSharing(Boolean enforceSharing);
  IAggregateQuery allRows(Boolean include);
  IAggregateQuery usingScope(Enums.FilterScope scope);
  String toSoql();
  String toSoql(Boolean binding);
  List<AggregateResult> run();
}

interface IBaseFactory {
  void register(Map<Type, Type> registryPatch);
  Type getRegisteredClass(Type key);
}

interface IDomainFactory extends IBaseFactory {
  IDomain make(SObjectType token);
  IDomain make(SObjectType token, List<SObject> records);
  IDomain make(String name);
  IDomain make(List<SObject> records);
}

interface IQueryFactory extends IBaseFactory {
  IQuery make(SObjectType token);
  IQuery make(String name);
  IQuery make(String name, List<Object> additiveArgs);
  IQuery make(SObjectType token, List<Object> additiveArgs);
  IQueryFactory defaultFieldScope(IFieldScope scope);
}

interface IServiceFactory extends IBaseFactory {
  Object make(Type key);
  Object get(Type key);
}

interface ITriggeredFactory extends IBaseFactory {
  ITriggered make(SObjectType token);
  ITriggered make(String name);
  void execute();
  void disable(Map<SObjectType, Set<TriggerOperation>> bypasses);
  void enable(Map<SObjectType, Set<TriggerOperation>> bypasses);
  void disable();
  void enable();
  void disable(Iterable<SObjectType> tokens);
  void enable(Iterable<SObjectType> tokens);
  void disableWhen(ITriggeredBypass rule);
}

interface ICondition {
  ICondition clone(Boolean deep);
  String compile(IConditionCompilation compilation);
  Boolean evaluate(SObject candidate);
  ICondition prepend(IReference via);
  void realize(SObjectType target);
  IModel source();
  String toSoql();
}

interface IFieldCondition extends ICondition {
  Boolean isAggregateCondition();
  Enums.Comparator operator();
  IPath path();
  String toSoql(String valueText);
  String toSoql();
  Object value();
}

interface ILogicalCondition extends ICondition {
  ILogicalCondition add(ICondition member);
  ILogicalCondition addAll(List<ICondition> members);
  ILogicalCondition clear();
  List<ICondition> getAll();
}

interface IConditionCompilation {
  List<IFieldCondition> getFieldConditions();
  String getMarkup();
  Set<IPath> getPaths();
  IModel source();
  String toSoql();
}

interface ICore {
  IReference reference(SObjectType token);
  IReference reference(SObjectField field);
  IReference reference(List<SObjectField> fields);
  IModel model(SObjectType token);
  IModel model(String sobjectName);
  IModel model(SObject record);
  IModel model(List<SObject> records);
  IPath path(SObjectField field);
  IPath path(List<SObjectField> fields);
  ILogicalCondition all(List<ICondition> items);
  ILogicalCondition any(List<ICondition> items);
  IFieldCondition cond(Enums.Comparator op, Object lhs, Object rhs, Boolean negated);
  IFieldCondition cond(Enums.Comparator op, Object lhs, Object rhs);
  IFieldCondition eq(Object lhs, Object rhs);
  IFieldCondition ne(Object lhs, Object rhs);
  IFieldCondition ge(Object lhs, Object rhs);
  IFieldCondition le(Object lhs, Object rhs);
  IFieldCondition gt(Object lhs, Object rhs);
  IFieldCondition lt(Object lhs, Object rhs);
  IFieldCondition lk(Object lhs, Object rhs);
  IFieldCondition iin(Object lhs, Object rhs);
  IFieldCondition nin(Object lhs, Object rhs);
  IFieldCondition inc(Object lhs, Object rhs);
  IFieldCondition exc(Object lhs, Object rhs);
  ICondition neg(ICondition condition);
  IFieldCondition condId(Set<Id> recordIds);
  IFieldCondition condRtdn(Set<String> developerNames);
  IOrdering ordering(Object route, Boolean isAscending, Boolean nullsLast);
  IAggregateFunction count(Object field);
  IAggregateFunction countDistinct(Object field);
  IAggregateFunction sum(Object field);
  IAggregateFunction avg(Object field);
  IAggregateFunction min(Object field);
  IAggregateFunction max(Object field);
  IAggregateFunction aggregate(Enums.Aggregate function, Object field);
  IWork work();
  ISearchQuery searchQuery(List<IQuery> queries);
}

interface IApplication extends ICore {
  IServiceFactory sf();
  IQueryFactory qf();
  IDomainFactory df();
  ITriggeredFactory tf();
}

interface IDateLiteral {
  String toSoql();
}

interface IDomain {
  void init(IModel model, SObject[] rows);
  Map<Id, SObject> toMap();
  IModel source();
  Integer size();
  SObject[] records();
  void updateBlank(SObject template, IWork work);
  void updateDifferent(SObject template, IWork work);
  SObject[] sort(IOrdering ordering);
  SObject[] filter(ICondition condition);
  SObject[] getChangedRecords(Map<Id, SObject> previous, Set<SObjectField> fields);
  SObject[] getChangedRecords(Map<Id, SObject> previous, Set<String> fieldNames);
  Map<Id, SObject[]> catalogId(Object route);
  Map<Id, SObject[]> segmentId(Object route);
  Map<String, SObject[]> catalog(Object route);
  Map<String, SObject[]> segment(Object route);
  void forget(Object route);
  Map<Id, SObject> collectRecords(Object route);
  Object aggregate(IAggregateFunction function);
}

interface IFieldScope {
  Set<SObjectField> apply(IModel model);
  IFieldScope exclude(IFieldScope scope);
}

interface IHandler {
}

interface IBatchIterableHandler extends IHandler {
  Iterable<Object> batchStart();
  void batchExecute(Iterable<Object> scope);
  void batchFinish();
  Integer batchDefaultSize();
}

interface IBatchQueryableHandler extends IHandler {
  IQuery batchStart();
  void batchExecute(List<SObject> scope);
  void batchFinish();
  Integer batchDefaultSize();
}

interface IHandlerCapturing extends IHandler {
  Enums.CaptureMode getCaptureMode(IJob parentJob, IJob childJob);
}

interface IJobAware extends IHandler {
  void setJob(IJob job);
}

interface IQueueableHandler extends IHandler {
  void queueableExecute();
}

interface ISchedulableHandler extends IHandler {
  void schedulableExecute();
  String name();
  String cronExpression();
}

interface IJob {
  IJob then(IJob successor);
  IJob run();
  Id getJobId();
  IJob setShared(String key, Object value);
  Object getShared(String key);
}

interface IBatch extends IJob {
  IBatch setBatchSize(Integer batchSize);
  void finish();
  Integer getDefaultBatchSize();
}

interface IBatchIterable extends IBatch {
  Iterable<Object> start();
  void execute(Iterable<Object> scope);
}

interface IBatchQueryable extends IBatch {
  IQuery start();
  void execute(List<SObject> scope);
}

interface IQueueable extends IJob {
  IQueueable setMinuteDelay(Integer minuteDelay);
  void execute();
}

interface ISchedulable extends IJob {
  void execute();
  String name();
  String cronExpression();
  String toCronExpression(Datetime dt);
  void unschedule();
}

interface IOrdering {
  IModel source();
  IPath path();
  Boolean isAscending();
  Boolean nullsLast();
  String toSoql();
  void realize(SObjectType sobjectToken);
  void apply(List<SObject> records);
}

interface IPath {
  DescribeFieldResult describe();
  List<SObjectField> fieldSequence();
  Object getFieldValue(SObject row);
  Integer size();
  String label();
  String name();
  IReference reference();
  IModel source();
  SObjectField terminus();
  IReference toReference();
}

interface ILookupPath extends IPath {
  SObject getRecordValue(SObject row);
  IModel[] targets();
  String relationshipName();
}

interface IQuery {
  List<SObject> run();
  SObject fetch();
  List<SObject> fetch(Integer maxRows);
  Integer count();
  Database.QueryLocator toLocator();
  String toSoql(Boolean binding);
  String toSoql();
  IModel source();
  IQueryFields fields();
  IQuery addAllFields();
  IQuery addImplicitFields();
  IQuery addSubquery(String relationshipName, IQuery child);
  IQuery addSubquery(SObjectField relationshipField, IQuery child);
  Map<String, IQuery> getSubqueryMap();
  IQuery addCondition(ICondition condition);
  ILogicalCondition filters();
  List<IOrdering> orderings();
  IQuery setOffset(Integer skipRows);
  IQuery setLimit(Integer maxRows);
  IQuery withSharing(Boolean enforce);
  IQuery withSecurity(Boolean enforce);
  IQuery forUpdate(Boolean lock);
  IQuery allRows(Boolean include);
  IQuery usingScope(Enums.FilterScope scope);
  IQuery forView(Boolean mark);
  IQuery forReference(Boolean mark);
  IQuery deepClone();
}

interface IQueryFields {
  IQueryFields add(Object route, Set<SObjectField> fields);
  IQueryFields add(Set<SObjectField> fields);
  IQueryFields add(Object route, IQueryFields fields);
  IQueryFields add(IQueryFields fields);
  IQueryFields add(Object route, Map<IReference, Set<SObjectField>> fields);
  IQueryFields add(Map<IReference, Set<SObjectField>> fields);
  IQueryFields add(Object route, Set<String> fields);
  IQueryFields add(Set<String> fields);
  IQueryFields add(Set<IPath> paths);
  IQueryFields add(Object route, IFieldScope scope);
  IQueryFields add(IFieldScope scope);
  IQueryFields addAll(Object route);
  IQueryFields addAll();
  IQueryFields clearFields();
  IModel source();
  String toSoql();
  Set<IPath> getRoutes();
  Map<IReference, Set<SObjectField>> getFieldsByReference();
}

interface IReference {
  List<SObjectField> fieldSequence();
  SObject getRecordValue(SObject row);
  IReference getReference(Object via);
  IPath path(Object via);
  IPath path(Object via, Boolean strictType, Boolean strictNull);
  Integer size();
  IModel source();
  IModel target();
  IPath toPath();
  String toSoql(SObjectField field);
}

interface IModel extends IReference {
  SObjectType token();
  String name();
  DescribeSObjectResult describe();
  Map<String, SObjectField> fieldMap();
  Map<String, FieldSet> fieldSetMap();
  SObjectField nameField();
  IScheme scheme();
  ICore core();
  IPath path(Object via);
  IPath path(Object via, Boolean strictType, Boolean strictNull);
  ChildRelationship getChildRelationship(SObjectField lookupOnChild);
  ChildRelationship getChildRelationship(String relationshipName);
  String recordTypeName(Id recordTypeId);
  Id recordTypeId(String developerName);
  ICondition parseCondition(String expression);
  IConditionCompilation compileCondition(ICondition root);
  ICondition condRtdn(Set<String> developerNames);
  List<SObject> spawnRecordList();
  SObject spawnRecord(Map<String, Object> valuesByField);
  IDomain domain(List<SObject> rows);
  IAggregateQuery aggregateQuery();
  IQuery query(List<ICondition> conditions);
  IQuery query();
}

interface IScheme {
  SObjectType getSObjectType(String sobjectName);
  DescribeSObjectResult getDescribe(SObjectType arg);
  Map<String, SObjectField> getFieldMap(SObjectType sobjectToken);
  Map<String, Schema.Fieldset> getFieldsetMap(SObjectType sobjectToken);
  DescribeFieldResult getFieldDescribe(SObjectField field);
  List<SObject> queryWithBinds(String queryString, Map<String, Object> bindMap, System.AccessLevel accessLevel);
  Database.QueryLocator getQueryLocatorWithBinds(String queryString, Map<String, Object> bindMap, System.AccessLevel accessLevel);
  Integer countQueryWithBinds(String queryString, Map<String, Object> bindMap, System.AccessLevel accessLevel);
  Type getTypeForName(String className);
}

interface ISearchQuery {
  ISearchQuery deepClone();
  Set<Enums.SearchScope> searchScope();
  Map<SObjectType, IQuery> targetMap();
  ISearchQuery setWith(String val);
  ISearchQuery setLimit(Integer limitCount);
  String toSosl(String searchTerm);
  List<List<SObject>> run(String searchTerm);
  Map<SObjectType, List<SObject>> runAsMap(String searchTerm);
}

interface ISearchScheme {
  List<List<SObject>> search(String sosl, System.AccessLevel accessLevel);
}

interface ITriggered {
  void handleTrigger(TriggerOperation op, List<SObject> triggerNew, List<SObject> triggerOld, Map<Id, SObject> triggerOldMap, IModel model);
}

interface ITriggeredBypass {
  Boolean bypasses(SObjectType token, TriggerOperation operation);
}

interface ITriggeredConfigured {
  Boolean shouldRecycleInstance();
  Boolean shouldEnforceSecurity();
}

interface IWork {
  IWork track(SObject record);
  IWork track(List<SObject> records);
  IWork track(SObject record, SObjectField relatedToField, SObject relatedTo);
  IWork track(SObject record, SObjectField relatedToField, SObjectField externalIdField, String externalId);
  IWork track(List<SObject> records, SObjectField externalIdField);
  IWork purge(SObject record);
  IWork purge(List<SObject> records);
  IWork track(Messaging.Email email);
  IWork track(List<Messaging.Email> emails);
  Database.DmlOptions options();
  IWork setOrder(List<SObjectType> purgeOrder);
  IWork withSharing(Boolean enforce);
  void apply();
  Boolean hasWork();
  List<IWorkFailure> failures();
  IWorkFailure failureOf(SObject record);
}

interface IWorkFailure {
  SObject getRecord();
  String getMessage();
  List<Database.Error> getErrors();
}

class Application implements IApplication, ICore {
  static Application make(IScheme scheme, Map<Type, Type> serviceRegistry, Map<Type, Type> queryRegistry, Map<Type, Type> domainRegistry, Map<Type, Type> triggerRegistry);
  static Application make(IScheme scheme, Map<Type, Type> serviceRegistry, Map<Type, Type> queryRegistry, Map<Type, Type> domainTriggerRegistry);
  static Application make(IScheme scheme);
  static Application make();
  class FactoryException extends Exception {
  }
}

class Async {
  static Boolean synchronousInTests;
  static IQueueable queueable(IQueueableHandler handler);
  static IBatchQueryable queryable(IBatchQueryableHandler handler);
  static IBatchIterable iterable(IBatchIterableHandler handler);
  static ISchedulable schedulable(ISchedulableHandler handler);
}

class CharUtil {
  static final ICharset binary;
  static final ICharset numeric;
  static final ICharset lowerhex;
  static final ICharset upperhex;
  static final ICharset lowerdec;
  static final ICharset upperdec;
  static final ICharset alphadec;
  static final ICharset ascii;
  static ICharset charset(String chars);
  interface ICharset {
    Integer getBase();
    String get(Integer position);
    Decimal toDecimal(String digits);
    String fromDecimal(Decimal value, Integer width);
    String convert(String digits, Integer width, ICharset target);
    Integer getPlaces(Decimal value);
    String generateRandom(Integer length);
    String shiftEncrypt(String text, List<Integer> offsets);
    String shiftDecrypt(String text, List<Integer> offsets);
  }
}

class CsvUtil {
  static String toCsv(List<String> header, List<Map<String, Object>> data);
  static String toCsv(List<String> fieldPaths, List<SObject> records);
  static String toCsv(Map<String, String> labelByPath, List<SObject> records);
  static Table read(String text);
  static List<List<String>> rows(String text, String separator);
  static String separatorOf(String text);
  static Boolean isBlank(List<String> row);
  class GeneralException extends Exception {
  }
  class Table {
    String separator;
    List<String> header;
    List<List<String>> rows;
    Integer rowNumber(Integer index);
  }
}

inherited sharing class DateLiteral {
  static IDateLiteral yesterday();
  static IDateLiteral today();
  static IDateLiteral tomorrow();
  static IDateLiteral last90Days();
  static IDateLiteral next90Days();
  static IDateLiteral lastNDays(Integer n);
  static IDateLiteral nextNDays(Integer n);
  static IDateLiteral nDaysAgo(Integer n);
  static IDateLiteral lastWeek();
  static IDateLiteral thisWeek();
  static IDateLiteral nextWeek();
  static IDateLiteral lastNWeeks(Integer n);
  static IDateLiteral nextNWeeks(Integer n);
  static IDateLiteral nWeeksAgo(Integer n);
  static IDateLiteral lastMonth();
  static IDateLiteral thisMonth();
  static IDateLiteral nextMonth();
  static IDateLiteral lastNMonths(Integer n);
  static IDateLiteral nextNMonths(Integer n);
  static IDateLiteral nMonthsAgo(Integer n);
  static IDateLiteral lastQuarter();
  static IDateLiteral thisQuarter();
  static IDateLiteral nextQuarter();
  static IDateLiteral lastNQuarters(Integer n);
  static IDateLiteral nextNQuarters(Integer n);
  static IDateLiteral nQuartersAgo(Integer n);
  static IDateLiteral lastYear();
  static IDateLiteral thisYear();
  static IDateLiteral nextYear();
  static IDateLiteral lastNYears(Integer n);
  static IDateLiteral nextNYears(Integer n);
  static IDateLiteral nYearsAgo(Integer n);
  static IDateLiteral lastFiscalQuarter();
  static IDateLiteral thisFiscalQuarter();
  static IDateLiteral nextFiscalQuarter();
  static IDateLiteral lastNFiscalQuarters(Integer n);
  static IDateLiteral nextNFiscalQuarters(Integer n);
  static IDateLiteral nFiscalQuartersAgo(Integer n);
  static IDateLiteral lastFiscalYear();
  static IDateLiteral thisFiscalYear();
  static IDateLiteral nextFiscalYear();
  static IDateLiteral lastNFiscalYears(Integer n);
  static IDateLiteral nextNFiscalYears(Integer n);
  static IDateLiteral nFiscalYearsAgo(Integer n);
  static IDateLiteral of(String text);
}

class DebugUtil {
  static IPrinter printer();
  interface IPrinter {
    IPrinter writeSection(String title);
    IPrinter write(Object value);
    IPrinter writeSerialized(Object value);
    IPrinter writePretty(Object value);
    IPrinter writeLimits();
    IPrinter inc();
    IPrinter dec();
    void print();
  }
}

virtual class DomainRecords implements IDomain, ITriggered, ITriggeredConfigured {
  virtual void init(IModel source, List<SObject> records);
  IModel source();
  List<SObject> records();
  Integer size();
  Map<Id, SObject> toMap();
  List<SObject> getChangedRecords(Map<Id, SObject> previous, Set<String> fieldNames);
  List<SObject> getChangedRecords(Map<Id, SObject> previous, Set<SObjectField> fields);
  List<SObject> filter(ICondition condition);
  List<SObject> sort(IOrdering ordering);
  Map<String, List<SObject>> segment(Object path);
  Map<Id, List<SObject>> segmentId(Object path);
  Map<String, List<SObject>> catalog(Object path);
  Map<Id, List<SObject>> catalogId(Object path);
  void forget(Object path);
  Map<Id, SObject> collectRecords(Object path);
  Object aggregate(IAggregateFunction function);
  void updateDifferent(SObject template, IWork work);
  void updateBlank(SObject template, IWork work);
}

abstract class BaseDomain extends DomainRecords implements IDomain, ITriggered, ITriggeredConfigured {
  BaseDomain();
  BaseDomain(IModel source, List<SObject> records);
  void init(IModel source, List<SObject> records);
  virtual void onInitialized(IModel source, List<SObject> records);
  virtual void onBeforeUpsert(Map<Id, SObject> oldMap);
  virtual void onAfterUpsert(Map<Id, SObject> oldMap);
  virtual void onBeforeDelete();
  virtual void onAfterDelete();
  virtual void onAfterUndelete();
  IDomain base();
  virtual Boolean shouldRecycleInstance();
  virtual Boolean shouldEnforceSecurity();
}

class Enums {
  enum SearchScope {
    ALL, NAME, EMAIL, PHONE;
  }
  enum FilterScope {
    DELEGATED, EVERYTHING, MINE, MINE_AND_MY_GROUPS, MY_TERRITORY, MY_TEAM_TERRITORY, SCOPING_RULE, TEAM;
  }
  enum Comparator {
    EQ, NE, LT, GT, LE, GE, LK, NIN, IIN, EXC, INC;
  }
  enum Aggregate {
    COUNT, COUNT_DISTINCT, SUM, AVG, MIN, MAX;
  }
  enum CaptureMode {
    SYNCHRONOUS, RELEASE, IMMEDIATE, PREPEND, APPEND, IGNORE;
  }
}

class FieldScope {
  static IFieldScope any(List<IFieldScope> scopes);
  static IFieldScope all(List<IFieldScope> scopes);
  static IFieldScope make(Trait trait);
  static IFieldScope make(String patt);
  static IFieldScope make(Schema.SOAPType st);
  static IFieldScope make(DisplayType dt);
  enum Trait {
    ALL, CUSTOM, STANDARD, NAMESPACED, UNDERSIZE, OVERSIZE, FORMULA;
  }
}

class FieldUtil {
  static Set<String> getMultipickValues(SObject holder, SObjectField field);
  static Boolean pushMultipickValues(SObject holder, SObjectField field, Set<String> additions);
  static Boolean clearMultipickValues(SObject holder, SObjectField field, Set<String> removals);
  static Boolean clearInvalidMultipickValues(SObject holder, SObjectField field);
  static Set<String> getPicklistValues(SObjectField field);
  static Map<String, Set<String>> getDependentPicklistValues(SObjectField dependentField);
  static String decimalToBinary(Integer whole);
  static String base64ToBits(String encoded);
  static final List<String> addressChunks;
  static Set<String> getAddressFieldNames(String stem);
  static void copyAddress(SObject source, String sourceStem, SObject target, String targetStem);
  static Boolean addressIsBlank(SObject holder, String stem);
  static Boolean addressIsBlank(SObject holder, String stem, Boolean anyPart);
  static SObject chunk(SObject target, String stem, String text);
  static SObject chunk(SObject target, List<SObjectField> parts, String text);
  static String toCSV(List<SObject> rows, List<String> fields, Boolean withHeader);
  static String toCSV(List<SObject> rows, Boolean withHeader);
  static String toCSV(List<SObject> rows);
  static List<SObject> changed(List<SObject> current, Map<Id, SObject> previous, List<String> fieldNames);
  static List<SObject> changed(List<SObject> current, Map<Id, SObject> previous, List<SObjectField> tokens);
  static Map<String, List<SObject>> catalog(List<SObject> rows, String groupField);
  static List<SObjectField> getBlankFields(SObject holder, Set<SObjectField> candidates);
  static SObject crop(SObject source, Set<SObjectField> keep);
  static SObject crop(SObject source, Set<String> keep);
  static SObject join(SObject dominant, SObject fallback);
  static Map<String, Object> join(Map<String, Object> dominant, Map<String, Object> fallback);
  static Boolean takesText(Schema.DescribeFieldResult shape);
  static Object fromText(SObjectField field, String text);
  static Object fromText(Schema.DescribeFieldResult shape, String text);
  class GeneralException extends Exception {
  }
  class PicklistEntryWrapper {
    String validFor;
    String value;
    String label;
    String defaultValue;
    String active;
  }
}

class IdUtil {
  static Map<SObjectType, List<SObject>> toRecordsByToken(Set<Id> ids);
  static List<SObject> toRecords(Set<Id> ids, Boolean mixed);
  static Id generateId(IModel model);
  static Id generateId(SObjectType token);
  static List<Id> generateIds(IModel model, Integer count);
  static String getRecordUrl(Id target);
  static Boolean isValidId(String recordId, IModel model);
  static ITracker getTracker();
  interface ITracker {
    Set<Id> getNovelIds(Set<Id> candidates, Boolean remember);
    Set<Id> getNovelIds(List<Id> candidates, Boolean remember);
    Set<Id> getIds();
  }
}

class LimitsUtil {
  static String stringify();
  class AnyException extends Exception {
  }
  class Snapshot {
    Snapshot();
    Snapshot getDelta(Snapshot other);
    String stringify();
    String toString();
  }
  class LimitItem {
    LimitItem(String name, Decimal used, Decimal available);
    String stringify();
    LimitItem getDelta(LimitItem preceeding);
  }
}

inherited sharing class MockScheme implements IScheme, ISearchScheme {
  MockScheme();
  MockScheme returning(SObjectType objectType, List<SObject> rows);
  List<String> queries();
  List<Map<String, Object>> bindMaps();
  SObjectType getSObjectType(String sobjectName);
  DescribeSObjectResult getDescribe(SObjectType sobjectToken);
  Map<String, SObjectField> getFieldMap(SObjectType sobjectToken);
  Map<String, FieldSet> getFieldsetMap(SObjectType sobjectToken);
  DescribeFieldResult getFieldDescribe(SObjectField field);
  Type getTypeForName(String className);
  List<SObject> queryWithBinds(String soql, Map<String, Object> binds, System.AccessLevel mode);
  Integer countQueryWithBinds(String soql, Map<String, Object> binds, System.AccessLevel mode);
  Database.QueryLocator getQueryLocatorWithBinds(String soql, Map<String, Object> binds, System.AccessLevel mode);
  List<List<SObject>> search(String sosl, System.AccessLevel mode);
}

inherited sharing class Persistent {
  static INamespace getNamespace(String scope);
  static String buildGlobalKey(String scope, String name, Boolean validate);
  static void globalPutAll(Map<String, Object> valuesByGlobalKey);
  static void globalRemoveAll(Set<String> globalKeys);
  static Map<String, Object> globalGetAll();
  static Set<String> globalKeySet();
  class RuntimeException extends Exception {
  }
  interface INamespace {
    Object get(String name);
    Map<String, Object> getAll();
    Map<String, Object> getAll(Set<String> names);
    Boolean containsKey(String name);
    Set<String> keySet();
    void put(String name, Object value);
    void putAll(Map<String, Object> valuesByName);
    void remove(String name);
    void removeAll();
    void removeAll(Set<String> names);
    String prefix();
  }
}

virtual inherited sharing class Query implements IQuery {
  virtual IQuery deepClone();
  virtual IModel source();
  virtual IQueryFields fields();
  virtual Query addAllFields();
  virtual Query addAllFields(Object route);
  virtual IQuery addImplicitFields();
  virtual IQuery addSubquery(SObjectField relationshipField, IQuery child);
  virtual IQuery addSubquery(String relationshipName, IQuery child);
  virtual Map<String, IQuery> getSubqueryMap();
  virtual ILogicalCondition filters();
  virtual IQuery addCondition(ICondition condition);
  virtual List<IOrdering> orderings();
  virtual IQuery setLimit(Integer maxRows);
  virtual IQuery setOffset(Integer skipRows);
  virtual IQuery withSecurity(Boolean enforce);
  virtual IQuery withSharing(Boolean enforce);
  virtual IQuery forUpdate(Boolean lock);
  virtual IQuery allRows(Boolean include);
  virtual IQuery usingScope(Enums.FilterScope scope);
  virtual IQuery forView(Boolean mark);
  virtual IQuery forReference(Boolean mark);
  virtual String toSoql();
  virtual String toSoql(Boolean binding);
  virtual List<SObject> run();
  virtual List<SObject> fetch(Integer maxRows);
  virtual SObject fetch();
  virtual Integer count();
  virtual Database.QueryLocator toLocator();
}

abstract inherited sharing class BaseQuery extends Query implements IQuery {
  BaseQuery();
  BaseQuery(IModel model);
  BaseQuery(BaseQuery other);
  void init(IModel source);
  virtual void onInitialized(IModel source);
  virtual Set<SObjectField> getDefaultFields();
  IQuery base();
}

class RandomUtil {
  static Integer getInteger();
  static Integer getIntegerUnique();
  static Integer getIntegerBetween(Integer min, Integer max);
  static Integer getCountingNumber();
  static Integer getInteger(Integer length);
  static Integer getIntegerBetweenUnique(Integer min, Integer max);
  static Object getListItem(List<Object> options);
  static String getString(Integer length, String chars);
  static String getString(Integer length);
  static Decimal getDecimal(Integer length);
  static Decimal getDecimal(Integer left, Integer right);
  static Id getId(SObjectType token);
  static Id getIdUnique(SObjectType token);
  class RuntimeException extends Exception {
  }
}

class RecordsUtil {
  static Boolean updateWhereDifferent(List<SObject> targets, SObject pattern, IWork work);
  static Boolean updateWhereDifferent(SObject target, SObject pattern, IWork work);
  static Boolean updateWhereBlank(List<SObject> targets, SObject pattern, IWork work);
  static Boolean updateWhereBlank(SObject target, SObject pattern, IWork work);
  static Boolean doTemplatedUpdate(IModel model, List<SObject> targets, SObject pattern, IWork work, Boolean blanksOnly);
  class GenericException extends Exception {
  }
}

class StringUtil {
  static Boolean areEquivalent(String first, String second, Boolean caseSensitive);
  static Boolean containsAll(Iterable<String> pool, Iterable<String> wanted, Boolean caseSensitive);
  static Boolean containsAny(Iterable<String> pool, Iterable<String> wanted, Boolean caseSensitive);
}

class TandemSortingUtil {
  static void sort(SObject[] records, IPath path, Boolean ascending, Boolean nullsAtEnd);
  static void sort(List<Object> companions, List<String> keys, Boolean ascending, Boolean nullsAtEnd);
  static void sort(List<Object> companions, List<Decimal> keys, Boolean ascending, Boolean nullsAtEnd);
  static void sort(List<Object> companions, List<Datetime> keys, Boolean ascending, Boolean nullsAtEnd);
  static void sort(List<Object> companions, List<Boolean> keys, Boolean ascending, Boolean nullsAtEnd);
  class GeneralException extends Exception {
  }
}

class UuidUtil {
  class Converter {
    Converter(List<List<Integer>> offsetTables);
    Converter(CachingDirection caching, List<List<Integer>> offsetTables);
    List<String> fromRecordIds(Iterable<String> recordIds);
    String fromRecordId(String recordId);
    List<String> toRecordIds(Iterable<String> uuids);
    Id toRecordId(String uuid);
  }
  enum CachingDirection {
    Unidirectional, Bidirectional;
  }
}
