@IsTest
private class PaymentLinkExpireActionTest {
    private static final String ACTIVE_STATUS = AdyenOMSConstants.PaymentLinkStatus.ACTIVE.name().toLowerCase();
    private static final String EXPIRED_STATUS = AdyenOMSConstants.PaymentLinkStatus.EXPIRED.name().toLowerCase();
    
    @IsTest(SeeAllData = true)
    static void expireLinkSuccessTest() {
        // Given - a date in the past
        OrderPaymentSummary orderPaySummary = TestDataFactory.insertAccountAndOrderPaymentSummary();
        Datetime dateInThePast = Datetime.now().addDays(-1);
        Payment_Link__c paymentLink = TestDataFactory.createPaymentLink(orderPaySummary.OrderSummaryId, ACTIVE_STATUS, dateInThePast);
        insert paymentLink;
        PaymentLinkExpireAction.PBLForceExpire forceExpireArg = new PaymentLinkExpireAction.PBLForceExpire();
        forceExpireArg.orderSummaryId = orderPaySummary.OrderSummaryId;
        // When
        PaymentLinkExpireAction.forceExpireLink(new List<PaymentLinkExpireAction.PBLForceExpire>{forceExpireArg});
        // Then
        paymentLink = [SELECT Status__c FROM Payment_Link__c WHERE Id = :paymentLink.Id];
        Assert.areEqual(EXPIRED_STATUS, paymentLink.Status__c.toLowerCase());

        // Given - a date in the future
        Datetime dateInTheFuture = Datetime.now().addDays(+1);
        paymentLink.Status__c = ACTIVE_STATUS;
        paymentLink.Expire_Date__c = dateInTheFuture;
        update paymentLink;
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.PBLMockResponse());
        // When
        Test.startTest();
        PaymentLinkExpireAction.forceExpireLink(new List<PaymentLinkExpireAction.PBLForceExpire>{forceExpireArg});
        Test.stopTest();
        // Then
        paymentLink = [SELECT Status__c FROM Payment_Link__c WHERE Id = :paymentLink.Id];
        Assert.areEqual(EXPIRED_STATUS, paymentLink.Status__c.toLowerCase());
    }

    @IsTest
    static void noPayLinksToExpireTest() {
        // Given
        Payment_Link__c paymentLink = TestDataFactory.createPaymentLink(null, ACTIVE_STATUS, Datetime.now());
        insert paymentLink;
        PaymentLinkExpireAction.PBLForceExpire forceExpireArg = new PaymentLinkExpireAction.PBLForceExpire();
        forceExpireArg.orderSummaryId = '1Osa5000000Z000000';
        // When
        PaymentLinkExpireAction.forceExpireLink(new List<PaymentLinkExpireAction.PBLForceExpire>{forceExpireArg});
        // Then
        paymentLink = [SELECT Status__c FROM Payment_Link__c WHERE Id = :paymentLink.Id];
        Assert.areEqual(ACTIVE_STATUS, paymentLink.Status__c.toLowerCase());
    }

    @IsTest(SeeAllData = true)
    static void multipleLinksToExpireTest() {
        // Given
        OrderPaymentSummary orderPaySummary = TestDataFactory.insertAccountAndOrderPaymentSummary();
        Id orderSummaryId = orderPaySummary.OrderSummaryId;
        Payment_Link__c paymentLink1 = TestDataFactory.createPaymentLink(orderSummaryId, ACTIVE_STATUS, Datetime.now().addDays(-2));
        Payment_Link__c paymentLink2 = TestDataFactory.createPaymentLink(orderSummaryId, ACTIVE_STATUS, Datetime.now().addDays(-1));
        Payment_Link__c paymentLink3 = TestDataFactory.createPaymentLink(orderSummaryId, ACTIVE_STATUS, Datetime.now().addDays(+1));
        Payment_Link__c paymentLink4 = TestDataFactory.createPaymentLink(orderSummaryId, ACTIVE_STATUS, Datetime.now().addDays(+2));
        Payment_Link__c paymentLink5 = TestDataFactory.createPaymentLink(orderSummaryId, EXPIRED_STATUS, Datetime.now());
        insert new List<Payment_Link__c>{ paymentLink1, paymentLink2, paymentLink3, paymentLink4, paymentLink5 };
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.PBLMockResponse());
        PaymentLinkExpireAction.PBLForceExpire forceExpireArg = new PaymentLinkExpireAction.PBLForceExpire();
        forceExpireArg.orderSummaryId = orderSummaryId;
        // When
        Test.startTest();
        PaymentLinkExpireAction.forceExpireLink(new List<PaymentLinkExpireAction.PBLForceExpire>{forceExpireArg});
        Test.stopTest();
        // Then
        Assert.areEqual(0, [SELECT COUNT() FROM Payment_Link__c WHERE Order_Summary__c = :orderSummaryId AND Status__c LIKE :ACTIVE_STATUS]);
        Assert.areEqual(5, [SELECT COUNT() FROM Payment_Link__c WHERE Order_Summary__c = :orderSummaryId AND Status__c LIKE :EXPIRED_STATUS]);
    }

    @IsTest(SeeAllData = true)
    static void noRequiredArgTest() {
        // Given - no args
        // When
        try {
            PaymentLinkExpireAction.forceExpireLink(new List<PaymentLinkExpireAction.PBLForceExpire>());
            Assert.fail();
        } catch (Exception ex) { // Then
            Assert.isInstanceOfType(ex, IllegalArgumentException.class);
        }
    }

    @IsTest(SeeAllData = true)
    static void expireErrorResponseTest() {
        // Given
        OrderPaymentSummary orderPaySummary = TestDataFactory.insertAccountAndOrderPaymentSummary();
        Id orderSummaryId = orderPaySummary.OrderSummaryId;
        Payment_Link__c paymentLink = TestDataFactory.createPaymentLink(orderSummaryId, ACTIVE_STATUS, Datetime.now().addDays(+2));
        insert paymentLink;
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.FailureResponse());
        PaymentLinkExpireAction.PBLForceExpire forceExpireArg = new PaymentLinkExpireAction.PBLForceExpire();
        forceExpireArg.orderSummaryId = orderSummaryId;
        // When
        try {
            Test.startTest();
            PaymentLinkExpireAction.forceExpireLink(new List<PaymentLinkExpireAction.PBLForceExpire>{forceExpireArg});
            Test.stopTest();
        } catch (Exception ex) { // Then
            Assert.isInstanceOfType(ex, AdyenGatewayAdapter.GatewayException.class);
        }
    }
}
