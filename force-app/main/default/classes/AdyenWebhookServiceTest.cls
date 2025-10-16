@IsTest
private class AdyenWebhookServiceTest {
    
    private static AdyenWebhookService.WebhookContext createMerchantContext() {
        AdyenWebhookService.mockAdapter = new Adyen_Adapter__mdt(
            Merchant_Account__c = 'TestMerchant',
            Management_API_Named_Credential__c = 'TestCredential',
            Management_API_Version__c = 'v3',
            Management_API_Webhook_Endpoint__c = '/{merchantId}/webhooks',
            Management_API_Endpoint_Path__c = '/merchants',
            Package_Namespace__c = ''
        );
        return new AdyenWebhookService.WebhookContext(
            AdyenWebhookService.mockAdapter, 
            AdyenWebhookService.SETUP_TYPE_MERCHANT, 
            null
        );
    }
    
    private static AdyenWebhookService.WebhookContext createCompanyContext() {
        AdyenWebhookService.mockAdapter = new Adyen_Adapter__mdt(
            Merchant_Account__c = 'TestMerchant',
            Management_API_Named_Credential__c = 'TestCredential',
            Management_API_Version__c = 'v3',
            Management_API_Webhook_Endpoint__c = '/{merchantId}/webhooks',
            Management_API_Endpoint_Path__c = '/merchants',
            Package_Namespace__c = ''
        );
        return new AdyenWebhookService.WebhookContext(
            AdyenWebhookService.mockAdapter, 
            AdyenWebhookService.SETUP_TYPE_COMPANY, 
            'TestCompanyId'
        );
    }
    
    private static AdyenWebhookService.WebhookRequest createWebhookRequest() {
        String webhookUrl = 'https://testwebhook.com';
        List<String> eventCodes = new List<String>{'AUTHORISATION'};
        String description = 'Test webhook';
        return new AdyenWebhookService.WebhookRequest(webhookUrl, eventCodes, description);
    }

    @IsTest
    static void setupMerchantWebhookSuccessTest() {
        // Given
        AdyenWebhookService.WebhookContext context = createMerchantContext();
        AdyenWebhookService.WebhookRequest request = createWebhookRequest();
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.WebhookSetupMockResponse());

        Test.startTest();
        // When
        WebhookSetupResponse response = AdyenWebhookService.setupWebhook(context, request);
        Test.stopTest();

