public class QueryFragmentRegistry {

    private Map<String,IQueryFragment> fragments = new Map<String,IQueryFragment>();

    public void register(String name, IQueryFragment fragment){
        if (String.isBlank(name) || fragment == null) return;
        fragments.put(name, fragment);
    }

    public Boolean has(String name){
        return fragments.containsKey(name);
    }

    public IQuery apply(String name, IQuery base){
        IQueryFragment f = fragments.get(name);
        if (f == null) return base;
        return f.apply(base);
    }
}


