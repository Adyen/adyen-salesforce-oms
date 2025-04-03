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
            WebhookSetupRequest webhookRequest = buildWebhookRequest(webhookUrl, description);
            String requestBody = JSON.serialize(webhookRequest, true);
            String endpoint = buildEndpoint(adyenAdapter);
            String responseBody = makeHttpRequest('POST', endpoint, requestBody);
            return (WebhookSetupResponse) JSON.deserialize(responseBody, WebhookSetupResponse.class);
        } catch (Exception e) {
            throw new AdyenWebhookException('Error setting up webhook: ' + e.getMessage());
        }
    }

    private static WebhookSetupRequest buildWebhookRequest(String webhookUrl, String description) {
        WebhookSetupRequest webhookRequest = new WebhookSetupRequest();
        webhookRequest.url = webhookUrl;
        webhookRequest.active = false;
        webhookRequest.communicationFormat = DEFAULT_COMMUNICATION_FORMAT;
        webhookRequest.encryptionProtocol = DEFAULT_ENCRYPTION_PROTOCOL;
        webhookRequest.type = DEFAULT_WEBHOOK_TYPE;
        if (String.isNotBlank(description)) {
            webhookRequest.description = description;
        }
        return webhookRequest;
    }

    private static String buildEndpoint(Adyen_Adapter__mdt adyenAdapter) {
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

    private static String makeHttpRequest(String method, String endpoint, String requestBody) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod(method);
        request.setHeader('Content-Type', 'application/json');
        if (method != 'GET' && String.isNotBlank(requestBody)) {
            request.setBody(requestBody);
        }
        HttpResponse response = http.send(request);
        if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
            return response.getBody();
        } else {
            throw new AdyenWebhookException('HTTP error: ' + response.getStatusCode() + ' ' + response.getStatus() + ', Body: ' + response.getBody());
        }
    }
    
    public class AdyenWebhookException extends Exception {}
}
