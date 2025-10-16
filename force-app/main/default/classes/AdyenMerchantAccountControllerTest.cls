@isTest
private class AdyenMerchantAccountControllerTest {

    @isTest
    static void getMerchantAccountConfigurationTest() {
        // Given & When
        Test.startTest();
        String merchantAccount = AdyenMerchantAccountController.getMerchantAccountConfiguration();
        Test.stopTest();

        // Then
        Assert.isNotNull(merchantAccount, 'Merchant account should not be null');
    }

    @isTest
    static void updateMerchantAccountSuccessTest() {
        // Given
        String newMerchantAccount = 'updated-merchant-account';

        Test.startTest();
        // When
        String deploymentId = AdyenMerchantAccountController.updateMerchantAccount(newMerchantAccount);
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, deploymentId, 'Deployment ID should not be null');
        Assert.areEqual(TestDataFactory.mockDeploymentId, deploymentId, 'Returned deployment ID did not match the expected mock value.');
    }

    @isTest
    static void updateMerchantAccountBlankTest() {
        // Given & When
        Test.startTest(); 
        try {
            AdyenMerchantAccountController.updateMerchantAccount('');
            Assert.fail('An Exception should have been thrown.');
        } catch (AuraHandledException e) {
            // Then
            Assert.areEqual(e.getMessage(), 'Script-thrown exception', 'Exception message did not match expected message.');
        }
        Test.stopTest();
    }
}