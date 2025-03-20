@IsTest
private class AdyenCustomMetadataServiceTest {

    @IsTest
    static void getDefaultAdapterTest() {
        // Given default adapter

        Test.startTest();
        // When
        Adyen_Adapter__mdt result = AdyenCustomMetadataService.getDefaultAdapter();
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, result, 'The default adapter should not be null');
        Assert.areEqual('AdyenDefault', result.DeveloperName);
    }

    @IsTest
    static void updateDefaultAdapterTest() {
        // Given
        Adyen_Adapter__mdt testAdapter = TestDataFactory.createMockAdapter();

        Test.startTest();
        // When
        String deploymentId = AdyenCustomMetadataService.updateDefaultAdapter(testAdapter);
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, deploymentId, 'Deployment ID should not be null');
        Assert.areEqual(TestDataFactory.mockDeploymentId, deploymentId);
    }

    @IsTest
    static void updateDefaultAdapterErrorTest() {
        // Given
        Adyen_Adapter__mdt testAdapter = null;

        Test.startTest();
        // When
        try {
            AdyenCustomMetadataService.updateDefaultAdapter(testAdapter);
            Assert.fail('Expected exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isTrue(e instanceof AuraHandledException);
        }
        Test.stopTest();
    }
}