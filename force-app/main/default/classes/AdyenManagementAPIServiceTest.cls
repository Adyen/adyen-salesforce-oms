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

    @isTest
    static void fetchApiCredentialDetailsSuccessTest() {
        // Given
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.MockApiCredentialResponse());

        // When
        Test.startTest();
        AdyenManagementAPIService.ApiCredentialResult result = AdyenManagementAPIService.fetchApiCredentialDetails();
        Test.stopTest();

        // Then
        Assert.isTrue(result.isSuccess, 'Expected fetchApiCredentialDetails to succeed');
        Assert.isNotNull(result.apiCredential, 'API credential should not be null');
        Assert.areEqual('TestCompany', result.apiCredential.companyName, 'Company name should match');
        Assert.areEqual('test-user', result.apiCredential.username, 'Username should match');
        Assert.isTrue(result.apiCredential.active, 'Credential should be active');
    }

    @isTest
    static void fetchApiCredentialDetailsFailureTest() {
        // Given
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.MockApiCredentialCalloutFailure());

        // When
        Test.startTest();
        AdyenManagementAPIService.ApiCredentialResult result = AdyenManagementAPIService.fetchApiCredentialDetails();
        Test.stopTest();

        // Then
        Assert.isFalse(result.isSuccess, 'Expected fetchApiCredentialDetails to fail');
        Assert.isTrue(result.errorMessage.contains('Forbidden'), 'Expected error message to contain "Forbidden".');
        Assert.isNull(result.apiCredential, 'API credential should be null on failure');
    }

    @isTest
    static void getCompanyIdSuccessTest() {
        // Given
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.MockApiCredentialResponse());

        // When
        Test.startTest();
        String companyId = AdyenManagementAPIService.getCompanyId();
        Test.stopTest();

        // Then
        Assert.isNotNull(companyId, 'Company ID should not be null');
        Assert.areEqual('TestCompany', companyId, 'Company ID should match the company name from API credential');
    }

    @isTest
    static void getCompanyIdFailureTest() {
        // Given
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.MockApiCredentialCalloutFailure());

        // When
        Test.startTest();
        try {
            AdyenManagementAPIService.getCompanyId();
            Assert.fail('Expected exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenManagementAPIService.AdyenManagementAPIException.class);
            Assert.isTrue(e.getMessage().contains('Failed to fetch company ID'), 'Error message should mention company ID fetch failure');
        }
        Test.stopTest();
    }

    @isTest
    static void parseErrorMessageWithTitleTest() {
        // Given
        String errorBody = '{"title":"Invalid request","detail":"The request was malformed"}';
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(400);
        mockResponse.setStatus('Bad Request');
        mockResponse.setBody(errorBody);

        // When
        Test.startTest();
        String errorMessage = AdyenManagementAPIService.parseErrorMessage(mockResponse);
        Test.stopTest();

        // Then
        Assert.areEqual('Invalid request', errorMessage, 'Should extract title from error response');
    }

    @isTest
    static void parseErrorMessageWithDetailTest() {
        // Given
        String errorBody = '{"detail":"Authentication failed"}';
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(401);
        mockResponse.setStatus('Unauthorized');
        mockResponse.setBody(errorBody);

        // When
        Test.startTest();
        String errorMessage = AdyenManagementAPIService.parseErrorMessage(mockResponse);
        Test.stopTest();

        // Then
        Assert.areEqual('Authentication failed', errorMessage, 'Should extract detail from error response');
    }
}