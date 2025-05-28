public class PostInstallScript implements InstallHandler {
    private static final String ADYEN_PBL_JOB_NAME = 'Adyen_PBL_Batch_Job';
    private static final String REFUND_REFERENCE_JOB_NAME = 'Adyen_Refund_Reference_Batch_Job';
    private static final String SCHEDULED_JOB_TYPE = '7'; // Scheduled Apex Job

    public void onInstall(InstallContext context) {
        if (!isBatchJobScheduled(ADYEN_PBL_JOB_NAME)) {
            String cronExp = '0 0 * * * ?';
            System.schedule(ADYEN_PBL_JOB_NAME, cronExp, new AdyenPaymentLinkBatchJobScheduler());
        }

        if (!isBatchJobScheduled(REFUND_REFERENCE_JOB_NAME)) {
            String cronExp = '0 0 * * * ?';
            System.schedule(REFUND_REFERENCE_JOB_NAME, cronExp, new AdyenRefundRefBatchJobScheduler());
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
