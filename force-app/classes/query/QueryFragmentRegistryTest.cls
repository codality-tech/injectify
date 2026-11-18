@IsTest
private class QueryFragmentRegistryTest {
  private class LimitSecureFragment implements IQueryFragment {
    private Integer lim;
    LimitSecureFragment(Integer lim) {
      this.lim = lim;
    }
    public IQuery apply(IQuery base) {
      return base.withSecurity(true).setLimit(lim);
    }
  }

  @IsTest
  static void testRegisterAndApply() {
    QueryFragmentRegistry reg = new QueryFragmentRegistry();
    System.assertEquals(false, reg.has('ls2'));
    reg.register('ls2', new LimitSecureFragment(2));
    System.assertEquals(true, reg.has('ls2'));

    IQuery base = Application.s.model(Account.SObjectType)
      .query(new List<ICondition>());
    IQuery q = reg.apply('ls2', base);
    String soql = q.toSoql(false);
    System.assert(soql.contains('FROM Account'), 'Should include Account');
    System.assert(soql.contains('LIMIT 2'), 'Should include limit');
    System.assert(
      soql.contains('SECURITY_ENFORCED'),
      'Should enforce security'
    );
  }
}
