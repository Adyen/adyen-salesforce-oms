@IsTest
private class AdyenPaymentHelperTest {
    @IsTest
    static void notValidWebhookTest() {
        AdyenPaymentHelper.TEST_NOTIFICATION_REQUEST_BODY = TestDataFactory.createNotificationRequestBody(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE, null);

        Test.startTest();
        CommercePayments.GatewayNotificationResponse notificationResponse = AdyenPaymentHelper.handleAsyncNotificationCallback(null);
        Test.stopTest();

        Assert.isFalse(notificationResponse.toString().containsIgnoreCase('error'));
    }

    @IsTest
    static void noRelatedPaymentWebhookTest() {
        AdyenPaymentHelper.TEST_NOTIFICATION_REQUEST_BODY = TestDataFactory.createNotificationRequestBody(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE, TestDataFactory.GATEWAY_REF);

        Test.startTest();
        CommercePayments.GatewayNotificationResponse notificationResponse = AdyenPaymentHelper.handleAsyncNotificationCallback(null);
        Test.stopTest();

        Assert.isFalse(notificationResponse.toString().containsIgnoreCase('error'));
    }

    @IsTest
    static void successWebhookTest() {
        // given notification with related payment
        Account acct = TestDataFactory.createAccount();
        insert acct;
        TestDataFactory.insertBasicPaymentRecords(acct.Id, null);
        AdyenPaymentHelper.TEST_NOTIFICATION_REQUEST_BODY = TestDataFactory.createNotificationRequestBody(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE, TestDataFactory.TEST_PSP_REFERENCE);
        // when
        Test.startTest();
        CommercePayments.GatewayNotificationResponse notificationResponse = AdyenPaymentHelper.handleAsyncNotificationCallback(null);
        Test.stopTest();
        // then
        Assert.isFalse(notificationResponse.toString().containsIgnoreCase('error'));
    }

    @IsTest
    static void createNotificationSaveResultRefundTest() {
        // given refund fail notification
        Account acct = TestDataFactory.createAccount();
        insert acct;
        TestDataFactory.insertBasicPaymentRecords(acct.Id, null);
        NotificationRequestItem nri = TestDataFactory.createNotificationRequestItem(AdyenConstants.NOTIFICATION_REQUEST_TYPE_REFUND, TestDataFactory.TEST_PSP_REFERENCE);
        nri.success = 'false';
        // when
        Test.startTest();
        CommercePayments.NotificationSaveResult notificationSaveResult = AdyenPaymentHelper.createNotificationSaveResult(nri);
        Test.stopTest();
        // then - no matching payment found
        Assert.areEqual(400, notificationSaveResult.getStatusCode());
    }

    @IsTest
    static void createNotificationExceptionTest() {
        // given notification with unhandled type
        NotificationRequestItem nri = TestDataFactory.createNotificationRequestItem(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CANCEL, TestDataFactory.TEST_PSP_REFERENCE);
        try { // when
            AdyenPaymentHelper.createNotificationSaveResult(nri);
            Assert.fail();
        } catch (Exception ex) { // then
            Assert.isInstanceOfType(ex, AdyenGatewayAdapter.GatewayException.class);
        }
    }

    @IsTest(SeeAllData=true)
    static void callPostAuthorizeTest() {
        // Given
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        AdyenPaymentHelper.PBLPostAuthRequest postAuthRequest = new AdyenPaymentHelper.PBLPostAuthRequest();
        postAuthRequest.paymentGatewayId = null;
        postAuthRequest.accountId = testAccount.Id;
        postAuthRequest.currencyIsoCode = 'EUR';
        postAuthRequest.amount = 55.55;

        List<AdyenPaymentHelper.PBLPostAuthRequest> postAuthRequests = new List<AdyenPaymentHelper.PBLPostAuthRequest>{ postAuthRequest };
        Test.startTest();
		Test.setMock(HttpCalloutMock.class, new TestDataFactory.PBLMockResponse());
        // when
        List<AdyenPaymentHelper.PBLPostAuthResponse> postAuthResponses =  AdyenPaymentHelper.callPostAuthorize(postAuthRequests);
        Test.stopTest();

        // then
        Assert.isTrue(postAuthResponses.size() == 1);
        Assert.areEqual('https://test.payment.link', postAuthResponses[0].paymentLink);
        Assert.areEqual('2024-01-01T12:00:00+00:00', postAuthResponses[0].linkExpiresAt);
        Assert.areEqual(AdyenPBLHelper.parseDateTime('2024-01-01T12:00:00+00:00'), postAuthResponses[0].expirationDateTime);
        Assert.areEqual('PLE5B4575C5A026A2B2', postAuthResponses[0].paymentLinkId);
    }
}