global interface IApplication extends ICore {
  IServiceFactory sf();
  IQueryFactory qf();
  IDomainFactory df();
  ITriggeredFactory tf();
}
