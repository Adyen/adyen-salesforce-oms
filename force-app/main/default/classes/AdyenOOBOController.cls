public with sharing class AdyenOOBOController {

    @AuraEnabled(cacheable=true)
    public static Id getOrderSummaryIdByOrderNumber(String orderNumber) {
        try {
            List<OrderSummary> orderSummaries = [
                SELECT Id 
                FROM OrderSummary 
                WHERE OrderNumber = :orderNumber 
                LIMIT 1
            ];

            if (!orderSummaries.isEmpty()) {
                return orderSummaries[0].Id;
            } else {
                throw new AuraHandledException('Order Summary not found for the provided order number: ' + orderNumber);
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}