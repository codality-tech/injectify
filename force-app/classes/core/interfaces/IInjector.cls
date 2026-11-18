public interface IInjector {
  Object getInstance(Type classImp);
  Object newInstance(Type classImp);
  Object newInstance(String className);
  Type getType(String className);
}
