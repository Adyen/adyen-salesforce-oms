@IsTest
private class AdyenRefundRefBatchJobSchedulerTest {
    
    @IsTest
    static void scheduleJobTest() {
        // Given
        AdyenRefundRefBatchJobScheduler scheduler = new AdyenRefundRefBatchJobScheduler();
        String cronExp = '0 0 * * * ?';
        
        // When
        Test.startTest();
        String jobId = System.schedule('Test Refund Reference Batch', cronExp, scheduler);
        Test.stopTest();
        
        // Then
        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
        Assert.areEqual(cronExp, ct.CronExpression, 'Expected cron expression to match');
    }
}