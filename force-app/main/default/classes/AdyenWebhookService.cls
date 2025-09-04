public with sharing class AdyenWebhookService {
    private static final String DEFAULT_COMMUNICATION_FORMAT = 'json';
    private static final String DEFAULT_ENCRYPTION_PROTOCOL = 'TLSv1.3';
    private static final String DEFAULT_WEBHOOK_TYPE = 'standard';
    public static final String SETUP_TYPE_COMPANY = 'company';
    public static final String SETUP_TYPE_MERCHANT = 'merchant';
    public static final String FILTER_ALL_ACCOUNTS = 'allAccounts';

    @TestVisible
    private static Adyen_Adapter__mdt mockAdapter;

    public class WebhookContext {
        public String setupType { get; set; }
        public String companyId { get; set; }
        public String merchantAccountId { get; set; }
        public Adyen_Adapter__mdt adapter { get; set; }

        public WebhookContext(Adyen_Adapter__mdt adapter, String setupType, String accountId) {
            this.adapter = adapter;
            this.setupType = setupType;
            if (SETUP_TYPE_COMPANY.equals(setupType)) {
                this.companyId = accountId;
            } else {
                this.merchantAccountId = accountId != null ? accountId : adapter?.Merchant_Account__c;
                this.setupType = SETUP_TYPE_MERCHANT;
            }
        }

        public Boolean isCompanyLevel() {
            return SETUP_TYPE_COMPANY.equals(this.setupType);
        }

        public String getAccountId() {
            return isCompanyLevel() ? this.companyId : this.merchantAccountId;
        }

        public String getContextDescription() {
            return isCompanyLevel() ? 'company ' + this.companyId : 'merchant ' + this.merchantAccountId;
        }
    }

    public static WebhookSetupResponse setupWebhook(WebhookContext context, WebhookRequest request) {
        validateInputs(context, request, null);
        return processWebhookRequest(context, null, request, true);
    }

    public static WebhookSetupResponse updateWebhook(WebhookContext context, String webhookId, WebhookRequest request) {
        if (String.isBlank(webhookId)) {
            throw new AdyenWebhookException('Webhook ID is required for webhook update.');
        }
        validateInputs(context, request, webhookId);
        return processWebhookRequest(context, webhookId, request, false);
    }

    public static WebhookSetupResponse getWebhook(WebhookContext context, String webhookId) {
        validateBasicInputs(context, webhookId);
        return executeGetWebhook(context, webhookId);
    }

    public static String generateHmacKey(WebhookContext context, String webhookId) {
        validateBasicInputs(context, webhookId);
        return executeHmacGeneration(context, webhookId);
    }

    public static WebhookTestResponse testWebhook(WebhookContext context, String webhookId) {
        validateBasicInputs(context, webhookId);
        return executeWebhookTest(context, webhookId);
    }

    private static WebhookSetupResponse processWebhookRequest(WebhookContext context, String webhookId, WebhookRequest request, Boolean isCreate) {
        String endpoint = buildWebhookEndpoint(context, webhookId, null);
        WebhookSetupRequest webhookSetupRequest = buildWebhookSetupRequest(request, isCreate);
        String requestBody = JSON.serialize(webhookSetupRequest, true);
        
        if (context.isCompanyLevel()) {
            requestBody = addFilterMerchantAccountTypeToJson(requestBody);
        }
        
        String httpMethod = isCreate ? 'POST' : 'PATCH';
        String operation = isCreate ? 'setting up' : 'updating';
        String errorPrefix = 'Error ' + operation + ' ' + context.getContextDescription() + ' webhook: ';
        
        return executeWebhookOperation(httpMethod, endpoint, requestBody, errorPrefix);
    }

    private static WebhookSetupResponse executeGetWebhook(WebhookContext context, String webhookId) {
        try {
            String endpoint = buildWebhookEndpoint(context, webhookId, null);
            HttpResponse response = AdyenManagementAPIService.makeHttpRequest('GET', endpoint, null);
            
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                String errorMessage = AdyenManagementAPIService.parseErrorMessage(response);
                throw new AdyenWebhookException('Failed to retrieve ' + context.getContextDescription() + ' webhook: ' + errorMessage);
            }
            
            return (WebhookSetupResponse) JSON.deserialize(response.getBody(), WebhookSetupResponse.class);
        } catch (AdyenWebhookException e) {
            throw e;
        } catch (Exception e) {
            throw new AdyenWebhookException('Error retrieving ' + context.getContextDescription() + ' webhook: ' + e.getMessage());
        }
    }

    private static String executeHmacGeneration(WebhookContext context, String webhookId) {
        try {
            String endpoint = buildWebhookEndpoint(context, webhookId, '/generateHmac');
            HttpResponse response = AdyenManagementAPIService.makeHttpRequest('POST', endpoint, '{}');
            
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                String errorMessage = AdyenManagementAPIService.parseErrorMessage(response);
                throw new AdyenWebhookException('HMAC generation failed for ' + context.getContextDescription() + ': ' + errorMessage);
            }
            
            HmacGenerationResponse hmacResponse = (HmacGenerationResponse) JSON.deserialize(response.getBody(), HmacGenerationResponse.class);
            return hmacResponse.hmacKey;
        } catch (AdyenWebhookException e) {
            throw e;
        } catch (Exception e) {
            throw new AdyenWebhookException('Error generating HMAC key for ' + context.getContextDescription() + ': ' + e.getMessage());
        }
    }

    private static WebhookTestResponse executeWebhookTest(WebhookContext context, String webhookId) {
        try {
            String endpoint = buildWebhookEndpoint(context, webhookId, '/test');
            String requestBody = buildWebhookTestRequest();
            HttpResponse response = AdyenManagementAPIService.makeHttpRequest('POST', endpoint, requestBody);
            
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                String errorMessage = AdyenManagementAPIService.parseErrorMessage(response);
                throw new AdyenWebhookException(context.getContextDescription() + ' webhook test failed: ' + errorMessage);
            }
            
            WebhookTestResponse testResponse = (WebhookTestResponse) JSON.deserialize(response.getBody(), WebhookTestResponse.class);
            
            if (testResponse.data != null) {
                for (TestNotificationItem item : testResponse.data) {
                    if (item.status != null && item.status.toLowerCase() == 'failed') {
                        throw new AdyenWebhookException(context.getContextDescription() + ' webhook test failed: ' + 
                            (String.isNotBlank(item.output) ? item.output : 'Test notification was not successfully delivered'));
                    }
                }
            }
            
            return testResponse;
        } catch (AdyenWebhookException e) {
            throw e;
        } catch (Exception e) {
            throw new AdyenWebhookException('Error testing ' + context.getContextDescription() + ' webhook: ' + e.getMessage());
        }
    }

    private static String buildWebhookEndpoint(WebhookContext context, String webhookId, String suffix) {
        if (context.isCompanyLevel()) {
            return buildCompanyWebhookApiEndpoint(context.adapter, context.companyId, webhookId, suffix);
        } else {
            return buildMerchantWebhookApiEndpoint(context.adapter, webhookId, suffix);
        }
    }

    private static WebhookSetupResponse executeWebhookOperation(String httpMethod, String endpoint, String requestBody, String errorMessagePrefix) {
        try {
            HttpResponse response = AdyenManagementAPIService.makeHttpRequest(httpMethod, endpoint, requestBody);
            
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                String errorMessage = AdyenManagementAPIService.parseErrorMessage(response);
                throw new AdyenWebhookException(errorMessage);
            }
            
            return (WebhookSetupResponse) JSON.deserialize(response.getBody(), WebhookSetupResponse.class);
        } catch (AdyenWebhookException e) {
            throw e;
        } catch (Exception e) {
            throw new AdyenWebhookException(errorMessagePrefix + e.getMessage());
        }
    }

    private static void validateInputs(WebhookContext context, WebhookRequest request, String webhookId) {
        validateBasicInputs(context, webhookId);
        if (request != null) {
            request.validate();
        } else {
            throw new AdyenWebhookException('Webhook request data is required');
        }
    }

    private static void validateBasicInputs(WebhookContext context, String webhookId) {
        if (context == null || context.adapter == null) {
            throw new AdyenWebhookException('Webhook context and adapter are required');
        }
        
        if (String.isBlank(context.getAccountId())) {
            throw new AdyenWebhookException((context.isCompanyLevel() ? 'Company ID' : 'Merchant Account') + ' is required');
        }
    }

    private static String buildMerchantWebhookApiEndpoint(Adyen_Adapter__mdt adyenAdapter, String webhookId, String suffix) {
        adyenAdapter = validateAdapterFields(adyenAdapter);
        String namespace = String.isNotBlank(adyenAdapter.Package_Namespace__c) ? adyenAdapter.Package_Namespace__c + '__' : '';
        String baseUrl = 'callout:' + namespace + adyenAdapter.Management_API_Named_Credential__c;
        
        String endpoint = String.format('{0}{1}{2}{3}', new List<String>{
            baseUrl,
            adyenAdapter.Management_API_Version__c,
            adyenAdapter.Management_API_Endpoint_Path__c,
            adyenAdapter.Management_API_Webhook_Endpoint__c.replace('{merchantId}', adyenAdapter.Merchant_Account__c)
        });

        if (String.isNotBlank(webhookId)) {
            endpoint += '/' + String.escapeSingleQuotes(webhookId);
        }

        if (String.isNotBlank(suffix)) {
            endpoint += suffix;
        }
        
        return endpoint;
    }

    private static String buildCompanyWebhookApiEndpoint(Adyen_Adapter__mdt adyenAdapter, String companyId, String webhookId, String suffix) {
        adyenAdapter = validateAdapterFields(adyenAdapter);
        String namespace = String.isNotBlank(adyenAdapter.Package_Namespace__c) ? adyenAdapter.Package_Namespace__c + '__' : '';
        String baseUrl = 'callout:' + namespace + adyenAdapter.Management_API_Named_Credential__c;
        
        String endpoint = String.format('{0}{1}/companies/{2}/webhooks', new List<String>{
            baseUrl,
            adyenAdapter.Management_API_Version__c,
            String.escapeSingleQuotes(companyId)
        });

        if (String.isNotBlank(webhookId)) {
            endpoint += '/' + String.escapeSingleQuotes(webhookId);
        }

        if (String.isNotBlank(suffix)) {
            endpoint += suffix;
        }
        
        return endpoint;
    }

    private static WebhookSetupRequest buildWebhookSetupRequest(WebhookRequest request, Boolean isCreate) {
        WebhookSetupRequest webhookSetupRequest = new WebhookSetupRequest();
        webhookSetupRequest.url = request.webhookUrl;
        webhookSetupRequest.active = true;
        webhookSetupRequest.communicationFormat = DEFAULT_COMMUNICATION_FORMAT;
        webhookSetupRequest.encryptionProtocol = DEFAULT_ENCRYPTION_PROTOCOL;
        
        if (isCreate) {
            webhookSetupRequest.type = DEFAULT_WEBHOOK_TYPE;
        }
        if (String.isNotBlank(request.description)) {
            webhookSetupRequest.description = request.description;
        }
        
        webhookSetupRequest.additionalSettings = new WebhookSetupRequest.AdditionalSettings();
        webhookSetupRequest.additionalSettings.includeEventCodes = request.eventCodes;

        return webhookSetupRequest;
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
    
    private static String addFilterMerchantAccountTypeToJson(String jsonString) {
        Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
        jsonMap.put('filterMerchantAccountType', FILTER_ALL_ACCOUNTS);
        return JSON.serialize(jsonMap);
    }

    public class WebhookRequest {
        @AuraEnabled
        public String webhookUrl { get; set; }
        
        @AuraEnabled
        public List<String> eventCodes { get; set; }
        
        @AuraEnabled
        public String description { get; set; }

        public WebhookRequest(String webhookUrl, List<String> eventCodes, String description) {
            this.webhookUrl = webhookUrl;
            this.eventCodes = eventCodes;
            this.description = description;
        }

        public void validate() {
            if (String.isBlank(this.webhookUrl)) {
                throw new AdyenWebhookException('Webhook URL is required');
            }
            if (this.eventCodes == null || this.eventCodes.isEmpty()) {
                throw new AdyenWebhookException('At least one event code must be specified');
            }
            if (String.isBlank(description)) {
                throw new AdyenWebhookException('Description cannot be empty');
            }
        }
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