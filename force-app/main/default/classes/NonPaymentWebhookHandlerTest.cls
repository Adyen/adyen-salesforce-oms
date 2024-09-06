@IsTest
private class NonPaymentWebhookHandlerTest {

    @IsTest
    static void unsupportedNotificationTypeTest() {
        // given unsupported notification type (not a cancellation)
        String wrongWebhookType = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE, '1234567890123456', '1010101010101010', '999999', true);
        RestRequest req = createRestRequest();
        req.requestBody = Blob.valueOf(wrongWebhookType);
        RestContext.request = req;

        // when
        Test.startTest();
        String response = NonPaymentWebhookHandler.doPost();
        Test.stopTest();

        // then
        Assert.isNotNull(response);
        Assert.istrue(response.containsIgnoreCase('webhook type was ignored'));
    }

    @IsTest
    static void notificationWithInvalidPspTest() {
        // given invalid pspReference in notification
        String invalidWebhook = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE, '111', '222', '999999', true);
        RestRequest req = createRestRequest();
        req.requestBody = Blob.valueOf(invalidWebhook);
        RestContext.request = req;

        // when
        Test.startTest();
        String response = NonPaymentWebhookHandler.doPost();
        Test.stopTest();

        // then
        Assert.isNotNull(response);
        Assert.istrue(response.containsIgnoreCase('no valid psp reference found'));
    }

    @IsTest(SeeAllData=true)
    static void notificationWithMissingPaymentAuthTest() {
        // given valid cancellation webhook but no related payment found
        Account acct = TestDataFactory.createAccount();
        insert acct;
        Order order = TestDataFactory.insertOrderAndRelatedRecords(acct.Id, 33.42, 0.96);
        OrderPaymentSummary orderPaymentSummary = TestDataFactory.createOrderSummaryRecords(order.Id);
        PaymentAuthorization payAuth = TestDataFactory.createPaymentAuthorization(acct.Id, null, null, orderPaymentSummary.Id, null);
        insert payAuth;
        String validWebhook = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CANCEL, '123456789012ABCD','101010101010ABCD', '999999', true);
        RestRequest req = createRestRequest();
        req.requestBody = Blob.valueOf(validWebhook);
        RestContext.request = req;

        // when
        Test.startTest();
        String response = NonPaymentWebhookHandler.doPost();
        Test.stopTest();

        // then
        Assert.isNotNull(response);
        Assert.istrue(response.containsIgnoreCase('no related payment record found'));
    }

    @IsTest(SeeAllData = true)
    static void successfulCancellationNotificationTest() {
        // given valid cancellation with a related PaymentAuthorization
        Account acct = TestDataFactory.createAccount();
        insert acct;
        Order order = TestDataFactory.insertOrderAndRelatedRecords(acct.Id, 33.42, 0.96);
        OrderPaymentSummary orderPaymentSummary = TestDataFactory.createOrderSummaryRecords(order.Id);
        PaymentAuthorization payAuth = TestDataFactory.createPaymentAuthorization(acct.Id, null, null, orderPaymentSummary.Id, '101010101010ABCD');
        insert payAuth;

        String validWebhook = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CANCEL, '123456789012ABCD', '101010101010ABCD', '999999', true);
        RestRequest req = createRestRequest();
        req.requestBody = Blob.valueOf(validWebhook);
        RestContext.request = req;

        // when
        Test.startTest();
        String response = NonPaymentWebhookHandler.doPost();
        Test.stopTest();

        // then
        Assert.isNotNull(response, 'Response should not be null');
        Assert.areEqual('[accepted]', response, 'Expected accepted response');
        PaymentGatewayLog log = [SELECT Id, InteractionStatus, OrderPaymentSummaryId FROM PaymentGatewayLog WHERE ReferencedEntityId = :payAuth.Id LIMIT 1];
        Assert.areEqual('Success', log.InteractionStatus, 'Expected interaction status to be Success.');
        Assert.areEqual(orderPaymentSummary.Id, log.OrderPaymentSummaryId, 'PaymentGatewayLog should be related to OrderPaymentSummary');
    }

    @IsTest(SeeAllData = true)
    static void failedCancellationNotificationTest() {
            // given failed cancellation with a related PaymentAuthorization
            Account acct = TestDataFactory.createAccount();
            insert acct;
            Order order = TestDataFactory.insertOrderAndRelatedRecords(acct.Id, 33.42, 0.96);
            OrderPaymentSummary orderPaymentSummary = TestDataFactory.createOrderSummaryRecords(order.Id);
            PaymentAuthorization payAuth = TestDataFactory.createPaymentAuthorization(acct.Id, null, null, orderPaymentSummary.Id, '101010101010ABCD');
            insert payAuth;
    
            String validWebhook = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CANCEL, '123456789012ABCD', '101010101010ABCD', '999999', false);
            RestRequest req = createRestRequest();
            req.requestBody = Blob.valueOf(validWebhook);
            RestContext.request = req;
    
            // when
            Test.startTest();
            String response = NonPaymentWebhookHandler.doPost();
            Test.stopTest();
    
            // then
            Assert.isNotNull(response, 'Response should not be null');
            Assert.areEqual('[accepted]', response, 'Expected accepted response');
            PaymentGatewayLog log = [SELECT Id, InteractionStatus, OrderPaymentSummaryId FROM PaymentGatewayLog WHERE ReferencedEntityId = :payAuth.Id LIMIT 1];
            Assert.areEqual('Failed', log.InteractionStatus, 'Expected interaction status to be Failed.');
            Assert.areEqual(orderPaymentSummary.Id, log.OrderPaymentSummaryId, 'PaymentGatewayLog should be related to OrderPaymentSummary');
    }

    @IsTest
    static void invalidNotificationRequestTest() {
        // given an invalid request to trigger an exception
        RestRequest req = createRestRequest();
        req.requestBody = Blob.valueOf('invalid_body');
        RestContext.request = req;

        // when
        Test.startTest();
        String response = NonPaymentWebhookHandler.doPost();
        Test.stopTest();

        // then
        Assert.isNotNull(response);
        Assert.isTrue(response.containsIgnoreCase('exception'));
    }

    private static RestRequest createRestRequest() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/nonPaymentWebhook/v1/';
        req.httpMethod = 'POST';
        return req;
    }
}
