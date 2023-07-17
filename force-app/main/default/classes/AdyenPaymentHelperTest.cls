@isTest
private class AdyenPaymentHelperTest {
    @isTest
    static void handleAsyncNotificationCallbackAcceptedTest() {
        AdyenPaymentHelper.TEST_NOTIFICATION_REQUEST_BODY = TestDataFactory.createNotificationRequestBody('CAPTURE', TestDataFactory.GATEWAY_REF);

        PaymentGatewayProvider payGatProvider = [SELECT ApexAdapterId FROM PaymentGatewayProvider WHERE ApexAdapterId != NULL LIMIT 1];
        PaymentGateway payGateway = TestDataFactory.createPaymentGateway();
        payGateway.PaymentGatewayProviderId = payGatProvider.Id;
        insert payGateway;
        PaymentAuthorization payAuth = TestDataFactory.createPaymentAuthorization(null, null, payGateway.Id, null);
        payAuth.GatewayRefNumber = TestDataFactory.GATEWAY_REF;
        insert payAuth;

        Test.startTest();
        CommercePayments.GatewayNotificationResponse captureResponse = AdyenPaymentHelper.handleAsyncNotificationCallback(null, 'AdyenAsyncAdapter');
        Test.stopTest();

        Assert.isFalse(captureResponse.toString().containsIgnoreCase('error'));
    }

    @isTest
    static void handleAsyncNotificationCallbackSkippedTest() {
        AdyenPaymentHelper.TEST_NOTIFICATION_REQUEST_BODY = TestDataFactory.createNotificationRequestBody('CAPTURE', null);

        Test.startTest();
        CommercePayments.GatewayNotificationResponse captureResponse = AdyenPaymentHelper.handleAsyncNotificationCallback(null, 'AdyenAsyncAdapter');
        Test.stopTest();

        Assert.isFalse(captureResponse.toString().containsIgnoreCase('error'));
    }

    @isTest
    static void handleAsyncNotificationCallbackNotProcessedTest() {
        AdyenPaymentHelper.TEST_NOTIFICATION_REQUEST_BODY = TestDataFactory.createNotificationRequestBody('CAPTURE', TestDataFactory.GATEWAY_REF);

        Test.startTest();
        CommercePayments.GatewayNotificationResponse captureResponse = AdyenPaymentHelper.handleAsyncNotificationCallback(null, 'AdyenAsyncAdapter');
        Test.stopTest();

        Assert.isFalse(captureResponse.toString().containsIgnoreCase('error'));
    }
}