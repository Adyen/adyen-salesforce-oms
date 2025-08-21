@IsTest
private class AdyenWebhookSetupControllerTest {

    @IsTest(SeeAllData=true)
    static void getWebhookUrlSuccessTest() {
        // Given
        Test.startTest();
        
        // When
        String webhookUrl = AdyenWebhookSetupController.getWebhookUrl();
        
        Test.stopTest();
        
        // Then
        Assert.isNotNull(webhookUrl, 'Webhook URL should not be null');
        Assert.isTrue(webhookUrl.endsWith('adyenNotification/v1'), 'Webhook URL should end with notification endpoint');
    }

    @IsTest(SeeAllData=true)
    static void setupWebhookSuccessTest() {
        // Given
        String description = 'Test Webhook Description';
        List<String> eventCodes = new List<String>{'CAPTURE', 'REFUND', 'CAPTURE_FAILED', 'REFUND_FAILED'};
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.WebhookSetupMockResponse());
        
        Test.startTest();
        
        // When
        AdyenWebhookSetupController.WebhookSetupResult result = AdyenWebhookSetupController.setupWebhook(description, eventCodes);
        
        Test.stopTest();
        
        // Then
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isTrue(result.isSuccess, 'Setup should be successful');
        Assert.isNull(result.errorMessage, 'Error message should be null on success');
        Assert.isNotNull(result.webhookResponse, 'Webhook response should not be null');
    }

    @IsTest
    static void setupWebhookEmptyDescriptionTest() {
        // Given
        String description = '';
        List<String> eventCodes = new List<String>{'CAPTURE', 'REFUND'};
        
        Test.startTest();
        
        // When
        AdyenWebhookSetupController.WebhookSetupResult result = AdyenWebhookSetupController.setupWebhook(description, eventCodes);
        
        Test.stopTest();
        
        // Then
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isFalse(result.isSuccess, 'Setup should fail');
        Assert.isNotNull(result.errorMessage, 'Error message should not be null');
        Assert.isTrue(result.errorMessage.contains('Description cannot be empty'), 'Error message should mention empty description');
        Assert.isNull(result.webhookResponse, 'Webhook response should be null on failure');
    }

    @IsTest
    static void setupWebhookEmptyEventCodesTest() {
        // Given
        List<String> emptyEventCodes = new List<String>();
        
        Test.startTest();
        
        // When & Then
        AdyenWebhookSetupController.WebhookSetupResult result = AdyenWebhookSetupController.setupWebhook('Test Description', emptyEventCodes);
        Assert.isFalse(result.isSuccess, 'Setup should fail with empty event codes');
        Assert.isTrue(result.errorMessage.contains('At least one event code must be selected'), 'Error message should mention event codes requirement');
        
        Test.stopTest();
    }

    @IsTest(SeeAllData=true)
    static void setupWebhookServiceExceptionTest() {
        // Given
        String description = 'Test Webhook Description';
        List<String> eventCodes = new List<String>{'CAPTURE', 'REFUND'};
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.FailureResponse());
        
        Test.startTest();
        
        // When
        AdyenWebhookSetupController.WebhookSetupResult result = AdyenWebhookSetupController.setupWebhook(description, eventCodes);
        
        Test.stopTest();
        
        // Then
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isFalse(result.isSuccess, 'Setup should fail when service throws exception');
        Assert.isNull(result.webhookResponse, 'Webhook response should be null on failure');
    }

    @IsTest(SeeAllData=true)
    static void setupWebhookWithHmacSuccessTest() {
        // Given
        String description = 'Test Webhook Description';
        List<String> eventCodes = new List<String>{'CAPTURE', 'REFUND'};
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.WebhookSetupWithHmacMockResponse());
        
        Test.startTest();
        
        // When
        AdyenWebhookSetupController.WebhookSetupResult result = AdyenWebhookSetupController.setupWebhook(description, eventCodes);
        
        Test.stopTest();
        
        // Then
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isTrue(result.isSuccess, 'Setup should be successful');
        Assert.isNotNull(result.webhookResponse, 'Webhook response should not be null');
        Assert.isNotNull(result.hmacKey, 'HMAC key should be generated');
        Assert.isFalse(result.hmacGenerationFailed, 'HMAC generation should not fail');
        Assert.isNull(result.hmacErrorMessage, 'HMAC error message should be null on success');
    }

    @IsTest(SeeAllData=true)
    static void setupWebhookWithHmacFailureTest() {
        // Given
        String description = 'Test Webhook Description';
        List<String> eventCodes = new List<String>{'CAPTURE', 'REFUND'};
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.WebhookSetupWithHmacFailureMockResponse());
        
        Test.startTest();
        
        // When
        AdyenWebhookSetupController.WebhookSetupResult result = AdyenWebhookSetupController.setupWebhook(description, eventCodes);
        
        Test.stopTest();
        
        // Then
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isTrue(result.isSuccess, 'Webhook setup should still be successful');
        Assert.isNotNull(result.webhookResponse, 'Webhook response should not be null');
        Assert.isNull(result.hmacKey, 'HMAC key should be null on failure');
        Assert.isTrue(result.hmacGenerationFailed, 'HMAC generation should fail');
        Assert.isNotNull(result.hmacErrorMessage, 'HMAC error message should not be null on failure');
    }

    @IsTest(SeeAllData=true)
    static void saveWebhookDataToMetadataSuccessTest() {
        // Given
        String hmacKey = 'test-hmac-key-123456789';
        String webhookId = 'WBHK12345678912345678912345678';
        
        Test.startTest();
        // When
        String deploymentId = AdyenWebhookSetupController.saveWebhookDataToMetadata(hmacKey, webhookId);
        Test.stopTest();
        
        // Then
        Assert.areNotEqual(null, deploymentId, 'Deployment ID should not be null');
    }

    @IsTest
    static void saveWebhookDataToMetadataEmptyHmacKeyTest() {
        // Given
        String hmacKey = null;
        String webhookId = 'WBHK12345678912345678912345678';
        
        Test.startTest();
        // When & Then
        try {
            AdyenWebhookSetupController.saveWebhookDataToMetadata(hmacKey, webhookId);
            Assert.fail('Expected exception was not thrown');
        } catch (Exception e) {
            Assert.isInstanceOfType(e, AuraHandledException.class);
        }
        Test.stopTest();
    }

    @IsTest
    static void saveWebhookDataToMetadataEmptyWebhookIdTest() {
        // Given
        String hmacKey = 'test-hmac-key-123456789';
        String webhookId = null;
        
        Test.startTest();
        // When & Then
        try {
            AdyenWebhookSetupController.saveWebhookDataToMetadata(hmacKey, webhookId);
            Assert.fail('Expected exception was not thrown');
        } catch (Exception e) {
            Assert.isInstanceOfType(e, AuraHandledException.class);
        }
        Test.stopTest();
    }

    @IsTest
    static void testWebhookSuccessTest() {
        // Given
        String webhookId = 'WBHK12345678912345678912345678';
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.WebhookTestMockResponse());
        
        Test.startTest();
        
        // When
        AdyenWebhookSetupController.WebhookTestResult result = AdyenWebhookSetupController.testWebhook(webhookId);
        
        Test.stopTest();
        
        // Then
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isTrue(result.isSuccess, 'Test should be successful');
        Assert.isNotNull(result.testResponse.data, 'Test response data should not be null');
        Assert.isTrue(result.testResponse.data.size() > 0, 'Test response data should contain items');
        Assert.areEqual('success', result.testResponse.data[0].status, 'Test response status should be success');
    }

    @IsTest
    static void testWebhookFailureTest() {
        // Given
        String webhookId = 'WBHK12345678912345678912345678';
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.WebhookTestFailureMockResponse());
        
        Test.startTest();
        
        // When
        AdyenWebhookSetupController.WebhookTestResult result = AdyenWebhookSetupController.testWebhook(webhookId);
        
        Test.stopTest();
        
        // Then
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isFalse(result.isSuccess, 'Test should fail');
        Assert.isNull(result.testResponse, 'Test response should be null on failure');
    }

    @IsTest
    static void testWebhookEmptyWebhookIdTest() {
        // Given
        String webhookId = '';
        
        Test.startTest();
        
        // When
        AdyenWebhookSetupController.WebhookTestResult result = AdyenWebhookSetupController.testWebhook(webhookId);
        
        Test.stopTest();
        
        // Then
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isFalse(result.isSuccess, 'Test should fail');
    }

    @IsTest
    static void testWebhookHttpFailureTest() {
        // Given
        String webhookId = 'WBHK12345678912345678912345678';
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.FailureResponse());
        
        Test.startTest();
        
        // When
        AdyenWebhookSetupController.WebhookTestResult result = AdyenWebhookSetupController.testWebhook(webhookId);
        
        Test.stopTest();
        
        // Then
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isFalse(result.isSuccess, 'Test should fail');
        Assert.isNotNull(result.errorMessage, 'Error message should not be null');
        Assert.isNull(result.testResponse, 'Test response should be null on failure');
    }

    @IsTest
    static void checkExistingWebhookTest() {

        // Given
        Adyen_Adapter__mdt adyenAdapter = [
            SELECT Webhook_ID__c 
            FROM Adyen_Adapter__mdt 
            WHERE DeveloperName = :AdyenConstants.DEFAULT_ADAPTER_NAME 
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new TestDataFactory.WebhookGetMockResponse());
        
        Test.startTest();
        
        // When
        AdyenWebhookSetupController.WebhookCheckResult result = AdyenWebhookSetupController.checkExistingWebhook();
        
        Test.stopTest();
        
        // Then
        Assert.isNotNull(result, 'Result should not be null');

        if (String.isBlank(adyenAdapter.Webhook_ID__c)) {
            Assert.isFalse(result.webhookExists, 'Webhook should not exist if ID is blank in metadata.');
            Assert.isNull(result.webhookId, 'Webhook ID in result should be null.');
        } else {
            Assert.isTrue(result.webhookExists, 'Webhook should exist if ID is present in metadata.');
        }
    }

    @IsTest
    static void checkExistingWebhookNotFoundTest() {
        // Given
        Adyen_Adapter__mdt adyenAdapter = [
            SELECT Webhook_ID__c 
            FROM Adyen_Adapter__mdt 
            WHERE DeveloperName = :AdyenConstants.DEFAULT_ADAPTER_NAME 
            LIMIT 1
        ];
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.NotFoundResponse());
        
        Test.startTest();

        // When & Then
        try {
            AdyenWebhookSetupController.WebhookCheckResult result = AdyenWebhookSetupController.checkExistingWebhook();
            if (String.isBlank(adyenAdapter.Webhook_ID__c)) {
                Assert.isFalse(result.webhookExists, 'Webhook should not exist if ID is blank in metadata.');
                Assert.isNull(result.webhookId, 'Webhook ID in result should be null.');
            } else {
                Assert.fail('Expected exception was not thrown');
            }
            
        } catch (Exception e) {
            Assert.isInstanceOfType(e, AuraHandledException.class);
        }
    }

    @IsTest(SeeAllData=true)
    static void updateWebhookSuccessTest() {
        // Given
        String description = 'Updated Test Webhook Description';
        List<String> eventCodes = new List<String>{'CAPTURE', 'REFUND', 'CANCELLATION'};
        String webhookId = 'WBHK12345678912345678912345678';
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.WebhookUpdateWithHmacMockResponse());
        
        Test.startTest();
        
        // When
        AdyenWebhookSetupController.WebhookSetupResult result = AdyenWebhookSetupController.updateWebhook(description, eventCodes, webhookId);
        
        Test.stopTest();
        
        // Then
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isTrue(result.isSuccess, 'Update should be successful');
        Assert.isNull(result.errorMessage, 'Error message should be null on success');
        Assert.isNotNull(result.webhookResponse, 'Webhook response should not be null');
        Assert.areEqual(webhookId, result.webhookId, 'Webhook ID should match');
    }

    @IsTest
    static void updateWebhookEmptyDescriptionTest() {
        // Given
        String description = '';
        List<String> eventCodes = new List<String>{'CAPTURE'};
        String webhookId = 'WBHK12345678912345678912345678';
        
        Test.startTest();
        
        // When
        AdyenWebhookSetupController.WebhookSetupResult result = AdyenWebhookSetupController.updateWebhook(description, eventCodes, webhookId);
        
        Test.stopTest();
        
        // Then
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isFalse(result.isSuccess, 'Update should fail with empty description');
        Assert.isNotNull(result.errorMessage, 'Error message should not be null');
    }

    @IsTest
    static void updateWebhookEmptyEventCodesTest() {
        // Given
        String description = 'Test Description';
        List<String> eventCodes = new List<String>();
        String webhookId = 'WBHK12345678912345678912345678';
        
        Test.startTest();
        
        // When
        AdyenWebhookSetupController.WebhookSetupResult result = AdyenWebhookSetupController.updateWebhook(description, eventCodes, webhookId);
        
        Test.stopTest();
        
        // Then
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isFalse(result.isSuccess, 'Update should fail with empty event codes');
        Assert.isNotNull(result.errorMessage, 'Error message should not be null');
    }

    @IsTest
    static void updateWebhookEmptyWebhookIdTest() {
        // Given
        String description = 'Test Description';
        List<String> eventCodes = new List<String>{'CAPTURE', 'REFUND'};
        String webhookId = '';
        
        // When & Then
        try {
            Test.startTest();

            AdyenWebhookSetupController.WebhookSetupResult result = AdyenWebhookSetupController.updateWebhook(description, eventCodes, webhookId);

            Test.stopTest();
            Assert.fail('Expected exception was not thrown');
        } catch (Exception e) {
            Assert.isInstanceOfType(e, AuraHandledException.class);
        }
    }

    @IsTest(SeeAllData=true)
    static void updateWebhookServiceExceptionTest() {
        // Given
        String description = 'Test Webhook Description';
        List<String> eventCodes = new List<String>{'CAPTURE', 'REFUND'};
        String webhookId = 'WBHK12345678912345678912345678';
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.FailureResponse());
        
        Test.startTest();
        
        // When
        AdyenWebhookSetupController.WebhookSetupResult result = AdyenWebhookSetupController.updateWebhook(description, eventCodes, webhookId);
        
        Test.stopTest();
        
        // Then
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isFalse(result.isSuccess, 'Update should fail when service throws exception');
        Assert.isNull(result.webhookResponse, 'Webhook response should be null on failure');
    }

}