@IsTest
private class PostInstallScriptTest {
    
    @IsTest
    static void testInstallScript() {
        // Given
        PostInstallScript postInstall = new PostInstallScript();
        
        // When
        Test.testInstall(postInstall, null);

        // Then
        List<CronTrigger> jobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Adyen_PBL_Batch_Job'];
        Assert.areEqual(1, jobs.size(), 'Expected one scheduled job after fresh install');

        // When: Simulating an upgrade from version 1.0 to the current version
        Test.testInstall(postInstall, new Version(1, 0));

        // Then: Ensure the job is still only scheduled once (no duplicate scheduling)
        jobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Adyen_PBL_Batch_Job'];
        Assert.areEqual(1, jobs.size(), 'Expected only one scheduled job after upgrade');
    }
}