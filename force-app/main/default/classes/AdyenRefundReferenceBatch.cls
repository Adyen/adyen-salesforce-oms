public without sharing class AdyenRefundReferenceBatch implements Database.Batchable<sObject> {
         
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
            Map<Id, Refund> refundsToUpdate = new Map<Id, Refund>();

            for (PaymentGatewayLog gatewayLog : gatewayLogs) {
                if (gatewayLog.Request != null && gatewayLog.ReferencedEntityId != null) {
                    Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(gatewayLog.Request);
                    String reference = (String) jsonMap.get('reference');
                    if (String.isNotBlank(reference)) {
                        refundsToUpdate.put(
                            gatewayLog.ReferencedEntityId,
                            new Refund(
                                Id = gatewayLog.ReferencedEntityId,
                                Refund_Reference__c = reference
                            )
                        );
                    }
                }
            }

            if (!refundsToUpdate.isEmpty()) {
                update refundsToUpdate.values();
            }
        } catch (Exception e) {
            System.debug('Exception occurred during batch execution: ' + e.getMessage());
        }
    }

    public void finish(Database.BatchableContext batchContext) {
        // No additional logic needed after batch execution
    }
}