public class PostInstallScript implements InstallHandler {
    private static final String ADYEN_PBL_JOB_NAME = 'Adyen_PBL_Batch_Job';
    private static final String REFUND_REFERENCE_JOB_NAME = 'Adyen_Refund_Reference_Batch_Job';
    private static final String SCHEDULED_JOB_TYPE = '7'; // Scheduled Apex Job
    private static final String DEFAULT_CRON_EXPRESSION = '0 0 * * * ?';

    public void onInstall(InstallContext context) {
        if (!isBatchJobScheduled(ADYEN_PBL_JOB_NAME)) {
            System.schedule(ADYEN_PBL_JOB_NAME, DEFAULT_CRON_EXPRESSION, new AdyenPaymentLinkBatchJobScheduler());
        }

        if (!isBatchJobScheduled(REFUND_REFERENCE_JOB_NAME)) {
            System.schedule(REFUND_REFERENCE_JOB_NAME, DEFAULT_CRON_EXPRESSION, new AdyenRefundRefBatchJobScheduler());
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
