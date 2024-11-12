@IsTest
public class OrderSummaryCreatedEventHandlerTest {

    @IsTest(SeeAllData=true)
    static void handleAfterInsertWithMatchingLinkTest() {
        // Given
        List<OrderSummary> orderSummaries = setupAndGetOrderSummary();
        Payment_Link__c paymentLink = insertPaymentLink(orderSummaries[0].OrderNumber);
        List<OrderSummaryCreatedEvent> events = createEventForOrderSummary(orderSummaries);

        // When
        Test.startTest();
        OrderSummaryCreatedEventHandler.handleAfterInsert(events);
        Test.stopTest();

        Payment_Link__c updatedPaymentLink = [
            SELECT Id, Order_Number__c, Order_Summary__c
            FROM Payment_Link__c
            WHERE Id =: paymentLink.Id LIMIT 1
        ];
       
        // Then
        Assert.areNotEqual(null, updatedPaymentLink.Order_Summary__c, 
            'Expected Order_Summary__c to be populated for matching OrderNumber');
    }

    @IsTest(SeeAllData=true)
    static void handleAfterInsertWithNoMatchingLinksTest() {
        // Given
        List<OrderSummary> orderSummaries = setupAndGetOrderSummary();
        Payment_Link__c paymentLink = insertPaymentLink('NonMatchingOrderNumber');
        List<OrderSummaryCreatedEvent> events = createEventForOrderSummary(orderSummaries);

        // When
        Test.startTest();
        OrderSummaryCreatedEventHandler.handleAfterInsert(events);
        Test.stopTest();

        Payment_Link__c updatedPaymentLink = [
            SELECT Id, Order_Number__c, Order_Summary__c
            FROM Payment_Link__c
            WHERE Id =: paymentLink.Id LIMIT 1
        ];

        // Then
        Assert.areEqual(null, updatedPaymentLink.Order_Summary__c, 
            'Expected Order_Summary__c to remain null when no matching OrderNumber is found');
    }

    private static List<OrderSummary> setupAndGetOrderSummary() {
        OrderPaymentSummary ops = TestDataFactory.insertAccountAndOrderPaymentSummary();
        return [SELECT Id, OrderNumber FROM OrderSummary WHERE Id =: ops.OrderSummaryId];
    }

    private static List<OrderSummaryCreatedEvent> createEventForOrderSummary(List<OrderSummary> orderSummaries) {
        return new List<OrderSummaryCreatedEvent>{
            new OrderSummaryCreatedEvent(OrderSummaryId = orderSummaries[0].Id)
        };
    }

    private static Payment_Link__c insertPaymentLink(String orderNumber) {
        Payment_Link__c paymentLink = new Payment_Link__c(Order_Number__c = orderNumber, Order_Summary__c = null);
        insert paymentLink;
        return paymentLink;
    }
}
