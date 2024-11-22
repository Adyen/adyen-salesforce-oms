@IsTest
private class AdyenRefundHelperTest {
    @IsTest
    static void createPaypalAuthRefundRequestTest() {
        // Given
        Account acct = TestDataFactory.createAccount();
        insert acct;
        CardPaymentMethod cardPayMeth = TestDataFactory.createCardPaymentMethod();
        insert cardPayMeth;
        PaymentAuthorization payAuth = TestDataFactory.createPaymentAuthorization(acct.Id, cardPayMeth.Id, null, null, TestDataFactory.TEST_PSP_REFERENCE);
        payAuth.Adyen_Payment_Method_Variant__c = 'paypal';
        insert payAuth;
        Payment payment = TestDataFactory.createPayment(acct.Id, cardPayMeth.Id, null, payAuth.Id, null);
        payment.GatewayRefDetails = 'FO_007';
        insert payment;
        payment.PaymentAuthorization = [SELECT Adyen_Payment_Method_Variant__c FROM PaymentAuthorization WHERE Id = :payAuth.Id];
        CommercePayments.ReferencedRefundRequest refundRequest = new CommercePayments.ReferencedRefundRequest(TestDataFactory.TEST_PRICE_AMOUNT, payment.Id);

        // Then
        CheckoutRefundRequest modificationRequest = AdyenRefundHelper.createRefundRequest(refundRequest, payment, AdyenPaymentUtility.chooseAdapterWithFallBack(null));

        // When
        Assert.isNotNull(modificationRequest.capturePspReference);
        Assert.areEqual(TestDataFactory.TEST_PSP_REFERENCE, modificationRequest.capturePspReference);
    }
}
