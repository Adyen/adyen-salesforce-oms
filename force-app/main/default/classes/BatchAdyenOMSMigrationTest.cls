@isTest
public with sharing class BatchAdyenOMSMigrationTest {
    private static final String TEST_PSP_REFERENCE = '853587067740652G';
    private static final String TEST_PSP_REFERENCE_FAIL = '853587067740652F';
    private static final String TEST_MERCHANT_ACCOUNT = 'TEST_MERCHANT_ACCOUNT';
    private static final String TEST_MERCHANT_REFERENCE = 'TEST_MERCHANT_REFERENCE';
    private static final String TEST_SHOPPER_REFERENCE = 'TEST_SHOPPER_REFERENCE';
    private static final String TEST_CARD_SUCCESS = '4242424242424242';
    private static final String TEST_PAYMENT_TOKEN = 'TEST_PAYMENT_TOKEN';
    private static final String TEST_AUTH_CODE = 'TEST_AUTH_CODE';
    private static final String RESULT_CODE_SUCCESS = 'Authorised';
    private static final String RESULT_CODE_FAIL = 'Failure';
    private static final Double TEST_AMOUNT = 19.99;

    @IsTest(SeeAllData=true) // needed only for ConnectApi call in TestDataFactory
    private static void batchTest() {
        OrderPaymentSummary orderPaymentSummary = TestDataFactory.insertOrderPaymentSummary();
        orderPaymentSummary.OrderSummary = [
            SELECT SalesChannel.adyensompackage__AdyenMerchantID__c, adyensompackage__Adyen_paymentMethod__c
            FROM OrderSummary
            WHERE Id = :orderPaymentSummary.OrderSummaryId
        ];

        orderPaymentSummary.OrderSummary.SalesChannel.adyensompackage__AdyenMerchantID__c = 'MyMerchantId';
        update orderPaymentSummary.OrderSummary.SalesChannel;
        
        orderPaymentSummary.OrderSummary.adyensompackage__Adyen_paymentMethod__c = 'Card';
        update orderPaymentSummary.OrderSummary;

        Test.startTest();
        Database.executeBatch(new BatchAdyenOMSMigration(''));
        Test.stopTest();

        orderPaymentSummary = [
            SELECT OrderSummary.SalesChannel.adyensompackage__AdyenMerchantID__c, OrderSummary.adyensompackage__Adyen_paymentMethod__c, OrderSummary.SalesChannel.AdyenMerchantID__c
            FROM OrderPaymentSummary 
            WHERE Id = :orderPaymentSummary.Id
            LIMIT 1
        ];

        PaymentAuthorization paymentAuthorization = [
            SELECT Adyen_Payment_Method__c, Adyen_Payment_Method_Variant__c
            FROM PaymentAuthorization
            WHERE OrderPaymentSummaryId = :orderPaymentSummary.Id
            LIMIT 1
        ];

        Payment payment = [
            SELECT Adyen_Payment_Method__c, Adyen_Payment_Method_Variant__c
            FROM Payment
            WHERE OrderPaymentSummaryId = :orderPaymentSummary.Id
            LIMIT 1
        ];

        System.Assert.areEqual('MyMerchantId', orderPaymentSummary.OrderSummary.SalesChannel.AdyenMerchantID__c);

        System.Assert.areEqual('Card', paymentAuthorization.Adyen_Payment_Method__c);
        System.Assert.areEqual('Card', paymentAuthorization.Adyen_Payment_Method_Variant__c);

        System.Assert.areEqual('Card', payment.Adyen_Payment_Method__c);
        System.Assert.areEqual('Card', payment.Adyen_Payment_Method_Variant__c);
    }
}