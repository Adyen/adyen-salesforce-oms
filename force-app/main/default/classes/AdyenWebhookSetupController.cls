public with sharing class AdyenWebhookSetupController {
    
    public class WebhookSetupResult {
        @AuraEnabled
        public Boolean isSuccess { get; set; }
        @AuraEnabled
        public String errorMessage { get; set; }
        @AuraEnabled
        public WebhookSetupResponse webhookResponse { get; set; }
        
        public WebhookSetupResult() {
            this.isSuccess = false;
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
            
        } catch (Exception e) {
            result.isSuccess = false;
            result.errorMessage = e.getMessage();
        }
        
        return result;
    }
}