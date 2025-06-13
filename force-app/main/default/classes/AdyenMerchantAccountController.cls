public with sharing class AdyenMerchantAccountController {
    
    @AuraEnabled
    public static String getMerchantAccountConfiguration() {
        try {
            return AdyenCustomMetadataService.getDefaultAdapter().Merchant_Account__c;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving merchant account configuration: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String updateMerchantAccount(String merchantAccountId) {
        try {
            if (String.isBlank(merchantAccountId)) {
                throw new AuraHandledException('Merchant Account cannot be empty.');
            }
            
            Adyen_Adapter__mdt adapterData = AdyenCustomMetadataService.getDefaultAdapter();
            adapterData.Merchant_Account__c = merchantAccountId;
            
            return AdyenCustomMetadataService.updateDefaultAdapter(adapterData);
        } catch (Exception e) {
            throw new AuraHandledException('Error updating merchant account: ' + e.getMessage());
        }
    }
}