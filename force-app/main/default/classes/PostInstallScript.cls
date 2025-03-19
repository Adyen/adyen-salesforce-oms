public class PostInstallScript implements InstallHandler {
    private static final String JOB_NAME = 'Adyen_PBL_Batch_Job';
    private static final String SCHEDULED_JOB_TYPE = '7'; // Scheduled Apex Job

    public void onInstall(InstallContext context) {
        if (!isBatchJobScheduled(JOB_NAME)) {
            String cronExp = '0 0 * * * ?';
            System.schedule(JOB_NAME, cronExp, new AdyenPaymentLinkBatchJobScheduler());
        } 
    }

    private Boolean isBatchJobScheduled(String jobName) {
        List<CronTrigger> scheduledJobs = [
            SELECT Id, CronJobDetail.Name 
            FROM CronTrigger 
            WHERE CronJobDetail.Name = :jobName 
            AND CronJobDetail.JobType = :SCHEDULED_JOB_TYPE
        ];

        return !scheduledJobs.isEmpty();
    }
}
