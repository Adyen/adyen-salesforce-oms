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
    static void saveHmacToMetadataSuccessTest() {
        // Given
        String hmacKey = 'test-hmac-key-123456789';
        
        Test.startTest();
        // When
        String deploymentId = AdyenWebhookSetupController.saveHmacToMetadata(hmacKey);
        Test.stopTest();
        
        // Then
        Assert.areNotEqual(null, deploymentId, 'Deployment ID should not be null');
    }

    @IsTest
    static void saveHmacToMetadataNullKeyTest() {
        // Given
        String hmacKey = null;
        
        Test.startTest();
        // When
        try {
            AdyenWebhookSetupController.saveHmacToMetadata(hmacKey);
            Assert.fail('Expected exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AuraHandledException.class);
        }
        Test.stopTest();
    }
}