        // Then
        Assert.areNotEqual(response, null);
        Assert.areEqual(request.description, response.description);
    }

    @IsTest
    static void setupCompanyWebhookSuccessTest() {
        // Given
        AdyenWebhookService.WebhookContext context = createCompanyContext();
        AdyenWebhookService.WebhookRequest request = createWebhookRequest();
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.WebhookSetupMockResponse());

        Test.startTest();
        // When
        WebhookSetupResponse response = AdyenWebhookService.setupWebhook(context, request);
        Test.stopTest();

        // Then
        Assert.areNotEqual(response, null);
        Assert.areEqual(request.description, response.description);
    }

    @IsTest
    static void setupWebhookMissingContextTest() {
        // Given
        AdyenWebhookService.WebhookRequest request = createWebhookRequest();

        Test.startTest();
        try {
            // When
            AdyenWebhookService.setupWebhook(null, request);
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
        }
        Test.stopTest();
    }

    @IsTest
    static void setupWebhookMissingRequestTest() {
        // Given
        AdyenWebhookService.WebhookContext context = createMerchantContext();

        Test.startTest();
        try {
            // When
            AdyenWebhookService.setupWebhook(context, null);
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
        AdyenWebhookService.WebhookContext context = createMerchantContext();
        AdyenWebhookService.WebhookRequest request = createWebhookRequest();
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.FailureResponse());

        Test.startTest();
        try {
            // When
            AdyenWebhookService.setupWebhook(context, request);
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
        }
        Test.stopTest();
    }

    @IsTest
    static void updateWebhookMissingWebhookIdTest() {
        // Given
        AdyenWebhookService.WebhookContext context = createMerchantContext();
        AdyenWebhookService.WebhookRequest request = createWebhookRequest();

        Test.startTest();
        try {
            // When
            AdyenWebhookService.updateWebhook(context, null, request);
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
        }
        Test.stopTest();
    }

    @IsTest
    static void generateHmacKeyMerchantSuccessTest() {
        // Given
        AdyenWebhookService.WebhookContext context = createMerchantContext();
        String webhookId = 'test-webhook-id';
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.HmacGenerationMockResponse());

        Test.startTest();
        // When
        String result = AdyenWebhookService.generateHmacKey(context, webhookId);
        Test.stopTest();

        // Then
        Assert.isNotNull(result);
        Assert.isTrue(result.length() > 0);
    }

    @IsTest
    static void generateHmacKeyCompanySuccessTest() {
        // Given
        AdyenWebhookService.WebhookContext context = createCompanyContext();
        String webhookId = 'test-webhook-id';
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.HmacGenerationMockResponse());

        Test.startTest();
        // When
        String result = AdyenWebhookService.generateHmacKey(context, webhookId);
        Test.stopTest();

        // Then
        Assert.isNotNull(result);
        Assert.isTrue(result.length() > 0);
    }

    @IsTest
    static void generateHmacKeyMissingContextTest() {
        // Given
        String webhookId = 'test-webhook-id';

        Test.startTest();
        try {
            // When
            AdyenWebhookService.generateHmacKey(null, webhookId);
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
        }
        Test.stopTest();
    }

    @IsTest
    static void generateHmacKeyMissingWebhookIdTest() {
        // Given
        AdyenWebhookService.WebhookContext context = createMerchantContext();

        Test.startTest();
        try {
            // When
            AdyenWebhookService.generateHmacKey(context, null);
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
        }
        Test.stopTest();
    }

    @IsTest
    static void generateHmacKeyHttpFailureTest() {
        // Given
        AdyenWebhookService.WebhookContext context = createMerchantContext();
        String webhookId = 'test-webhook-id';
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.FailureResponse());

        Test.startTest();
        try {
            // When
            AdyenWebhookService.generateHmacKey(context, webhookId);
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
        }
        Test.stopTest();
    }

    @IsTest
    static void testMerchantWebhookSuccessTest() {
        // Given
        AdyenWebhookService.WebhookContext context = createMerchantContext();
        String webhookId = 'test-webhook-id';
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.WebhookTestMockResponse());

        Test.startTest();
        // When
        AdyenWebhookService.WebhookTestResponse result = AdyenWebhookService.testWebhook(context, webhookId);
        Test.stopTest();

        // Then
        Assert.isNotNull(result);
        Assert.isNotNull(result.data);
        Assert.isTrue(result.data.size() > 0);
        Assert.areEqual('success', result.data[0].status);
    }

    @IsTest
    static void testCompanyWebhookSuccessTest() {
        // Given
        AdyenWebhookService.WebhookContext context = createCompanyContext();
        String webhookId = 'test-webhook-id';
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.WebhookTestMockResponse());

        Test.startTest();
        // When
        AdyenWebhookService.WebhookTestResponse result = AdyenWebhookService.testWebhook(context, webhookId);
        Test.stopTest();

        // Then
        Assert.isNotNull(result);
        Assert.isNotNull(result.data);
        Assert.isTrue(result.data.size() > 0);
        Assert.areEqual('success', result.data[0].status);
    }

    @IsTest
    static void testWebhookFailureTest() {
        // Given
        AdyenWebhookService.WebhookContext context = createMerchantContext();
        String webhookId = 'test-webhook-id';
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.WebhookTestFailureMockResponse());

        Test.startTest();
        try {
            // When
            AdyenWebhookService.testWebhook(context, webhookId);
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
            Assert.isTrue(e.getMessage().contains('webhook test failed'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testWebhookMissingContextTest() {
        // Given
        Test.startTest();
        try {
            // When
            AdyenWebhookService.testWebhook(null, 'test-webhook-id');
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
        }
        Test.stopTest();
    }

    @IsTest
    static void testWebhookMissingWebhookIdTest() {
        // Given
        AdyenWebhookService.WebhookContext context = createMerchantContext();

        Test.startTest();
        try {
            // When
            AdyenWebhookService.testWebhook(context, null);
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
        }
        Test.stopTest();
    }

    @IsTest
    static void testWebhookHttpFailureTest() {
        // Given
        AdyenWebhookService.WebhookContext context = createMerchantContext();
        String webhookId = 'test-webhook-id';
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.FailureResponse());

        Test.startTest();
        try {
            // When
            AdyenWebhookService.testWebhook(context, webhookId);
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
        }
        Test.stopTest();
    }

    @IsTest
    static void getMerchantWebhookSuccessTest() {
        // Given
        AdyenWebhookService.WebhookContext context = createMerchantContext();
        String webhookId = 'test-webhook-id';
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.WebhookGetMockResponse());

        Test.startTest();
        // When
        WebhookSetupResponse result = AdyenWebhookService.getWebhook(context, webhookId);
        Test.stopTest();

        // Then
        Assert.isNotNull(result);
        Assert.areEqual('test-webhook-id', result.id);
        Assert.areEqual('Test webhook description', result.description);
    }
    
    @IsTest
    static void getCompanyWebhookSuccessTest() {
        // Given
        AdyenWebhookService.WebhookContext context = createCompanyContext();
        String webhookId = 'test-webhook-id';
        
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.WebhookGetMockResponse());

        Test.startTest();
        // When
        WebhookSetupResponse result = AdyenWebhookService.getWebhook(context, webhookId);
        Test.stopTest();

        // Then
        Assert.isNotNull(result);
        Assert.areEqual('test-webhook-id', result.id);
        Assert.areEqual('Test webhook description', result.description);
    }
    
    @IsTest
    static void getWebhookMissingParametersTest() {
        // Given
        AdyenWebhookService.WebhookContext context = createMerchantContext();
        
        Test.startTest();
        try {
            // When
            AdyenWebhookService.getWebhook(null, 'test-webhook-id');
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
        }

        try {
            // When
            AdyenWebhookService.getWebhook(context, null);
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
        }
        Test.stopTest();
    }

    @IsTest
    static void webhookContextMerchantTest() {
        // Given
        AdyenWebhookService.mockAdapter = new Adyen_Adapter__mdt(
            Merchant_Account__c = 'TestMerchant'
        );
        
        Test.startTest();
        // When
        AdyenWebhookService.WebhookContext context = new AdyenWebhookService.WebhookContext(
            AdyenWebhookService.mockAdapter, 
            AdyenWebhookService.SETUP_TYPE_MERCHANT, 
            null
        );
        Test.stopTest();
        
        // Then
        Assert.isFalse(context.isCompanyLevel());
        Assert.areEqual('TestMerchant', context.getAccountId());
        Assert.areEqual('merchant TestMerchant', context.getContextDescription());
    }

    @IsTest
    static void webhookContextCompanyTest() {
        // Given
        AdyenWebhookService.mockAdapter = new Adyen_Adapter__mdt(
            Merchant_Account__c = 'TestMerchant'
        );
        
        Test.startTest();
        // When
        AdyenWebhookService.WebhookContext context = new AdyenWebhookService.WebhookContext(
            AdyenWebhookService.mockAdapter, 
            AdyenWebhookService.SETUP_TYPE_COMPANY, 
            'TestCompanyId'
        );
        Test.stopTest();
        
        // Then
        Assert.isTrue(context.isCompanyLevel());
        Assert.areEqual('TestCompanyId', context.getAccountId());
        Assert.areEqual('company TestCompanyId', context.getContextDescription());
    }

    @IsTest
    static void webhookRequestValidationSuccessTest() {
        // Given
        AdyenWebhookService.WebhookRequest request = new AdyenWebhookService.WebhookRequest(
            'https://test.webhook.com',
            new List<String>{'AUTHORISATION'},
            'Test Description'
        );
        
        Test.startTest();
        try {
            // When
            request.validate();
        } catch (Exception e) {
            // Then
            Assert.fail('Validation should not throw exception for valid request');
        }
        Test.stopTest();
    }

    @IsTest
    static void webhookRequestValidationFailureTest() {
        Test.startTest();
        
        try {
            // Given
            AdyenWebhookService.WebhookRequest request = new AdyenWebhookService.WebhookRequest(
                null, new List<String>{'AUTHORISATION'}, 'Test'
            );
            // When
            request.validate();
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
        }

        try {
            // Given
            AdyenWebhookService.WebhookRequest request = new AdyenWebhookService.WebhookRequest(
                'https://test.com', new List<String>(), 'Test'
            );
            // When
            request.validate();
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            // Then
            Assert.isInstanceOfType(e, AdyenWebhookService.AdyenWebhookException.class);
        }
        
        Test.stopTest();
    }

    @IsTest
    static void processWebhookRequestCompanyLevelTest() {
        // Given
        AdyenWebhookService.WebhookContext companyContext = createCompanyContext();
        AdyenWebhookService.WebhookRequest request = createWebhookRequest();
        
        Test.setMock(HttpCalloutMock.class, new CompanyWebhookMockResponse());

        Test.startTest();
        // When
        WebhookSetupResponse result = AdyenWebhookService.setupWebhook(companyContext, request);
        Test.stopTest();

        // Then
        Assert.isNotNull(result);
    }
    
    private class CompanyWebhookMockResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String requestBody = req.getBody();
            Map<String, Object> requestMap = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
            
            Assert.isTrue(requestMap.containsKey('filterMerchantAccountType'), 
                'Company webhook request should contain filterMerchantAccountType');
            Assert.areEqual('allAccounts', requestMap.get('filterMerchantAccountType'),
                'filterMerchantAccountType should be set to allAccounts for company webhooks');
            
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"id":"test-webhook-id","description":"Test webhook","active":true}');
            return response;
        }
    }
}