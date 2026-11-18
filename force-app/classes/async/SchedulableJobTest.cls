@IsTest
private class SchedulableJobTest {
  private static List<String> trail = new List<String>();
  private static Id idSeenInside;

  private class Nightly extends SchedulableJob {
    private String cron;

    public override void execute() {
      trail.add('nightly');
      idSeenInside = getJobId();
    }

    public override String cronExpression() {
      return cron == null ? super.cronExpression() : cron;
    }
  }

  private class Marker extends QueueableJob {
    public override void execute() {
      trail.add('next');
    }
  }

  private static Integer scheduledCount(String jobName) {
    return [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = :jobName];
  }

  @IsTest
  static void buildsAOneTimeCronExpression() {
    String cron = new Nightly().toCronExpression(Datetime.newInstance(2031, 2, 3, 4, 5, 6));

    Assert.areEqual('6 5 4 3 2 ? 2031', cron);
  }

  @IsTest
  static void defaultsToItsClassNameAndOneMinuteAhead() {
    Nightly job = new Nightly();

    Assert.isTrue(job.name().endsWith('Nightly'), job.name());
    Assert.isFalse(job.name().contains(':'), job.name());
    List<String> fields = job.cronExpression().split(' ');
    Assert.areEqual(7, fields.size());
    Assert.areEqual('?', fields[5]);
  }

  @IsTest
  static void runsInTheCallersTransactionWhenSynchronousInTests() {
    Async.synchronousInTests = true;
    Nightly job = new Nightly();
    job.then(new Marker());

    job.run();

    Assert.areEqual(new List<String>{ 'nightly', 'next' }, trail);
    Assert.isNull(job.getJobId());
  }

  // The platform won't execute a schedulable declared inside a test, so the real run uses a handler.
  private class NightlyHandler implements ISchedulableHandler {
    public void schedulableExecute() {
      trail.add('nightly');
    }
    public String name() {
      return 'SchedulableJobTest nightly';
    }
    public String cronExpression() {
      return new Nightly().toCronExpression(Datetime.now().addMinutes(1));
    }
  }

  private class UnnamedHandler implements ISchedulableHandler {
    public void schedulableExecute() {
      trail.add('unnamed');
    }
    public String name() {
      return null;
    }
    public String cronExpression() {
      return '';
    }
  }

  @IsTest
  static void aHandlerWithoutNameOrScheduleGetsTheDefaults() {
    ISchedulable job = Async.schedulable(new UnnamedHandler());

    Assert.isTrue(job.name().endsWith('UnnamedHandler'), job.name());
    Assert.isTrue(String.isNotBlank(job.cronExpression()));
    Assert.areEqual(7, job.cronExpression().split(' ').size(), 'a one-time expression, a minute ahead');
  }

  private class FakeContext implements SchedulableContext {
    private Id triggerId;

    private FakeContext(Id triggerId) {
      this.triggerId = triggerId;
    }
    public Id getTriggerId() {
      return triggerId;
    }
  }

  @IsTest
  static void schedulesUnderItsNameAndRunsAtStopTest() {
    Async.synchronousInTests = false;
    ISchedulable job = Async.schedulable(new NightlyHandler());

    Test.startTest();
    job.run();
    Assert.areEqual(1, scheduledCount(job.name()));
    Test.stopTest();

    Assert.areEqual(new List<String>{ 'nightly' }, trail);
    Assert.isNotNull(job.getJobId());
  }

  @IsTest
  static void theTriggerIdReachesTheBodyAndTheChainContinues() {
    Async.synchronousInTests = true; // only decides how the follow-up job starts
    Id triggerId = IdUtil.generateId(CronTrigger.SObjectType);
    Nightly job = new Nightly();
    job.then(new Marker());

    job.execute(new FakeContext(triggerId));

    Assert.areEqual(new List<String>{ 'nightly', 'next' }, trail);
    Assert.areEqual(triggerId, idSeenInside);
    Assert.areEqual(triggerId, job.getJobId());
  }

  @IsTest
  static void unscheduleAbortsJobsWithItsName() {
    Async.synchronousInTests = false;
    Nightly job = new Nightly();
    job.cron = '0 0 0 1 1 ? 2099';
    job.run();
    Assert.areEqual(1, scheduledCount(job.name()));

    job.unschedule();

    Assert.areEqual(0, scheduledCount(job.name()));
  }
}
