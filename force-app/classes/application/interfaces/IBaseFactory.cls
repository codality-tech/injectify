global interface IBaseFactory {
  void register(Map<Type, Type> registryPatch);
  Type getRegisteredClass(Type key);
}
