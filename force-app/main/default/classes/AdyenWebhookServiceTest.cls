@IsTest
private class AdyenWebhookServiceTest {
    
    @IsTest
    static void setupWebhookSuccessTest() {
        // Given
        AdyenWebhookService.mockAdapter = new Adyen_Adapter__mdt(
            Merchant_Account__c = 'TestMerchant',
            Management_API_Named_Credential__c = 'TestCredential',
            Management_API_Version__c = 'v3',
            Management_API_Webhook_Endpoint__c = '/{merchantId}/webhooks',
            Management_API_Endpoint_Path__c = '/merchants',
            Package_Namespace__c = ''
        );

        String webhookUrl = 'https://testwebhook.com';
        List<String> eventCodes = new List<String>{'AUTHORISATION'};
        String description = 'Test webhook';

        Test.setMock(HttpCalloutMock.class, new TestDataFactory.WebhookSetupMockResponse());

        // When
        Test.startTest();
        WebhookSetupResponse response = AdyenWebhookService.setupWebhook(AdyenWebhookService.mockAdapter, webhookUrl, eventCodes, description);
        Test.stopTest();

        // Then
        Assert.areNotEqual(response, null);
        Assert.areEqual(description, response.description);
    }

    @IsTest
    static void setupWebhookMissingMerchantAccountTest() {
        // Given & When
        Test.startTest();
        try {
            AdyenWebhookService.setupWebhook(null, 'https://testwebhook.com', new List<String>{'AUTHORISATION'}, 'Test');
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
        }
        Test.stopTest();
    }

    @IsTest
    static void setupWebhookHttpFailureTest() {
        // Given
        AdyenWebhookService.mockAdapter = new Adyen_Adapter__mdt(
                Merchant_Account__c = 'TestMerchant',
                Management_API_Named_Credential__c = 'TestCredential',
                Management_API_Version__c = 'v3',
                Management_API_Webhook_Endpoint__c = '/{merchantId}/webhooks',
                Management_API_Endpoint_Path__c = '/merchants',
                Package_Namespace__c = ''
            );
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.FailureResponse());

        // When
        Test.startTest();
        try {
            AdyenWebhookService.setupWebhook(AdyenWebhookService.mockAdapter, 'https://testwebhook.com', new List<String>{'AUTHORISATION'}, 'Test');
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
        }
        Test.stopTest();
    }

    @IsTest
    static void generateHmacKeySuccessTest() {
        // Given
        AdyenWebhookService.mockAdapter = new Adyen_Adapter__mdt(
            Merchant_Account__c = 'TestMerchant',
            Management_API_Named_Credential__c = 'TestCredential',
            Management_API_Version__c = 'v3',
            Management_API_Webhook_Endpoint__c = '/{merchantId}/webhooks',
            Management_API_Endpoint_Path__c = '/merchants',
            Package_Namespace__c = ''
        );
        String webhookId = 'test-webhook-id';
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.HmacGenerationMockResponse());

        // When
        Test.startTest();
        String result = AdyenWebhookService.generateHmacKey(AdyenWebhookService.mockAdapter, webhookId);
        Test.stopTest();

        // Then
        Assert.isNotNull(result);
        Assert.isTrue(result.length() > 0);
    }

    @IsTest
    static void generateHmacKeyMissingMerchantAccountTest() {
        // Given
        AdyenWebhookService.mockAdapter = new Adyen_Adapter__mdt(
            Merchant_Account__c = null,
            Management_API_Named_Credential__c = 'TestCredential',
            Management_API_Version__c = 'v3',
            Management_API_Webhook_Endpoint__c = '/{merchantId}/webhooks',
            Management_API_Endpoint_Path__c = '/merchants',
            Package_Namespace__c = ''
        );
        String webhookId = 'test-webhook-id';

        // When
        Test.startTest();
        try {
            AdyenWebhookService.generateHmacKey(AdyenWebhookService.mockAdapter, webhookId);
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
            Assert.isTrue(e.getMessage().contains('Merchant Account is required for HMAC generation'));
        }
        Test.stopTest();
    }

    @IsTest
    static void generateHmacKeyMissingWebhookIdTest() {
        // Given
        AdyenWebhookService.mockAdapter = new Adyen_Adapter__mdt(
            Merchant_Account__c = 'TestMerchant',
            Management_API_Named_Credential__c = 'TestCredential',
            Management_API_Version__c = 'v3',
            Management_API_Webhook_Endpoint__c = '/{merchantId}/webhooks',
            Management_API_Endpoint_Path__c = '/merchants',
            Package_Namespace__c = ''
        );
        String webhookId = null;

        // When
        Test.startTest();
        try {
            AdyenWebhookService.generateHmacKey(AdyenWebhookService.mockAdapter, webhookId);
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
            Assert.isTrue(e.getMessage().contains('Webhook ID is required for HMAC generation'));
        }
        Test.stopTest();
    }

    @IsTest
    static void generateHmacKeyHttpFailureTest() {
        // Given
        AdyenWebhookService.mockAdapter = new Adyen_Adapter__mdt(
            Merchant_Account__c = 'TestMerchant',
            Management_API_Named_Credential__c = 'TestCredential',
            Management_API_Version__c = 'v3',
            Management_API_Webhook_Endpoint__c = '/{merchantId}/webhooks',
            Management_API_Endpoint_Path__c = '/merchants',
            Package_Namespace__c = ''
        );
        String webhookId = 'test-webhook-id';
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.FailureResponse());

        // When
        Test.startTest();
        try {
            AdyenWebhookService.generateHmacKey(AdyenWebhookService.mockAdapter, webhookId);
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
        }
        Test.stopTest();
    }
}