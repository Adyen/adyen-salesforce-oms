public with sharing class AdyenWebhookService {
    private static final String DEFAULT_COMMUNICATION_FORMAT = 'json';
    private static final String DEFAULT_ENCRYPTION_PROTOCOL = 'TLSv1.3';
    private static final String DEFAULT_WEBHOOK_TYPE = 'standard';
    
    @TestVisible
    private static Adyen_Adapter__mdt mockAdapter;

    public static WebhookSetupResponse setupWebhook(Adyen_Adapter__mdt adyenAdapter, String webhookUrl, List<String> eventCodes, String description) {
        if (adyenAdapter == null || String.isBlank(adyenAdapter.Merchant_Account__c)) {
            throw new AdyenWebhookException('Merchant Account is required');
        }
        if (String.isBlank(webhookUrl)) {
            throw new AdyenWebhookException('Webhook URL is required');
        }
        if (eventCodes == null || eventCodes.isEmpty()) {
            throw new AdyenWebhookException('At least one event code must be specified');
        }
        try {
            WebhookSetupRequest webhookRequest = buildWebhookRequest(webhookUrl, description, eventCodes, true);
            String requestBody = JSON.serialize(webhookRequest, true);
            String endpoint = buildWebhookEndpoint(adyenAdapter);
            HttpResponse response = AdyenManagementAPIService.makeHttpRequest('POST', endpoint, requestBody);
            
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                String errorMessage = AdyenManagementAPIService.parseErrorMessage(response);
                throw new AdyenWebhookException(errorMessage);
            }
            
            return (WebhookSetupResponse) JSON.deserialize(response.getBody(), WebhookSetupResponse.class);
        } catch (AdyenWebhookException e) {
            throw e;
        } catch (Exception e) {
            throw new AdyenWebhookException('Error setting up webhook: ' + e.getMessage());
        }
    }

    public static String generateHmacKey(Adyen_Adapter__mdt adyenAdapter, String webhookId) {
        if (adyenAdapter == null || String.isBlank(adyenAdapter.Merchant_Account__c)) {
            throw new AdyenWebhookException('Merchant Account is required for HMAC generation');
        }
        if (String.isBlank(webhookId)) {
            throw new AdyenWebhookException('Webhook ID is required for HMAC generation');
        }
        
        try {
            String endpoint = buildHmacGenerationEndpoint(adyenAdapter, webhookId);
            HttpResponse response = AdyenManagementAPIService.makeHttpRequest('POST', endpoint, '{}');
            
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                String errorMessage = AdyenManagementAPIService.parseErrorMessage(response);
                throw new AdyenWebhookException('HMAC generation failed: ' + errorMessage);
            }
            
            HmacGenerationResponse hmacResponse = (HmacGenerationResponse) JSON.deserialize(response.getBody(), HmacGenerationResponse.class);
            return hmacResponse.hmacKey;
        } catch (AdyenWebhookException e) {
            throw e;
        } catch (Exception e) {
            throw new AdyenWebhookException('Error generating HMAC key: ' + e.getMessage());
        }
    }

    public static WebhookTestResponse testWebhook(Adyen_Adapter__mdt adyenAdapter, String webhookId) {
        if (adyenAdapter == null || String.isBlank(adyenAdapter.Merchant_Account__c)) {
            throw new AdyenWebhookException('Merchant Account is required for webhook testing');
        }
        if (String.isBlank(webhookId)) {
            throw new AdyenWebhookException('Webhook ID is required for webhook testing');
        }
        
        try {
            String endpoint = buildWebhookTestEndpoint(adyenAdapter, webhookId);
            String requestBody = buildWebhookTestRequest();
            HttpResponse response = AdyenManagementAPIService.makeHttpRequest('POST', endpoint, requestBody);
            
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                String errorMessage = AdyenManagementAPIService.parseErrorMessage(response);
                throw new AdyenWebhookException('Webhook test failed: ' + errorMessage);
            }
            
            WebhookTestResponse testResponse = (WebhookTestResponse) JSON.deserialize(response.getBody(), WebhookTestResponse.class);
            
            if (testResponse.data != null) {
                for (TestNotificationItem item : testResponse.data) {
                    if (item.status != null && item.status.toLowerCase() == 'failed') {
                        throw new AdyenWebhookException('Webhook test failed: ' + 
                            (String.isNotBlank(item.output) ? item.output : 'Test notification was not successfully delivered'));
                    }
                }
            }
            
            return testResponse;
        } catch (AdyenWebhookException e) {
            throw e;
        } catch (Exception e) {
            throw new AdyenWebhookException('Error testing webhook: ' + e.getMessage());
        }
    }

    public static WebhookSetupResponse getWebhook(Adyen_Adapter__mdt adyenAdapter, String webhookId) {
        if (adyenAdapter == null || String.isBlank(adyenAdapter.Merchant_Account__c)) {
            throw new AdyenWebhookException('Merchant Account is required for webhook retrieval');
        }
        if (String.isBlank(webhookId)) {
            throw new AdyenWebhookException('Webhook ID is required for webhook retrieval');
        }
        
        try {
            String endpoint = buildWebhookRetrievalEndpoint(adyenAdapter, webhookId);
            HttpResponse response = AdyenManagementAPIService.makeHttpRequest('GET', endpoint, null);
            
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                String errorMessage = AdyenManagementAPIService.parseErrorMessage(response);
                throw new AdyenWebhookException('Failed to retrieve webhook: ' + errorMessage);
            }
            
            return (WebhookSetupResponse) JSON.deserialize(response.getBody(), WebhookSetupResponse.class);
        } catch (AdyenWebhookException e) {
            throw e;
        } catch (Exception e) {
            throw new AdyenWebhookException('Error retrieving webhook: ' + e.getMessage());
        }
    }

    public static WebhookSetupResponse updateWebhook(Adyen_Adapter__mdt adyenAdapter, String webhookId, String webhookUrl, List<String> eventCodes, String description) {
        if (adyenAdapter == null || String.isBlank(adyenAdapter.Merchant_Account__c)) {
            throw new AdyenWebhookException('Merchant Account is required');
        }
        if (String.isBlank(webhookId)) {
            throw new AdyenWebhookException('Webhook ID is required for webhook update');
        }
        if (String.isBlank(webhookUrl)) {
            throw new AdyenWebhookException('Webhook URL is required');
        }
        if (eventCodes == null || eventCodes.isEmpty()) {
            throw new AdyenWebhookException('At least one event code must be specified');
        }
        
        try {
            WebhookSetupRequest webhookRequest = buildWebhookRequest(webhookUrl, description, eventCodes, false);
            String requestBody = JSON.serialize(webhookRequest, true);
            String endpoint = buildWebhookUpdateEndpoint(adyenAdapter, webhookId);
            HttpResponse response = AdyenManagementAPIService.makeHttpRequest('PATCH', endpoint, requestBody);
            
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                String errorMessage = AdyenManagementAPIService.parseErrorMessage(response);
                throw new AdyenWebhookException(errorMessage);
            }
            
            return (WebhookSetupResponse) JSON.deserialize(response.getBody(), WebhookSetupResponse.class);
        } catch (AdyenWebhookException e) {
            throw e;
        } catch (Exception e) {
            throw new AdyenWebhookException('Error updating webhook: ' + e.getMessage());
        }
    }

    private static WebhookSetupRequest buildWebhookRequest(String webhookUrl, String description, List<String> eventCodes, Boolean isCreate) {
        WebhookSetupRequest webhookRequest = new WebhookSetupRequest();
        webhookRequest.url = webhookUrl;
        webhookRequest.active = true;
        webhookRequest.communicationFormat = DEFAULT_COMMUNICATION_FORMAT;
        webhookRequest.encryptionProtocol = DEFAULT_ENCRYPTION_PROTOCOL;
    
        if (isCreate) {
            webhookRequest.type = DEFAULT_WEBHOOK_TYPE;
        }
        
        if (String.isNotBlank(description)) {
            webhookRequest.description = description;
        }
        webhookRequest.additionalSettings = new WebhookSetupRequest.AdditionalSettings();
        webhookRequest.additionalSettings.includeEventCodes = eventCodes;

        return webhookRequest;
    }

    private static String buildWebhookEndpoint(Adyen_Adapter__mdt adyenAdapter) {
        adyenAdapter = validateAdapterFields(adyenAdapter);
        String namespace = String.isNotBlank(adyenAdapter.Package_Namespace__c) ? adyenAdapter.Package_Namespace__c + '__' : '';
        String baseUrl = 'callout:' + namespace + adyenAdapter.Management_API_Named_Credential__c;
        return String.format('{0}{1}{2}{3}', new List<String>{
            baseUrl,
            adyenAdapter.Management_API_Version__c,
            adyenAdapter.Management_API_Endpoint_Path__c,
            adyenAdapter.Management_API_Webhook_Endpoint__c.replace('{merchantId}', adyenAdapter.Merchant_Account__c)
        });
    }
    
    private static String buildHmacGenerationEndpoint(Adyen_Adapter__mdt adyenAdapter, String webhookId) {
        adyenAdapter = validateAdapterFields(adyenAdapter);
        String namespace = String.isNotBlank(adyenAdapter.Package_Namespace__c) ? adyenAdapter.Package_Namespace__c + '__' : '';
        String baseUrl = 'callout:' + namespace + adyenAdapter.Management_API_Named_Credential__c;
        String safeWebhookId = String.escapeSingleQuotes(webhookId);
        return String.format('{0}{1}{2}{3}/{4}/generateHmac', new List<String>{
            baseUrl,
            adyenAdapter.Management_API_Version__c,
            adyenAdapter.Management_API_Endpoint_Path__c,
            adyenAdapter.Management_API_Webhook_Endpoint__c.replace('{merchantId}', adyenAdapter.Merchant_Account__c),
            safeWebhookId
        });
    }

    private static String buildWebhookTestEndpoint(Adyen_Adapter__mdt adyenAdapter, String webhookId) {
        adyenAdapter = validateAdapterFields(adyenAdapter);
        String namespace = String.isNotBlank(adyenAdapter.Package_Namespace__c) ? adyenAdapter.Package_Namespace__c + '__' : '';
        String baseUrl = 'callout:' + namespace + adyenAdapter.Management_API_Named_Credential__c;
        String safeWebhookId = String.escapeSingleQuotes(webhookId);
        return String.format('{0}{1}{2}{3}/{4}/test', new List<String>{
            baseUrl,
            adyenAdapter.Management_API_Version__c,
            adyenAdapter.Management_API_Endpoint_Path__c,
            adyenAdapter.Management_API_Webhook_Endpoint__c.replace('{merchantId}', adyenAdapter.Merchant_Account__c),
            safeWebhookId
        });
    }

    private static String buildWebhookRetrievalEndpoint(Adyen_Adapter__mdt adyenAdapter, String webhookId) {
        adyenAdapter = validateAdapterFields(adyenAdapter);
        String namespace = String.isNotBlank(adyenAdapter.Package_Namespace__c) ? adyenAdapter.Package_Namespace__c + '__' : '';
        String baseUrl = 'callout:' + namespace + adyenAdapter.Management_API_Named_Credential__c;
        String safeWebhookId = String.escapeSingleQuotes(webhookId);
        return String.format('{0}{1}{2}{3}/{4}', new List<String>{
            baseUrl,
            adyenAdapter.Management_API_Version__c,
            adyenAdapter.Management_API_Endpoint_Path__c,
            adyenAdapter.Management_API_Webhook_Endpoint__c.replace('{merchantId}', adyenAdapter.Merchant_Account__c),
            safeWebhookId
        });
    }

    private static String buildWebhookUpdateEndpoint(Adyen_Adapter__mdt adyenAdapter, String webhookId) {
        adyenAdapter = validateAdapterFields(adyenAdapter);
        String namespace = String.isNotBlank(adyenAdapter.Package_Namespace__c) ? adyenAdapter.Package_Namespace__c + '__' : '';
        String baseUrl = 'callout:' + namespace + adyenAdapter.Management_API_Named_Credential__c;
        String safeWebhookId = String.escapeSingleQuotes(webhookId);
        return String.format('{0}{1}{2}{3}/{4}', new List<String>{
            baseUrl,
            adyenAdapter.Management_API_Version__c,
            adyenAdapter.Management_API_Endpoint_Path__c,
            adyenAdapter.Management_API_Webhook_Endpoint__c.replace('{merchantId}', adyenAdapter.Merchant_Account__c),
            safeWebhookId
        });
    }

    private static String buildWebhookTestRequest() {
        WebhookTestRequest testRequest = new WebhookTestRequest();
        testRequest.notification = new TestNotification();
        testRequest.notification.paymentMethod = 'visa';
        testRequest.notification.eventCode = 'CAPTURE';
        testRequest.notification.amount = new TestAmount();
        testRequest.notification.amount.currency_x = 'EUR';
        testRequest.notification.amount.value = 1000;
        testRequest.notification.reason = '';
        testRequest.notification.success = true;
        testRequest.types = new List<String>{'CUSTOM'};
        
        String jsonRequest = JSON.serialize(testRequest, true);
        return AdyenPaymentUtility.makeAdyenCompatible(jsonRequest);
    }

    private static Adyen_Adapter__mdt validateAdapterFields(Adyen_Adapter__mdt adyenAdapter) {
        if (Test.isRunningTest() && mockAdapter != null) {
            adyenAdapter = mockAdapter;
        }
        if (String.isBlank(adyenAdapter.Management_API_Named_Credential__c)) {
            throw new AdyenWebhookException('Management API Named Credential field is not configured');
        }
        if (String.isBlank(adyenAdapter.Management_API_Version__c)) {
            throw new AdyenWebhookException('Management API Version field is not configured');
        }
        if (String.isBlank(adyenAdapter.Management_API_Webhook_Endpoint__c)) {
            throw new AdyenWebhookException('Management API Endpoint field is not configured');
        }
        return adyenAdapter;
    }

    public class AdyenWebhookException extends Exception {}
    
    public class HmacGenerationResponse {
        public String hmacKey { get; set; }
    }

    public class WebhookTestResponse {
        public String status { get; set; }
        public List<TestNotificationItem> data { get; set; }
    }

    public class TestNotificationItem {
        public String merchantId { get; set; }
        public String output { get; set; }
        public String requestSent { get; set; }
        public String responseCode { get; set; }
        public String responseTime { get; set; }
        public String status { get; set; }
    }

    public class WebhookTestRequest {
        public TestNotification notification { get; set; }
        public List<String> types { get; set; }
    }

    public class TestNotification {
        public String paymentMethod { get; set; }
        public String eventCode { get; set; }
        public TestAmount amount { get; set; }
        public String reason { get; set; }
        public Boolean success { get; set; }
    }

    public class TestAmount {
        public String currency_x { get; set; }
        public Integer value { get; set; }
    }
}