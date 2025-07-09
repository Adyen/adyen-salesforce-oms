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
            WebhookSetupRequest webhookRequest = buildWebhookRequest(webhookUrl, description, eventCodes);
            String requestBody = JSON.serialize(webhookRequest, true);
            String endpoint = buildWebhookEndpoint(adyenAdapter);
            HttpResponse response = AdyenManagementAPIService.makeHttpRequest('POST', endpoint, requestBody);
            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                return (WebhookSetupResponse) JSON.deserialize(response.getBody(), WebhookSetupResponse.class);
            } else {
                String errorMessage = AdyenManagementAPIService.parseErrorMessage(response);
                throw new AdyenWebhookException(errorMessage);
            }
        } catch (Exception e) {
            if (e instanceof AdyenWebhookException) {
                throw e;
            }
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
            
            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                HmacGenerationResponse hmacResponse = (HmacGenerationResponse) JSON.deserialize(response.getBody(), HmacGenerationResponse.class);
                return hmacResponse.hmacKey;
            } else {
                String errorMessage = AdyenManagementAPIService.parseErrorMessage(response);
                throw new AdyenWebhookException('HMAC generation failed: ' + errorMessage);
            }
        } catch (Exception e) {
            if (e instanceof AdyenWebhookException) {
                throw e;
            }
            throw new AdyenWebhookException('Error generating HMAC key: ' + e.getMessage());
        }
    }

    private static WebhookSetupRequest buildWebhookRequest(String webhookUrl, String description, List<String> eventCodes) {
        WebhookSetupRequest webhookRequest = new WebhookSetupRequest();
        webhookRequest.url = webhookUrl;
        webhookRequest.active = true;
        webhookRequest.communicationFormat = DEFAULT_COMMUNICATION_FORMAT;
        webhookRequest.encryptionProtocol = DEFAULT_ENCRYPTION_PROTOCOL;
        webhookRequest.type = DEFAULT_WEBHOOK_TYPE;
        if (String.isNotBlank(description)) {
            webhookRequest.description = description;
        }
        webhookRequest.additionalSettings = new WebhookSetupRequest.AdditionalSettings();
        webhookRequest.additionalSettings.includeEventCodes = eventCodes;

        return webhookRequest;
    }

    private static String buildWebhookEndpoint(Adyen_Adapter__mdt adyenAdapter) {
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
        
        String namespace = String.isNotBlank(adyenAdapter.Package_Namespace__c) ? adyenAdapter.Package_Namespace__c + '__' : '';
        String baseUrl = 'callout:' + namespace + adyenAdapter.Management_API_Named_Credential__c;
        return String.format('{0}{1}{2}{3}/{4}/generateHmac', new List<String>{
            baseUrl,
            adyenAdapter.Management_API_Version__c,
            adyenAdapter.Management_API_Endpoint_Path__c,
            adyenAdapter.Management_API_Webhook_Endpoint__c.replace('{merchantId}', adyenAdapter.Merchant_Account__c),
            webhookId
        });
    }

    public class AdyenWebhookException extends Exception {}
    
    public class HmacGenerationResponse {
        public String hmacKey { get; set; }
    }
}