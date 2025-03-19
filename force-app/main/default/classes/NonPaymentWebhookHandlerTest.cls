@IsTest
private class NonPaymentWebhookHandlerTest {
    private static final String ACTIVE_STATUS = AdyenOMSConstants.PaymentLinkStatus.ACTIVE.name().toLowerCase();
    private static final String COMPLETED_STATUS = AdyenOMSConstants.PaymentLinkStatus.COMPLETED.name().toLowerCase();

    @IsTest
    static void unsupportedNotificationTypeTest() {
        // given unsupported notification type (not a cancellation)
        String wrongWebhookType = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE_FAILED, '1234567890123456', '1010101010101010', '999999', true);
        RestContext.request = createRestRequest(wrongWebhookType);

        // when
        Test.startTest();
        String response = NonPaymentWebhookHandler.doPost();
        Test.stopTest();

        // then
        Assert.isNotNull(response);
        Assert.isTrue(response.containsIgnoreCase(NonPaymentWebhookHandler.INVALID_WEBHOOK));
    }

    @IsTest
    static void notificationWithInvalidPspTest() {
        // given invalid pspReference in notification
        String invalidWebhook = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE, '111', '222', '999999', true);
        RestContext.request = createRestRequest(invalidWebhook);

        // when
        Test.startTest();
        String response = NonPaymentWebhookHandler.doPost();
        Test.stopTest();

        // then
        Assert.isNotNull(response);
        Assert.isTrue(response.containsIgnoreCase(NonPaymentWebhookHandler.INVALID_WEBHOOK));
    }

    @IsTest(SeeAllData=true)
    static void notificationWithMissingPaymentAuthTest() {
        // given valid cancellation webhook but no related payment found
        TestDataFactory.insertAccountOrderAndPayAuth(AdyenOMSConstants.PaymentAuthorizationStatus.PROCESSED.name());
        String validWebhook = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CANCEL, '123456789012ABCD','101010101010ABCD', '999999', true);
        RestContext.request = createRestRequest(validWebhook);

        // when
        Test.startTest();
        String response = NonPaymentWebhookHandler.doPost();
        Test.stopTest();

        // then
        Assert.isNotNull(response);
        Assert.isTrue(response.containsIgnoreCase(NonPaymentWebhookHandler.NO_PAYMENT_FOUND));
    }

    @IsTest(SeeAllData = true)
    static void successfulCancellationNotificationTest() {
        // given valid cancellation with a related PaymentAuthorization
        PaymentAuthorization payAuth = TestDataFactory.insertAccountOrderAndPayAuth(AdyenOMSConstants.PaymentAuthorizationStatus.PROCESSED.name());
        String successWebhook = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CANCEL, '123456789012ABCD', TestDataFactory.TEST_PSP_REFERENCE, '999999', true);
        RestContext.request = createRestRequest(successWebhook);

        // when
        Test.startTest();
        String response = NonPaymentWebhookHandler.doPost();
        Test.stopTest();

        // then
        Assert.areEqual(NonPaymentWebhookHandler.ACCEPTED_RESPONSE, response, 'Expected accepted response');
        PaymentGatewayLog successGatewayLog = [SELECT Id, InteractionStatus, OrderPaymentSummaryId FROM PaymentGatewayLog WHERE ReferencedEntityId = :payAuth.Id LIMIT 1];
        Assert.areEqual('Success', successGatewayLog.InteractionStatus, 'Expected interaction status to be Success.');
        Assert.areEqual(payAuth.OrderPaymentSummaryId, successGatewayLog.OrderPaymentSummaryId, 'successGatewayLog should be related to OrderPaymentSummary');
    }

    @IsTest(SeeAllData = true)
    static void failedCancellationNotificationTest() {
        // given failed cancellation with a related PaymentAuthorization
        PaymentAuthorization payAuth = TestDataFactory.insertAccountOrderAndPayAuth(AdyenOMSConstants.PaymentAuthorizationStatus.PROCESSED.name());
        String failedWebhook = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CANCEL, '123456789012ABCD', TestDataFactory.TEST_PSP_REFERENCE, '999999', false);
        RestContext.request = createRestRequest(failedWebhook);

        // when
        Test.startTest();
        String response = NonPaymentWebhookHandler.doPost();
        Test.stopTest();

        // then
        Assert.areEqual(NonPaymentWebhookHandler.ACCEPTED_RESPONSE, response, 'Expected accepted response');
        PaymentGatewayLog failedGatewayLog = [SELECT Id, InteractionStatus, OrderPaymentSummaryId FROM PaymentGatewayLog WHERE ReferencedEntityId = :payAuth.Id LIMIT 1];
        Assert.areEqual('Failed', failedGatewayLog.InteractionStatus, 'Expected interaction status to be Failed.');
        Assert.areEqual(payAuth.OrderPaymentSummaryId, failedGatewayLog.OrderPaymentSummaryId, 'failedGatewayLog should be related to OrderPaymentSummary');
    }

    @IsTest
    static void invalidNotificationRequestTest() {
        // given an invalid request to trigger an exception
        RestContext.request = createRestRequest('invalid_body');

        // when
        Test.startTest();
        String response = NonPaymentWebhookHandler.doPost();
        Test.stopTest();

        // then
        Assert.isNotNull(response);
        Assert.isTrue(response.containsIgnoreCase('exception'));
    }

    @IsTest(SeeAllData = true)
    static void successfulAuthorizationWebhookTest() {
        // given
        PaymentAuthorization payAuth = TestDataFactory.insertCartAndRelatedPA();
        PaymentAuthorization payAuthWithOrderSummary = [SELECT Id, OrderPaymentSummary.OrderSummary.OrderNumber FROM PaymentAuthorization WHERE Id =:payAuth.Id LIMIT 1];
        String orderNumber = payAuthWithOrderSummary.OrderPaymentSummary.OrderSummary.OrderNumber;
        String successfulAuthWebhook = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE, TestDataFactory.TEST_PSP_REFERENCE, null, orderNumber, true);
        RestContext.request = createRestRequest(successfulAuthWebhook);

        // when
        Test.startTest();
        String response = NonPaymentWebhookHandler.doPost();
        Test.stopTest();

        // then
        payAuth = [SELECT Status, GatewayRefNumber FROM PaymentAuthorization WHERE Id = :payAuth.Id];
        PaymentGatewayLog payGatewayLog = [SELECT GatewayRefNumber, InteractionStatus FROM PaymentGatewayLog WHERE ReferencedEntityId = :payAuth.Id];
        Assert.areEqual(NonPaymentWebhookHandler.ACCEPTED_RESPONSE, response);
        Assert.areEqual(AdyenOMSConstants.PaymentAuthorizationStatus.PROCESSED.name(), payAuth.Status.toUpperCase());
        Assert.areEqual(TestDataFactory.TEST_PSP_REFERENCE, payAuth.GatewayRefNumber);
        Assert.areEqual(AdyenOMSConstants.PaymentGatewayLogStatus.SUCCESS.name(), payGatewayLog.InteractionStatus.toUpperCase());
    }

    @IsTest(SeeAllData = true)
    static void authWebhookWithPaymentLinkTest() {
        // given
        PaymentAuthorization payAuth = TestDataFactory.insertCartAndRelatedPA();
        PaymentAuthorization payAuthWithOrderSummary = [SELECT Id, OrderPaymentSummary.OrderSummary.OrderNumber FROM PaymentAuthorization WHERE Id =:payAuth.Id LIMIT 1];
        String orderNumber = payAuthWithOrderSummary.OrderPaymentSummary.OrderSummary.OrderNumber;
        Datetime dateInTheFuture = Datetime.now().addDays(+1);
        Payment_Link__c paymentLink = TestDataFactory.createPaymentLink(payAuthWithOrderSummary.OrderPaymentSummary.orderSummaryId, ACTIVE_STATUS, dateInTheFuture);
        insert paymentLink;
        String successfulPblAuthWebhook = TestDataFactory.mockPblWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE, TestDataFactory.TEST_PSP_REFERENCE, paymentLink.Name, orderNumber, true);
        RestContext.request = createRestRequest(successfulPblAuthWebhook);

        // when
        Test.startTest();
        String response = NonPaymentWebhookHandler.doPost();
        Test.stopTest();

        // then
        payAuth = [SELECT Status, GatewayRefNumber, Adyen_Payment_Method_Variant__c FROM PaymentAuthorization WHERE Id = :payAuth.Id];
        PaymentGatewayLog payGatewayLog = [SELECT GatewayRefNumber, InteractionStatus FROM PaymentGatewayLog WHERE ReferencedEntityId = :payAuth.Id];
        Payment_Link__c updatedPaymentLink = [SELECT Status__c, Payment_Method_Used__c FROM Payment_Link__c WHERE Id = :paymentLink.Id];
        Assert.areEqual(NonPaymentWebhookHandler.ACCEPTED_RESPONSE, response);
        Assert.areEqual(AdyenOMSConstants.PaymentAuthorizationStatus.PROCESSED.name(), payAuth.Status.toUpperCase());
        Assert.areEqual(COMPLETED_STATUS, updatedPaymentLink.Status__c?.toLowerCase());
        Assert.isNotNull(updatedPaymentLink.Payment_Method_Used__c);
        Assert.areEqual(TestDataFactory.TEST_PSP_REFERENCE, payAuth.GatewayRefNumber);
        Assert.isNotNull(payAuth.Adyen_Payment_Method_Variant__c);
        Assert.areEqual(AdyenOMSConstants.PaymentGatewayLogStatus.SUCCESS.name(), payGatewayLog.InteractionStatus.toUpperCase());
    }

    @IsTest(SeeAllData = true)
    static void unsuccessfulAuthorizationWebhookTest() {
        // given
        PaymentAuthorization payAuth = TestDataFactory.insertCartAndRelatedPA();
        PaymentAuthorization payAuthWithOrderSummary = [SELECT Id, OrderPaymentSummary.OrderSummary.OrderNumber FROM PaymentAuthorization WHERE Id =:payAuth.Id LIMIT 1];
        String orderNumber = payAuthWithOrderSummary.OrderPaymentSummary.OrderSummary.OrderNumber;
        String unsuccessfulAuthWebhook = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE, TestDataFactory.TEST_PSP_REFERENCE, null, orderNumber, false);
        RestContext.request = createRestRequest(unsuccessfulAuthWebhook);

        // when
        Test.startTest();
        String response = NonPaymentWebhookHandler.doPost();
        Test.stopTest();

        // then
        payAuth = [SELECT Status, GatewayRefNumber FROM PaymentAuthorization WHERE Id = :payAuth.Id];
        PaymentGatewayLog payGatewayLog = [SELECT GatewayRefNumber, InteractionStatus FROM PaymentGatewayLog WHERE ReferencedEntityId = :payAuth.Id];
        Assert.areEqual(NonPaymentWebhookHandler.ACCEPTED_RESPONSE, response);
        Assert.areEqual(AdyenOMSConstants.PaymentAuthorizationStatus.PENDING.name(), payAuth.Status.toUpperCase());
        Assert.areEqual(TestDataFactory.TEST_PSP_REFERENCE, payAuth.GatewayRefNumber);
        Assert.areEqual(AdyenOMSConstants.PaymentGatewayLogStatus.FAILED.name(), payGatewayLog.InteractionStatus.toUpperCase());
    }

    @IsTest
    static void missingCartForAuthWebhookTest() {
        String successfulAuthWebhook = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE, TestDataFactory.TEST_PSP_REFERENCE, null, '0a6a50000000000000', true);
        RestContext.request = createRestRequest(successfulAuthWebhook);

        // when
        Test.startTest();
        String response = NonPaymentWebhookHandler.doPost();
        Test.stopTest();

        Assert.areEqual(NonPaymentWebhookHandler.responseWithReason(NonPaymentWebhookHandler.NO_PAYMENT_FOUND), response);
    }
    
    @IsTest(SeeAllData = true)
    static void captureWebhookWithoutPaymentRecordTest() {
        // given
        PaymentAuthorization payAuth = TestDataFactory.insertAccountOrderAndPayAuth(AdyenOMSConstants.PaymentAuthorizationStatus.PROCESSED.name());
        String captureWebhook = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE, '123456789012ABCD', TestDataFactory.TEST_PSP_REFERENCE, '999999', true);
        RestContext.request = createRestRequest(captureWebhook);

        // when
        Test.startTest();
        String response = NonPaymentWebhookHandler.doPost();
        Test.stopTest();

        // then
        PaymentGatewayLog captureGatewayLog = [SELECT Id, GatewayRefNumber, GatewayMessage, InteractionStatus FROM PaymentGatewayLog WHERE GatewayRefNumber = '123456789012ABCD' LIMIT 1];
        Assert.areEqual(NonPaymentWebhookHandler.ACCEPTED_RESPONSE, response, 'Expected accepted response');
        Assert.areEqual('Success', captureGatewayLog.InteractionStatus, 'Expected interaction status to be Success.');
        Assert.areEqual('[capture-completed]', captureGatewayLog.GatewayMessage);
    }
    
    @IsTest(SeeAllData = true)
    static void refundWebhookWithoutRefundRecordTest() {
        // given
        PaymentAuthorization payAuth = TestDataFactory.insertAccountOrderAndPayAuth(AdyenOMSConstants.PaymentAuthorizationStatus.PROCESSED.name());
        String refundWebhook = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_REFUND, '123456789012ABCD', TestDataFactory.TEST_PSP_REFERENCE, '999999', true);
        RestContext.request = createRestRequest(refundWebhook);

        // when
        Test.startTest();
        String response = NonPaymentWebhookHandler.doPost();
        Test.stopTest();

        // then
        PaymentGatewayLog refundGatewayLog = [SELECT Id, GatewayRefNumber, GatewayMessage, InteractionStatus FROM PaymentGatewayLog WHERE GatewayRefNumber = '123456789012ABCD' LIMIT 1];
        Assert.areEqual(NonPaymentWebhookHandler.ACCEPTED_RESPONSE, response, 'Expected accepted response');
        Assert.areEqual('Success', refundGatewayLog.InteractionStatus, 'Expected interaction status to be Success.');
        Assert.areEqual('[refund-completed]', refundGatewayLog.GatewayMessage);
    }

    private static RestRequest createRestRequest(String body) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/nonPaymentWebhook/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        return req;
    }
}