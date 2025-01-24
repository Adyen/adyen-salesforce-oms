public with sharing class AdyenPBLController {
    
    @AuraEnabled
    public static void updatePaymentLinkStatus(Id paymentLinkId) {

        if (paymentLinkId == null) {
            throw new AuraHandledException('Invalid Payment Link ID.');
        }
    
        try {

            Payment_Link__c paymentLink = [SELECT Id, Status__c, Name FROM Payment_Link__c WHERE Id = :paymentLinkId LIMIT 1];
            
            Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByDeveloperName(AdyenConstants.DEFAULT_ADAPTER_NAME);
            PaymentLinkResponse paymentLinkResponse = AdyenPBLHelper.getPaymentLinkById(adyenAdapter, paymentLink?.Name);
            String latestStatus = paymentLinkResponse.status; 
            
            if (latestStatus != null && AdyenOMSConstants.ADYEN_PBL_STATUS_TO_SF_STATUS.containsKey(latestStatus)) {
                paymentLink.Status__c = AdyenOMSConstants.ADYEN_PBL_STATUS_TO_SF_STATUS.get(latestStatus);
            }

            update paymentLink;

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
