@IsTest
private class AdyenPaymentHelperTest {
    @IsTest
    static void handleAsyncNotificationCallbackSkippedTest() {
        AdyenPaymentHelper.TEST_NOTIFICATION_REQUEST_BODY = TestDataFactory.createNotificationRequestBody('CAPTURE', null);

        Test.startTest();
        CommercePayments.GatewayNotificationResponse captureResponse = AdyenPaymentHelper.handleAsyncNotificationCallback(null, 'AdyenAsyncAdapter');
        Test.stopTest();

        Assert.isFalse(captureResponse.toString().containsIgnoreCase('error'));
    }

    @IsTest
    static void handleAsyncNotificationCallbackNotProcessedTest() {
        AdyenPaymentHelper.TEST_NOTIFICATION_REQUEST_BODY = TestDataFactory.createNotificationRequestBody('CAPTURE', TestDataFactory.GATEWAY_REF);

        Test.startTest();
        CommercePayments.GatewayNotificationResponse captureResponse = AdyenPaymentHelper.handleAsyncNotificationCallback(null, 'AdyenAsyncAdapter');
        Test.stopTest();

        Assert.isFalse(captureResponse.toString().containsIgnoreCase('error'));
    }

    @IsTest
    static void createNotificationSaveResultTest() {
        NotificationRequestItem nri = TestDataFactory.createNotificationRequestItem(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE, 'abc123');

        Test.startTest();
        CommercePayments.NotificationSaveResult notificationSaveResult = AdyenPaymentHelper.createNotificationSaveResult(nri);
        Test.stopTest();

        Assert.areEqual(400, notificationSaveResult.getStatusCode());
    }
}