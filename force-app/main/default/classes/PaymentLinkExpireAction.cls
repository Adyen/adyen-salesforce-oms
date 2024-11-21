global with sharing class PaymentLinkExpireAction {
    @InvocableMethod(Label = 'Force Expire Link' Category = 'Payment Link' Callout = true)
    global static void forceExpireLink(List<PBLForceExpire> pblForceExpireList) {
        if (pblForceExpireList == null || pblForceExpireList.isEmpty() || pblForceExpireList[0].orderSummaryId == null) {
            throw new IllegalArgumentException('Required order summary Id is missing!');
        }

        String expiredStatus = AdyenOMSConstants.PaymentLinkStatus.EXPIRED.name();
        String activeStatus = AdyenOMSConstants.PaymentLinkStatus.ACTIVE.name();
        Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByDeveloperName(AdyenConstants.DEFAULT_ADAPTER_NAME);
        Id orderSummaryId = pblForceExpireList[0].orderSummaryId;

        List<Payment_Link__c> activePaymentLinks = [
                SELECT Name, Expire_Date__c
                FROM Payment_Link__c
                WHERE Order_Summary__c = :orderSummaryId AND Status__c LIKE :activeStatus
        ];
        for (Payment_Link__c activeLink : activePaymentLinks) {
            if (activeLink.Expire_Date__c > Datetime.now()) { // expire date in the future
                Map<String,String> expirePatchBody = new Map<String, String>{ 'status' => expiredStatus.toLowerCase() };
                AdyenPBLHelper.sendLinkPatchRequest(adyenAdapter, activeLink.Name, JSON.serialize(expirePatchBody));
            }
            activeLink.Status__c = expiredStatus;
        }
        update activePaymentLinks;
    }

    global class PBLForceExpire {
        @InvocableVariable(Required=true)
        public Id orderSummaryId;
    }
}
