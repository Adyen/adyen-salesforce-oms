public with sharing class AdyenWebhookSetupController {
    
    public class WebhookSetupResult {
        @AuraEnabled
        public Boolean isSuccess { get; set; }
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
    
    @AuraEnabled
    public static String getWebhookUrl() {
        try {
            ConnectApi.NamedCredential webhookNamedCredential = ConnectApi.NamedCredentials.getNamedCredential(AdyenOMSConstants.WEBHOOK_NAMED_CREDENTIAL_NAME);
            String baseUrl = webhookNamedCredential.calloutUrl;
            Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByDeveloperName(AdyenConstants.DEFAULT_ADAPTER_NAME);
            String namespace = String.isNotBlank(adyenAdapter.Package_Namespace__c) ? adyenAdapter.Package_Namespace__c + '/' : '';
            return baseUrl + '/services/apexrest/' + namespace + 'adyenNotification/v1';
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving webhook URL: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static WebhookSetupResult setupWebhook(String description, List<String> eventCodes) {
        WebhookSetupResult result = new WebhookSetupResult();
        
        try {
            if (String.isBlank(description)) {
                throw new HandledException('Description cannot be empty.');
            }
            
            if (eventCodes == null || eventCodes.isEmpty()) {
                throw new HandledException('At least one event code must be selected.');
            }
            
            Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByDeveloperName(AdyenConstants.DEFAULT_ADAPTER_NAME);
            
            String webhookUrl = getWebhookUrl();
            
            WebhookSetupResponse webhookResponse = AdyenWebhookService.setupWebhook(
                adyenAdapter, 
                webhookUrl, 
                eventCodes, 
                description
            );
            
            result.isSuccess = true;
            result.webhookResponse = webhookResponse;
            
            try {
                String hmacKey = AdyenWebhookService.generateHmacKey(adyenAdapter, webhookResponse.id);
                result.hmacKey = hmacKey;
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
    
    @AuraEnabled
    public static String saveHmacToMetadata(String hmacKey) {
        try {
            if (String.isBlank(hmacKey)) {
                throw new AuraHandledException('HMAC Key cannot be empty.');
            }
            
            Adyen_Adapter__mdt adapterData = AdyenCustomMetadataService.getDefaultAdapter();
            adapterData.HMAC_Key__c = hmacKey;
            
            return AdyenCustomMetadataService.updateDefaultAdapter(adapterData);
        } catch (Exception e) {
            throw new AuraHandledException('Error saving HMAC key to metadata: ' + e.getMessage());
        }
    }
}