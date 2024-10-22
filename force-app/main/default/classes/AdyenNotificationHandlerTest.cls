@IsTest
private class AdyenNotificationHandlerTest {
    @IsTest
    static void notValidWebhookTest() {
        AdyenNotificationHandler.TEST_NOTIFICATION_REQUEST_BODY = TestDataFactory.createNotificationRequestBody(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE, null);

        Test.startTest();
        CommercePayments.GatewayNotificationResponse notificationResponse = AdyenNotificationHandler.handleAsyncNotificationCallback(null);
        Test.stopTest();

        Assert.isFalse(notificationResponse.toString().containsIgnoreCase('error'));
    }

    @IsTest
    static void noRelatedPaymentWebhookTest() {
        AdyenNotificationHandler.TEST_NOTIFICATION_REQUEST_BODY = TestDataFactory.createNotificationRequestBody(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE, TestDataFactory.GATEWAY_REF);

        Test.startTest();
        CommercePayments.GatewayNotificationResponse notificationResponse = AdyenNotificationHandler.handleAsyncNotificationCallback(null);
        Test.stopTest();

        Assert.isFalse(notificationResponse.toString().containsIgnoreCase('error'));
    }

    @IsTest
    static void successWebhookTest() {
        // given notification with related payment
        Account acct = TestDataFactory.createAccount();
        insert acct;
        TestDataFactory.insertBasicPaymentRecords(acct.Id, null);
        AdyenNotificationHandler.TEST_NOTIFICATION_REQUEST_BODY = TestDataFactory.createNotificationRequestBody(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE, TestDataFactory.TEST_PSP_REFERENCE);
        // when
        Test.startTest();
        CommercePayments.GatewayNotificationResponse notificationResponse = AdyenNotificationHandler.handleAsyncNotificationCallback(null);
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
        CommercePayments.NotificationSaveResult notificationSaveResult = AdyenNotificationHandler.createNotificationSaveResult(nri);
        Test.stopTest();
        // then - no matching payment found
        Assert.areEqual(400, notificationSaveResult.getStatusCode());
    }

    @IsTest
    static void createNotificationExceptionTest() {
        // given notification with unhandled type
        NotificationRequestItem nri = TestDataFactory.createNotificationRequestItem(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CANCEL, TestDataFactory.TEST_PSP_REFERENCE);
        try { // when
            AdyenNotificationHandler.createNotificationSaveResult(nri);
            Assert.fail();
        } catch (Exception ex) { // then
            Assert.isInstanceOfType(ex, AdyenGatewayAdapter.GatewayException.class);
        }
    }
}