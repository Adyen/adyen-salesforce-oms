public with sharing class AdyenRefundReferenceBatch implements Database.Batchable<sObject> {
         
    public Database.QueryLocator start(Database.BatchableContext batchContext) {
        return Database.getQueryLocator([
            SELECT Id, Request, ReferencedEntityId
            FROM PaymentGatewayLog
            WHERE InteractionType = 'ReferencedRefund'
            AND GatewayMessage = '[refund-received]'
            AND ReferencedEntityId != NULL
            AND ReferencedEntityId IN (
                SELECT Id
                FROM Refund
                WHERE Refund_Reference__c = NULL
            )
        ]);
    }
    
    public void execute(Database.BatchableContext batchContext, List<PaymentGatewayLog> gatewayLogs) {
        try {
            
            Map<Id, String> refundIdToReferenceMap = new Map<Id, String>();
    
            for (PaymentGatewayLog gatewayLog : gatewayLogs) {
                if (gatewayLog.Request != null && gatewayLog.ReferencedEntityId != null) {
                    Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(gatewayLog.Request);
                    String reference = (String) jsonMap.get('reference');
                    if (String.isNotBlank(reference)) {
                        refundIdToReferenceMap.put(gatewayLog.ReferencedEntityId, reference);
                    }
                }
            }
            
            if (!refundIdToReferenceMap.isEmpty()) {
                List<Refund> refundsToUpdate = new List<Refund>();
                for (Id refundId : refundIdToReferenceMap.keySet()) {
                    refundsToUpdate.add(new Refund(
                        Id = refundId,
                        Refund_Reference__c = refundIdToReferenceMap.get(refundId)
                    ));
                }
                update refundsToUpdate;
            }
        } catch (Exception e) {
            System.debug('Exception occured during batch execution: ' + e.getMessage());
        }
    }
    
    public void finish(Database.BatchableContext batchContext) {
        // No additional logic needed after batch execution
    }
}