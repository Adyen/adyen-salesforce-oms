@IsTest
private class PaymentLinkRegenerateActionTest {
    private static final String ACTIVE_STATUS = AdyenOMSConstants.PaymentLinkStatus.ACTIVE.name().toLowerCase();
    private static final String EXPIRED_STATUS = AdyenOMSConstants.PaymentLinkStatus.EXPIRED.name().toLowerCase();
    
    @IsTest(SeeAllData = true)
    static void regenerateLinkSuccessTest() {
        // Given
        OrderPaymentSummary orderPaySummary = TestDataFactory.insertAccountAndOrderPaymentSummary();
        Datetime expiryDate = Datetime.now().addDays(1);
        Payment_Link__c paymentLink = TestDataFactory.createPaymentLink(orderPaySummary.OrderSummaryId, ACTIVE_STATUS, expiryDate);
        insert paymentLink;
        PaymentLinkRegenerateAction.PBLRegenerateInput regenerateRequest = new PaymentLinkRegenerateAction.PBLRegenerateInput();
        regenerateRequest.orderSummaryId = orderPaySummary.OrderSummaryId;

        Test.setMock(HttpCalloutMock.class, new TestDataFactory.PBLMockResponse());
        // When
        Test.startTest();
        PaymentLinkRegenerateAction.regenerateLink(new List<PaymentLinkRegenerateAction.PBLRegenerateInput>{regenerateRequest});
        Test.stopTest();
        // Then
        paymentLink = [SELECT Status__c FROM Payment_Link__c WHERE Id = :paymentLink.Id];
        Assert.areEqual(EXPIRED_STATUS, paymentLink.Status__c.toLowerCase());
        Assert.areEqual(1, [SELECT COUNT() FROM Payment_Link__c WHERE Order_Summary__c = :orderPaySummary.OrderSummaryId AND Status__c LIKE :ACTIVE_STATUS]);
    }

    @IsTest(SeeAllData = true)
    static void noExistingLinkTest() {
        // Given
        OrderPaymentSummary orderPaySummary = TestDataFactory.insertAccountAndOrderPaymentSummary();
        Payment_Link__c paymentLink = TestDataFactory.createPaymentLink(null, ACTIVE_STATUS, Datetime.now());
        insert paymentLink;
        PaymentLinkRegenerateAction.PBLRegenerateInput regenerateRequest = new PaymentLinkRegenerateAction.PBLRegenerateInput();
        regenerateRequest.orderSummaryId = orderPaySummary.OrderSummaryId;
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.PBLMockResponse());
        // When
        Test.startTest();
        try {
            PaymentLinkRegenerateAction.regenerateLink(new List<PaymentLinkRegenerateAction.PBLRegenerateInput>{regenerateRequest});
            Assert.fail('An Exception should have been thrown.');
        } catch(Exception e) {
            Assert.areEqual(
                'No previous payment link found for the given order summary.',
                e.getMessage(),
                'The error message should match the expected output.'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void noRequiredArgTest() {
        // Given - no args
        // When
        try {
            PaymentLinkRegenerateAction.regenerateLink(new List<PaymentLinkRegenerateAction.PBLRegenerateInput>());
            Assert.fail();
        } catch (Exception ex) { // Then
            Assert.isInstanceOfType(ex, IllegalArgumentException.class);
        }
    }
}
