@isTest
public class AdyenOOBOControllerTest {

    @IsTest(SeeAllData=true)
    static void getOrderSummaryIdByOrderNumberTest_Success() {
        // Given
        Account acct = TestDataFactory.createAccount();
        insert acct;
        Order order = TestDataFactory.insertOrderAndRelatedRecords(acct.Id, 50, 10);
        OrderPaymentSummary orderPaymentSummary = TestDataFactory.createOrderSummaryRecords(order.Id);
        TestDataFactory.insertBasicPaymentRecords(acct.Id, orderPaymentSummary.Id);
        OrderSummary os = [SELECT Id, OrderNumber FROM OrderSummary LIMIT 1];

        // When
        Test.startTest();
        Id result = AdyenOOBOController.getOrderSummaryIdByOrderNumber(os.OrderNumber);
        Test.stopTest();

        // Then
        Assert.areEqual(os.Id, result, 'The returned Id should match the test OrderSummary Id.');
    }

    @IsTest(SeeAllData=true)
    static void getOrderSummaryIdByOrderNumberTest_NotFound() {
        // Given
        // No test data created intentionally for this scenario

        // When
        Test.startTest();
        try {
            Id result = AdyenOOBOController.getOrderSummaryIdByOrderNumber('NON_EXISTING_ORDER_NUMBER');
            Assert.isTrue(false, 'An Exception should have been thrown.');
        } catch (AuraHandledException e) {
            // Then
            Assert.areEqual(
                'Script-thrown exception',
                e.getMessage(),
                'The error message should match the expected output.'
            );
        }
        Test.stopTest();
    }
}