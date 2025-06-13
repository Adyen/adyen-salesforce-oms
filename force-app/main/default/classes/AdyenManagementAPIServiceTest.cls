@isTest
private class AdyenManagementAPIServiceTest {

    @isTest
    static void fetchMerchantAccountsSuccessTest() {
        // Given
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.MockMerchantAccountCallout());

        // When
        Test.startTest();
        AdyenManagementAPIService.MerchantAccountResult result = AdyenManagementAPIService.fetchMerchantAccounts();
        Test.stopTest();

        // Then
        Assert.isTrue(result.isSuccess, 'Expected fetchMerchantAccounts to succeed');
        Assert.areEqual(2, result.merchantAccounts.size(), 'Expected exactly 2 merchant accounts to be returned.');
    }

    @isTest
    static void fetchMerchantAccountsFailureTest() {
        // Given
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.MockMerchantAccountCalloutFailure());

        // When
        Test.startTest();
        AdyenManagementAPIService.MerchantAccountResult result = AdyenManagementAPIService.fetchMerchantAccounts();
        Test.stopTest();

        // Then
        Assert.isFalse(result.isSuccess, 'Expected fetchMerchantAccounts to fail');
        Assert.isTrue(result.errorMessage.contains('Unauthorized'), 'Expected error message to contain "Unauthorized".');
    }
}
