public with sharing class AdyenWebhookSetupController {
    public class WebhookSetupResult {
        @AuraEnabled
        public Boolean isSuccess { get; set; }
        @AuraEnabled
        public String webhookId { get; set; }
        @AuraEnabled
        public String errorMessage { get; set; }
        @AuraEnabled
        public WebhookSetupResponse webhookResponse { get; set; }
        @AuraEnabled
        public String hmacKey { get; set; }
        @AuraEnabled
        public Boolean hmacGenerationFailed { get; set; }
        @AuraEnabled
        public String hmacErrorMessage { get; set; }
        
        public WebhookSetupResult() {
            this.isSuccess = false;
            this.hmacGenerationFailed = false;
        }
    }

    public class WebhookTestResult {
        @AuraEnabled
        public Boolean isSuccess { get; set; }
        @AuraEnabled
        public String errorMessage { get; set; }
        @AuraEnabled
        public AdyenWebhookService.WebhookTestResponse testResponse { get; set; }
        
        public WebhookTestResult() {
            this.isSuccess = false;
        }
    }

    public class WebhookCheckResult {
        @AuraEnabled public Boolean webhookExists { get; set; }
        @AuraEnabled public String webhookId { get; set; }
        @AuraEnabled public Boolean webhookActive { get; set; }
        @AuraEnabled public String webhookUrl { get; set; }
        @AuraEnabled public String webhookDescription { get; set; }
        @AuraEnabled public List<String> webhookEventCodes { get; set; }
        
        @AuraEnabled public String detectedWebhookLevel { get; set; }
        @AuraEnabled public String requestedSetupType { get; set; }
        @AuraEnabled public Boolean isLevelMismatch { get; set; }
        
        public WebhookCheckResult() {
            this.webhookExists = false;
            this.webhookActive = false;
            this.webhookEventCodes = new List<String>();
            this.isLevelMismatch = false;
        }
    }

    @AuraEnabled
    public static String getWebhookUrl() {
        try {
            Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByDeveloperName(AdyenConstants.DEFAULT_ADAPTER_NAME);
            String namespace = adyenAdapter.Package_Namespace__c;

            String credentialName = AdyenOMSConstants.WEBHOOK_NAMED_CREDENTIAL_NAME;
            if (String.isNotBlank(namespace)) {
                credentialName = namespace + '__' + credentialName;
            }

            ConnectApi.NamedCredential webhookNamedCredential = ConnectApi.NamedCredentials.getNamedCredential(credentialName);
            String baseUrl = webhookNamedCredential.calloutUrl;
            String namespaceForUrl = String.isNotBlank(namespace) ? namespace + '/' : '';
            return baseUrl + '/services/apexrest/' + namespaceForUrl + 'adyenNotification/v1';
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving webhook URL: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static WebhookTestResult testWebhook(String webhookId, String setupType) {
        WebhookTestResult result = new WebhookTestResult();
        try {
            if (String.isBlank(webhookId)) {
                throw new HandledException('Webhook ID cannot be empty.');
            }
            
            AdyenWebhookService.WebhookContext context = createWebhookContext(setupType);
            AdyenWebhookService.WebhookTestResponse testResponse = AdyenWebhookService.testWebhook(context, webhookId);
            
            result.isSuccess = true;
            result.testResponse = testResponse;
        } catch (Exception e) {
            result.isSuccess = false;
            result.errorMessage = e.getMessage();
        }
        return result;
    }

    @AuraEnabled
    public static String saveWebhookDataToMetadata(String hmacKey, String webhookId) {
        try {
            if (String.isBlank(hmacKey)) {
                throw new AuraHandledException('HMAC Key cannot be empty.');
            }
            if (String.isBlank(webhookId)) {
                throw new AuraHandledException('Webhook ID cannot be empty.');
            }
            
            Adyen_Adapter__mdt adapterData = AdyenCustomMetadataService.getDefaultAdapter();
            adapterData.HMAC_Key__c = hmacKey;
            adapterData.Webhook_ID__c = webhookId;
            
            return AdyenCustomMetadataService.updateDefaultAdapter(adapterData);
        } catch (Exception e) {
            throw new AuraHandledException('Error saving webhook data to metadata: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static WebhookCheckResult checkExistingWebhook(String setupType) {
        try {
            Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByDeveloperName(AdyenConstants.DEFAULT_ADAPTER_NAME);
            if (String.isBlank(adyenAdapter.Webhook_ID__c)) {
                return new WebhookCheckResult();
            }

            AdyenWebhookService.WebhookContext context = createWebhookContext(setupType);
            WebhookSetupResponse existingWebhook = AdyenWebhookService.getWebhook(context, adyenAdapter.Webhook_ID__c);
            
            if (existingWebhook == null) {
                return new WebhookCheckResult();
            }

            WebhookCheckResult result = new WebhookCheckResult();
            result.webhookExists = true;
            result.webhookId = adyenAdapter.Webhook_ID__c;
            result.webhookActive = existingWebhook.active;
            result.webhookUrl = existingWebhook.url;
            result.webhookDescription = existingWebhook.description;
            result.requestedSetupType = setupType;
            
            if (existingWebhook.additionalSettings?.includeEventCodes != null) {
                result.webhookEventCodes = existingWebhook.additionalSettings.includeEventCodes;
            }
            
            result.detectedWebhookLevel = detectWebhookLevel(existingWebhook);
            
            result.isLevelMismatch = !setupType.equals(result.detectedWebhookLevel);
            
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error checking for existing webhook: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static WebhookSetupResult setupWebhook(String description, List<String> eventCodes, String setupType) {
        String webhookUrl = getWebhookUrl();
        AdyenWebhookService.WebhookRequest request = new AdyenWebhookService.WebhookRequest(webhookUrl, eventCodes, description);
        return processWebhookRequest(request, null, setupType);
    }

    @AuraEnabled
    public static WebhookSetupResult updateWebhook(String description, List<String> eventCodes, String webhookId, String setupType) {
        if (String.isBlank(webhookId)) {
            throw new AuraHandledException('Webhook ID cannot be empty for an update.');
        }
        String webhookUrl = getWebhookUrl();
        AdyenWebhookService.WebhookRequest request = new AdyenWebhookService.WebhookRequest(webhookUrl, eventCodes, description);
        return processWebhookRequest(request, webhookId, setupType);
    }

    @TestVisible
    private static AdyenWebhookService.WebhookContext createWebhookContext(String setupType) {
        Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByDeveloperName(AdyenConstants.DEFAULT_ADAPTER_NAME);
        
        if (AdyenWebhookService.SETUP_TYPE_COMPANY.equals(setupType)) {
            String companyId = AdyenManagementAPIService.getCompanyId();
            return new AdyenWebhookService.WebhookContext(adyenAdapter, setupType, companyId);
        } else {
            return new AdyenWebhookService.WebhookContext(adyenAdapter, AdyenWebhookService.SETUP_TYPE_MERCHANT, null);
        }
    }

    private static WebhookSetupResult processWebhookRequest(AdyenWebhookService.WebhookRequest request, String webhookId, String setupType) {
        WebhookSetupResult result = new WebhookSetupResult();

        try {
            AdyenWebhookService.WebhookContext context = createWebhookContext(setupType);
            WebhookSetupResponse webhookResponse;

            if (String.isBlank(webhookId)) {
                webhookResponse = AdyenWebhookService.setupWebhook(context, request);
            } else {
                webhookResponse = AdyenWebhookService.updateWebhook(context, webhookId, request);
            }

            result.isSuccess = true;
            result.webhookResponse = webhookResponse;
            result.webhookId = webhookResponse.id;

            try {
                result.hmacKey = AdyenWebhookService.generateHmacKey(context, webhookResponse.id);
            } catch (Exception hmacException) {
                result.hmacGenerationFailed = true;
                result.hmacErrorMessage = hmacException.getMessage();
            }

        } catch (Exception e) {
            result.isSuccess = false;
            result.errorMessage = e.getMessage();
        }

        return result;
    }

    private static String detectWebhookLevel(WebhookSetupResponse webhookResponse) {
        return String.isNotBlank(webhookResponse.filterMerchantAccountType) ? 
               AdyenWebhookService.SETUP_TYPE_COMPANY : 
               AdyenWebhookService.SETUP_TYPE_MERCHANT;
    }

}