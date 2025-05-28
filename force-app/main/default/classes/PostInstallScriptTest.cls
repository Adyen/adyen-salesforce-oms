@IsTest
private class PostInstallScriptTest {
    
    @IsTest
    static void testInstallScript() {
        // Given
        PostInstallScript postInstall = new PostInstallScript();
        
        // When
        Test.testInstall(postInstall, null);
        
        // Then
        List<CronTrigger> pblJobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Adyen_PBL_Batch_Job'];
        Assert.areEqual(1, pblJobs.size(), 'Expected one Adyen_PBL_Batch_Job scheduled after fresh install');
        
        List<CronTrigger> refundJobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Adyen_Refund_Reference_Batch_Job'];
        Assert.areEqual(1, refundJobs.size(), 'Expected one Adyen_RefundReference_Batch_Job scheduled after fresh install');
        
        // When: Simulating an upgrade from version 1.0 to the current version
        Test.testInstall(postInstall, new Version(1, 0));
        
        // Then: Ensure the job is still only scheduled once (no duplicate scheduling)
        pblJobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Adyen_PBL_Batch_Job'];
        Assert.areEqual(1, pblJobs.size(), 'Expected only one Adyen_PBL_Batch_Job after upgrade');
        
        refundJobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Adyen_Refund_Reference_Batch_Job'];
        Assert.areEqual(1, refundJobs.size(), 'Expected only one Adyen_RefundReference_Batch_Job after upgrade');
    }
}