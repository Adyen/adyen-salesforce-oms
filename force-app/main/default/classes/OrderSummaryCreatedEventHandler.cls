public with sharing class OrderSummaryCreatedEventHandler {

    public static void handleAfterInsert(List<OrderSummaryCreatedEvent> events) {
    
        Set<Id> orderSummaryIds = new Set<Id>();
        for (OrderSummaryCreatedEvent event : events) {
            if (event.OrderSummaryId != null) {
                orderSummaryIds.add(event.OrderSummaryId);
            }
        }

        Map<String, Id> orderNumberToSummaryIdMap = new Map<String, Id>();
        List<OrderSummary> orderSummaries = [
            SELECT Id, OrderNumber
            FROM OrderSummary
            WHERE Id IN :orderSummaryIds
        ];
        
        for (OrderSummary orderSummary : orderSummaries) {
            if (orderSummary.OrderNumber != null) {
                orderNumberToSummaryIdMap.put(orderSummary.OrderNumber, orderSummary.Id);
            }
        }

        if (orderNumberToSummaryIdMap.isEmpty()) {
            return; 
        }

        List<Payment_Link__c> paymentLinksToUpdate = [
            SELECT Id, Order_Number__c, Order_Summary__c
            FROM Payment_Link__c
            WHERE Order_Number__c IN :orderNumberToSummaryIdMap.keySet()
            AND Order_Summary__c = null
        ];
        
        for (Payment_Link__c paymentLink : paymentLinksToUpdate) {
            if (orderNumberToSummaryIdMap.containsKey(paymentLink.Order_Number__c)) {
                paymentLink.Order_Summary__c = orderNumberToSummaryIdMap.get(paymentLink.Order_Number__c);
            }
        }
        
        if (!paymentLinksToUpdate.isEmpty()) {
            update paymentLinksToUpdate;
        }
    }
}