public class AdyenPaymentLinkBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext batchContext) {
        return Database.getQueryLocator([
            SELECT Id, Expire_Date__c, Status__c 
            FROM Payment_Link__c 
            WHERE Status__c = 'Active'
        ]);
    }

    public void execute(Database.BatchableContext batchContext, List<Payment_Link__c> paymentLinkRecords) {
        List<Payment_Link__c> paymentLinksToExpire = new List<Payment_Link__c>();
        
        for (Payment_Link__c paymentLinkRecord : paymentLinkRecords) {
            if (paymentLinkRecord.Expire_Date__c != null && paymentLinkRecord.Expire_Date__c <= System.now()) {
                paymentLinkRecord.Status__c = AdyenOMSConstants.PaymentLinkStatus.EXPIRED.name();
                paymentLinksToExpire.add(paymentLinkRecord);
            }
        }

        if (!paymentLinksToExpire.isEmpty()) {
            update paymentLinksToExpire;
        }
    }

    public void finish(Database.BatchableContext batchContext) {
        // No additional logic needed after batch execution
    }
}