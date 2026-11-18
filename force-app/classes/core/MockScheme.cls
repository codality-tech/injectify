/**
 * A scheme for unit tests. Describes are real, but queries return the rows you register instead
 * of reading the database, and every query is recorded with its bind values. Inject it with
 * Application.make(scheme) or new Core(scheme) to test query-driven logic without inserting data:
 *
 *   MockScheme scheme = new MockScheme().returning(Account.SObjectType, cannedAccounts);
 *   IApplication app = Application.make(scheme);
 *   // ... code under test queries through app ...
 *   Assert.areEqual('Acme', scheme.bindMaps()[0].get('a0'));
 *
 * A query returns the rows registered for its outermost FROM object (none if nothing was
 * registered), as a list of that object's type. Aggregate queries return no rows, since Apex cannot
 * build an AggregateResult. Query locators come from the database, the only source of one.
 *
 * A search returns one list per object named after RETURNING, in that order, holding the rows
 * registered for the object. Its SOSL is recorded with the queries, with no bind values.
 */
global inherited sharing class MockScheme implements IScheme, ISearchScheme {
  private static final List<String> AGGREGATE_CALLS = new List<String>{
    'COUNT(',
    'COUNT_DISTINCT(',
    'SUM(',
    'AVG(',
    'MIN(',
    'MAX(',
    'GROUPING('
  };

  private IScheme describes = new SchemeDefault();
  private Map<String, List<SObject>> rowsByObject = new Map<String, List<SObject>>();
  private List<String> ran = new List<String>();
  private List<Map<String, Object>> bound = new List<Map<String, Object>>();

  global MockScheme() {
  }

  /** Every query against the object returns these rows, in this order. Returns this scheme. */
  global MockScheme returning(SObjectType objectType, List<SObject> rows) {
    rowsByObject.put(String.valueOf(objectType).toLowerCase(), rows == null ? new List<SObject>() : rows.clone());
    return this;
  }

  /** The SOQL of every query, count and locator, and the SOSL of every search, oldest first. */
  global List<String> queries() {
    return ran.clone();
  }

  /** The bind values of each recorded query, in the same order as queries(). */
  global List<Map<String, Object>> bindMaps() {
    return bound.clone();
  }

  // Describes

  global SObjectType getSObjectType(String sobjectName) {
    return describes.getSObjectType(sobjectName);
  }

  global DescribeSObjectResult getDescribe(SObjectType sobjectToken) {
    return describes.getDescribe(sobjectToken);
  }

  global Map<String, SObjectField> getFieldMap(SObjectType sobjectToken) {
    return describes.getFieldMap(sobjectToken);
  }

  global Map<String, FieldSet> getFieldsetMap(SObjectType sobjectToken) {
    return describes.getFieldsetMap(sobjectToken);
  }

  global DescribeFieldResult getFieldDescribe(SObjectField field) {
    return describes.getFieldDescribe(field);
  }

  global Type getTypeForName(String className) {
    return describes.getTypeForName(className);
  }

  // Queries

  global List<SObject> queryWithBinds(String soql, Map<String, Object> binds, System.AccessLevel mode) {
    record(soql, binds);
    if (isAggregate(soql)) {
      return new List<AggregateResult>();
    }
    return rowsFor(soql);
  }

  global Integer countQueryWithBinds(String soql, Map<String, Object> binds, System.AccessLevel mode) {
    record(soql, binds);
    return rowsFor(soql).size();
  }

  global Database.QueryLocator getQueryLocatorWithBinds(String soql, Map<String, Object> binds, System.AccessLevel mode) {
    record(soql, binds);
    return Database.getQueryLocatorWithBinds(soql, binds, mode);
  }

  global List<List<SObject>> search(String sosl, System.AccessLevel mode) {
    record(sosl, null);
    List<List<SObject>> found = new List<List<SObject>>();
    for (String objectName : returningObjects(sosl)) {
      found.add(typedRows(objectName));
    }
    return found;
  }

  private void record(String soql, Map<String, Object> binds) {
    ran.add(soql);
    bound.add(binds == null ? new Map<String, Object>() : binds.clone());
  }

  // The registered rows of the outermost FROM object, in a list of that object's type.
  private List<SObject> rowsFor(String soql) {
    return typedRows(outerObject(soql));
  }

  private List<SObject> typedRows(String objectName) {
    List<SObject> typed = (List<SObject>) Type.forName('List<' + objectName + '>').newInstance();
    List<SObject> rows = rowsByObject.get(objectName.toLowerCase());
    if (rows != null) {
      typed.addAll(rows);
    }
    return typed;
  }

  // The object named by the first FROM outside parentheses, so subqueries are skipped.
  @TestVisible
  private static String outerObject(String soql) {
    String upper = soql.toUpperCase();
    Integer depth = 0;
    for (Integer at = 0; at < soql.length(); at++) {
      String symbol = soql.mid(at, 1);
      if (symbol == '(') {
        depth++;
      } else if (symbol == ')') {
        depth--;
      } else if (depth == 0 && upper.mid(at, 5) == 'FROM ' && (at == 0 || soql.mid(at - 1, 1) == ' ')) {
        return soql.substring(at + 5).trim().split('\\s+')[0];
      }
    }
    throw new IllegalArgumentException('No FROM clause in: ' + soql);
  }

  // The objects a search returns: the names after RETURNING, without their bracketed clauses,
  // up to a WITH or LIMIT that belongs to the search itself.
  @TestVisible
  private static List<String> returningObjects(String sosl) {
    List<String> names = new List<String>();
    Integer starts = sosl.toUpperCase().indexOf(' RETURNING ');
    if (starts < 0) {
      return names;
    }
    String listed = sosl.substring(starts + 11);
    String upper = listed.toUpperCase();
    Integer depth = 0;
    Boolean quoted = false;
    String name = '';
    for (Integer at = 0; at < listed.length(); at++) {
      String symbol = listed.mid(at, 1);
      if (quoted) {
        if (symbol == '\\') {
          at++; // the escaped character is part of the literal
        } else if (symbol == '\'') {
          quoted = false;
        }
      } else if (symbol == '\'') {
        quoted = true;
      } else if (symbol == '(') {
        depth++;
      } else if (symbol == ')') {
        depth--;
      } else if (depth == 0) {
        if (upper.mid(at, 6) == ' WITH ' || upper.mid(at, 7) == ' LIMIT ') {
          break;
        }
        if (symbol == ',') {
          names.add(name.trim());
          name = '';
        } else {
          name += symbol;
        }
      }
    }
    if (String.isNotBlank(name)) {
      names.add(name.trim());
    }
    return names;
  }

  // Whether the SELECT list calls an aggregate function.
  private static Boolean isAggregate(String soql) {
    String upper = soql.toUpperCase();
    String selectList = upper.substringBefore(' FROM ');
    for (String call : AGGREGATE_CALLS) {
      if (selectList.contains(call)) {
        return true;
      }
    }
    return false;
  }
}
