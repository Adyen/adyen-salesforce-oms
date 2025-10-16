global with sharing class AdyenRefundRefBatchJobScheduler implements Schedulable{
    global void execute(SchedulableContext schedulableContext) {
        AdyenRefundReferenceBatch batch = new AdyenRefundReferenceBatch();
        Database.executeBatch(batch); 
    }
}