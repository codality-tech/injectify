/**
 * Small values that outlive the transaction, kept in the Persistent__c list custom setting.
 * Keys are grouped by prefix: a namespace with prefix `p` stores key `k` as the record `p@k`,
 * and the blank prefix stores it as plain `k`. Prefixes and keys are letters, digits and
 * underscores; together they fit the setting's 38-character record name.
 *
 * Values are primitives (Boolean, Id, String, Date, Datetime, Time, Integer, Long, Decimal,
 * Double), stored as JSON along with their type so they read back as the same type. Storing null
 * removes the key.
 */
global inherited sharing class Persistent {
  private static final String SEPARATOR = '@';
  private static final Integer NAME_LIMIT = 38;
  private static final Integer VALUE_LIMIT = 255;
  private static final Pattern FRAGMENT = Pattern.compile('\\w+');
  private static final Pattern GLOBAL_KEY = Pattern.compile('(\\w+@)?\\w+');

  global class RuntimeException extends Exception {
  }

  /** The keys under one prefix, or null when the prefix is malformed. */
  global static INamespace getNamespace(String scope) {
    if (!isPrefix(scope)) {
      return null;
    }
    return new Namespace(scope);
  }

  /** `prefix@key`, or the bare key for a blank prefix. With `validate`, a bad key throws. */
  global static String buildGlobalKey(String scope, String name, Boolean validate) {
    String globalKey = String.isBlank(scope) ? name : scope + SEPARATOR + name;
    Boolean usable = isPrefix(scope) && matches(FRAGMENT, name) && fits(globalKey);
    if (validate == true && !usable) {
      throw new RuntimeException('Not a usable key: ' + globalKey);
    }
    return globalKey;
  }

  global static void globalPutAll(Map<String, Object> valuesByGlobalKey) {
    for (String globalKey : valuesByGlobalKey.keySet()) {
      if (!matches(GLOBAL_KEY, globalKey) || !fits(globalKey)) {
        throw new RuntimeException('Not a usable key: ' + globalKey);
      }
    }
    store(valuesByGlobalKey);
  }

  /** Removes the keys without validating them, so malformed leftovers can be cleared. */
  global static void globalRemoveAll(Set<String> globalKeys) {
    Map<String, Object> cleared = new Map<String, Object>();
    for (String globalKey : globalKeys) {
      cleared.put(globalKey, null);
    }
    store(cleared);
  }

  global static Map<String, Object> globalGetAll() {
    Map<String, Object> valuesByGlobalKey = new Map<String, Object>();
    for (Persistent__c stored : Persistent__c.getAll().values()) {
      valuesByGlobalKey.put(stored.Name, decode(stored));
    }
    return valuesByGlobalKey;
  }

  /** Every stored key, prefixes included. */
  global static Set<String> globalKeySet() {
    Map<String, Persistent__c> everything = Persistent__c.getAll();
    return everything.keySet();
  }

  global interface INamespace {
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

  public virtual class Namespace implements INamespace {
    private String scope;

    private Namespace(String scope) {
      this.scope = scope;
    }

    public Object get(String name) {
      return read(buildGlobalKey(scope, name, true));
    }

    public Map<String, Object> getAll() {
      Map<String, Object> found = new Map<String, Object>();
      Map<String, String> storedNames = globalKeysUnder(scope);
      for (String name : storedNames.keySet()) {
        found.put(name, read(storedNames.get(name)));
      }
      return found;
    }

    /** One entry per requested key; missing keys map to null. */
    public Map<String, Object> getAll(Set<String> names) {
      Map<String, Object> found = new Map<String, Object>();
      for (String name : names) {
        found.put(name, get(name));
      }
      return found;
    }

    public Boolean containsKey(String name) {
      return get(name) != null;
    }

    public Set<String> keySet() {
      return globalKeysUnder(scope).keySet();
    }

    public void put(String name, Object value) {
      putAll(new Map<String, Object>{ name => value });
    }

    public void putAll(Map<String, Object> valuesByName) {
      Map<String, Object> valuesByGlobalKey = new Map<String, Object>();
      for (String name : valuesByName.keySet()) {
        valuesByGlobalKey.put(buildGlobalKey(scope, name, true), valuesByName.get(name));
      }
      store(valuesByGlobalKey);
    }

    public void remove(String name) {
      put(name, null);
    }

    /** Clears every key under the prefix, including any that no longer validate. */
    public void removeAll() {
      globalRemoveAll(new Set<String>(globalKeysUnder(scope).values()));
    }

    public void removeAll(Set<String> names) {
      Map<String, Object> cleared = new Map<String, Object>();
      for (String name : names) {
        cleared.put(name, null);
      }
      putAll(cleared);
    }

    public String prefix() {
      return scope;
    }
  }

  private static Boolean isPrefix(String scope) {
    return String.isBlank(scope) || matches(FRAGMENT, scope);
  }

  private static Boolean matches(Pattern shape, String text) {
    return text != null && shape.matcher(text).matches();
  }

  private static Boolean fits(String globalKey) {
    return globalKey.length() <= NAME_LIMIT;
  }

  // Maps each local key under the prefix to its stored name.
  private static Map<String, String> globalKeysUnder(String scope) {
    Boolean bare = String.isBlank(scope);
    String lead = bare ? '' : scope + SEPARATOR;
    Map<String, String> storedByLocal = new Map<String, String>();
    for (String globalKey : globalKeySet()) {
      Boolean belongs = bare
        ? !globalKey.contains(SEPARATOR)
        : globalKey.startsWith(lead) && globalKey.length() > lead.length();
      if (belongs) {
        storedByLocal.put(globalKey.substring(lead.length()), globalKey);
      }
    }
    return storedByLocal;
  }

  private static Object read(String globalKey) {
    Persistent__c stored = globalKey == null ? null : Persistent__c.getInstance(globalKey);
    return stored == null ? null : decode(stored);
  }

  @TestVisible
  private static void store(Map<String, Object> valuesByGlobalKey) {
    if (valuesByGlobalKey == null) {
      return;
    }
    List<Persistent__c> writes = new List<Persistent__c>();
    List<Persistent__c> deletions = new List<Persistent__c>();
    for (String globalKey : valuesByGlobalKey.keySet()) {
      Object value = valuesByGlobalKey.get(globalKey);
      Persistent__c stored = Persistent__c.getInstance(globalKey);
      if (value != null) {
        writes.add(encode(stored ?? new Persistent__c(Name = globalKey), value));
      } else if (stored != null) {
        deletions.add(stored);
      }
    }
    if (!writes.isEmpty()) {
      Database.upsert(writes, true, AccessLevel.SYSTEM_MODE); // a protected setting: system mode
    }
    if (!deletions.isEmpty()) {
      Database.delete(deletions, true, AccessLevel.SYSTEM_MODE);
    }
  }

  private static Persistent__c encode(Persistent__c target, Object value) {
    String typeName = typeNameOf(value);
    String serialized = JSON.serialize(value);
    if (serialized.length() > VALUE_LIMIT) {
      throw new RuntimeException(
        target.Name + ' needs ' + serialized.length() + ' characters; at most ' + VALUE_LIMIT + ' fit'
      );
    }
    target.Type__c = typeName;
    target.Value__c = serialized;
    return target;
  }

  private static Object decode(Persistent__c stored) {
    return JSON.deserialize(stored.Value__c, Type.forName(stored.Type__c));
  }

  // The names are stored in Type__c, so they must not change. Order matters: an Id also passes
  // as a String and a Date as a Datetime, so the narrower type is tested first.
  private static String typeNameOf(Object value) {
    if (value instanceof Boolean) {
      return 'Boolean';
    } else if (value instanceof Id) {
      return 'Id';
    } else if (value instanceof String) {
      return 'String';
    } else if (value instanceof Date) {
      return 'Date';
    } else if (value instanceof Datetime) {
      return 'Datetime';
    } else if (value instanceof Time) {
      return 'Time';
    } else if (value instanceof Integer) {
      return 'Integer';
    } else if (value instanceof Long) {
      return 'Long';
    } else if (value instanceof Decimal) {
      return 'Decimal';
    } else if (value instanceof Double) {
      return 'Double';
    }
    throw new RuntimeException('Only primitive values can be stored, not ' + value);
  }
}
