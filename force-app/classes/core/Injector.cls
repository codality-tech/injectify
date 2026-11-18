/**
 * Creates framework objects by type. getInstance keeps one shared object per type; newInstance
 * always makes a fresh one. Type names resolve through the scheme, so they can name a
 * subscriber's classes.
 */
public class Injector implements IInjector {
  private Map<Type, Object> sharedByType = new Map<Type, Object>();
  private IScheme scheme;

  public Injector(IScheme scheme) {
    this.scheme = scheme;
  }

  /** The shared object for the type, created on first request. */
  public Object getInstance(Type implementation) {
    if (!sharedByType.containsKey(implementation)) {
      sharedByType.put(implementation, implementation.newInstance());
    }
    return sharedByType.get(implementation);
  }

  public Object newInstance(Type implementation) {
    return implementation == null ? null : implementation.newInstance();
  }

  public Object newInstance(String className) {
    Type resolved = getType(className);
    return newInstance(resolved);
  }

  /** Null for a null name. */
  public Type getType(String className) {
    if (className == null) {
      return null;
    }
    return scheme.getTypeForName(className);
  }
}
