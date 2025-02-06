@IsTest
private class AdyenPaymentLinkBatchJobSchedulerTest {

    @IsTest
    static void scheduleJobTest() {
        // Given
        AdyenPaymentLinkBatchJobScheduler paymentLinkJob = new AdyenPaymentLinkBatchJobScheduler();
        String sch = '0 0 * * * ?';
        
        // When
        Test.startTest();
        String jobId = System.schedule('Test Payment Link Batch', sch, paymentLinkJob);
        Test.stopTest();

        // Then
        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
        Assert.areEqual(sch, ct.CronExpression);
    }
}