global with sharing class AdyenPaymentLinkBatchJobScheduler implements Schedulable{
    global void execute(SchedulableContext schedulableContext) {
        AdyenPaymentLinkBatch adyenPaymentLinkBatch = new AdyenPaymentLinkBatch();
        Database.executeBatch(adyenPaymentLinkBatch);
    }
}