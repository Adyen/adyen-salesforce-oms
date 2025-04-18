@IsTest
private class AdyenWebhookNotificationHandlerTest {

    @IsTest(SeeAllData=true)
    static void omsNotificationSuccessTest() {
        // given
        OrderPaymentSummary ops = TestDataFactory.insertAccountAndOrderPaymentSummary();
        CardPaymentMethod paymentMethod = TestDataFactory.createCardPaymentMethod();
        insert paymentMethod;
       	Payment payment = TestDataFactory.createPayment(null, paymentMethod.Id, null, null, ops.Id);
        payment.GatewayRefNumber = '123456789012ABCD';
		insert payment;
        String requestBody = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE, '123456789012ABCD', TestDataFactory.TEST_PSP_REFERENCE, '999999', true);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse('[accepted]', 200));

        // when
        Test.startTest();
        RestRequest req = createRestRequest(requestBody);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        AdyenWebhookNotificationHandler.handleWebhookNotification();
        Test.stopTest();

        // Assert
        Assert.areEqual(200, res.statusCode);
        Assert.areEqual('[accepted]', res.responseBody.toString());
    }

    @IsTest
    static void omsNotificationErrorTest() {
        // given
        String errorJson = '[{"message":"Gateway error occurred","errorCode":"UNKNOWN"}]';
        String requestBody = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE, '123456789012ABCD', TestDataFactory.TEST_PSP_REFERENCE, '999999', true);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(errorJson, 500));

        // when
        Test.startTest();
        RestRequest req = createRestRequest(requestBody);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        AdyenWebhookNotificationHandler.handleWebhookNotification();
        Test.stopTest();

        // then
        Assert.areEqual(500, res.statusCode);
        Assert.areEqual('Error: Gateway error occurred', res.responseBody.toString());
    }

   

    @IsTest
    static void nonPaymentNotificationSuccessTest() {
        // given
        String requestBody = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CANCEL, '123456789012ABCD', TestDataFactory.TEST_PSP_REFERENCE, '999999', true);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse('[accepted]', 200));

        // when
        Test.startTest();
        RestRequest req = createRestRequest(requestBody);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        AdyenWebhookNotificationHandler.handleWebhookNotification();
        Test.stopTest();

        // then
        Assert.areEqual(200, res.statusCode);
        Assert.areEqual('[accepted]', res.responseBody.toString());
    }

    private static RestRequest createRestRequest(String body) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/adyenNotification/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        return req;
    }

    private class MockHttpResponse implements HttpCalloutMock {
        private String responseBody;
        private Integer statusCode;

        public MockHttpResponse(String responseBody, Integer statusCode) {
            this.responseBody = responseBody;
            this.statusCode = statusCode;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setBody(this.responseBody);
            res.setStatusCode(this.statusCode);
            return res;
        }
    }
}