@IsTest
private class AdyenGatewayAdapterTest {
    @TestSetup
    static void makeData() {
        Account acct = TestDataFactory.createAccount();
        insert acct;
        TestDataFactory.insertBasicPaymentRecords(acct.Id, null);
    }

    @IsTest
    static void testCaptureOutboundSuccess() {
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());

        Test.startTest();
        Id authId = [SELECT Id FROM PaymentAuthorization ORDER BY CreatedDate DESC LIMIT 1].Id;
        CommercePayments.CaptureRequest captureRequest = new CommercePayments.CaptureRequest(TestDataFactory.TEST_PRICE_AMOUNT, authId);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(captureRequest, CommercePayments.RequestType.Capture);
        CommercePayments.GatewayResponse captureResponse = TestDataFactory.adyenAdapter.processRequest(context);
        Test.stopTest();

        Assert.isTrue(captureResponse.toString().contains('[capture-received]'));
        Assert.isTrue(captureResponse.toString().contains(TestDataFactory.TEST_PSP_REFERENCE));
    }

    @IsTest
    static void testCaptureOutboundFailure() {
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.FailureResponse());

        Test.startTest();
        Id authId = [SELECT Id FROM PaymentAuthorization ORDER BY CreatedDate DESC LIMIT 1].Id;
        CommercePayments.CaptureRequest captureRequest = new CommercePayments.CaptureRequest(TestDataFactory.TEST_PRICE_AMOUNT, authId);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(captureRequest, CommercePayments.RequestType.Capture);
        CommercePayments.GatewayResponse gatewayResponse = TestDataFactory.adyenAdapter.processRequest(context);
        Test.stopTest();

        Assert.isInstanceOfType(gatewayResponse, CommercePayments.GatewayErrorResponse.class);
        Assert.isTrue(gatewayResponse.toString().containsIgnoreCase('400'));
    }

    @IsTest
    static void testCaptureOutboundMissingPaymentAuthorization() {
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());

        Test.startTest();
        CommercePayments.CaptureRequest captureRequest = new CommercePayments.CaptureRequest(TestDataFactory.TEST_PRICE_AMOUNT, null);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(captureRequest, CommercePayments.RequestType.Capture);
        CommercePayments.GatewayResponse gatewayResponse = TestDataFactory.adyenAdapter.processRequest(context);
        Test.stopTest();

        Assert.isInstanceOfType(gatewayResponse, CommercePayments.GatewayErrorResponse.class);
        Assert.isTrue(gatewayResponse.toString().containsIgnoreCase(AdyenPaymentUtility.NO_PAYMENT_AUTH_FOUND_BY_ID));
    }

    @IsTest
    static void testCaptureOutboundMissingAmount() {
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());
        Id authId = [SELECT Id FROM PaymentAuthorization ORDER BY CreatedDate DESC LIMIT 1].Id;
        Test.startTest();
        CommercePayments.CaptureRequest captureRequest = new CommercePayments.CaptureRequest(null, authId);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(captureRequest, CommercePayments.RequestType.Capture);
        CommercePayments.GatewayResponse gatewayResponse = TestDataFactory.adyenAdapter.processRequest(context);
        Test.stopTest();
        Assert.isInstanceOfType(gatewayResponse, CommercePayments.GatewayErrorResponse.class);
        Assert.isTrue(gatewayResponse.toString().containsIgnoreCase('Payment Amount Missing'));
    }

    @IsTest
    static void testRefundOutboundSuccess() {
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());

        Test.startTest();
        Id paymentId = [SELECT Id FROM Payment ORDER BY CreatedDate DESC LIMIT 1].Id;
        CommercePayments.ReferencedRefundRequest refundRequest = new CommercePayments.ReferencedRefundRequest(TestDataFactory.TEST_PRICE_AMOUNT, paymentId);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(refundRequest, CommercePayments.RequestType.ReferencedRefund);
        CommercePayments.GatewayResponse refundResponse = TestDataFactory.adyenAdapter.processRequest(context);
        Test.stopTest();

        Assert.isTrue(refundResponse.toString().contains('received'));
    }

    @IsTest
    static void testRefundOutboundFailure() {
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.FailureResponse());

        Test.startTest();
        Id paymentId = [SELECT Id FROM Payment ORDER BY CreatedDate DESC LIMIT 1].Id;
        CommercePayments.ReferencedRefundRequest refundRequest = new CommercePayments.ReferencedRefundRequest(TestDataFactory.TEST_PRICE_AMOUNT, paymentId);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(refundRequest, CommercePayments.RequestType.ReferencedRefund);
        CommercePayments.GatewayResponse refundResponse = TestDataFactory.adyenAdapter.processRequest(context);
        Test.stopTest();

        Assert.isInstanceOfType(refundResponse, CommercePayments.GatewayErrorResponse.class);
        Assert.isTrue(refundResponse.toString().containsIgnoreCase('400'));
    }

    @IsTest
    static void testRefundOutboundMissingPayment() {
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());
        Test.startTest();
        CommercePayments.ReferencedRefundRequest refundRequest = new CommercePayments.ReferencedRefundRequest(TestDataFactory.TEST_PRICE_AMOUNT, null);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(refundRequest, CommercePayments.RequestType.ReferencedRefund);
        CommercePayments.GatewayResponse gatewayResponse = TestDataFactory.adyenAdapter.processRequest(context);
        Test.stopTest();
        Assert.isInstanceOfType(gatewayResponse, CommercePayments.GatewayErrorResponse.class);
        Assert.isTrue(gatewayResponse.toString().containsIgnoreCase(AdyenPaymentUtility.NO_PAYMENT_FOUND_BY_ID));
    }

    @IsTest
    static void testRefundOutboundMissingAmount() {
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());
        Id paymentId = [SELECT Id FROM Payment ORDER BY CreatedDate DESC LIMIT 1].Id;
        Test.startTest();
        CommercePayments.ReferencedRefundRequest refundRequest = new CommercePayments.ReferencedRefundRequest(null, paymentId);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(refundRequest, CommercePayments.RequestType.ReferencedRefund);
        CommercePayments.GatewayResponse gatewayResponse = TestDataFactory.adyenAdapter.processRequest(context);
        Test.stopTest();
        Assert.isInstanceOfType(gatewayResponse, CommercePayments.GatewayErrorResponse.class);
        Assert.isTrue(gatewayResponse.toString().containsIgnoreCase('Payment Amount Missing'));
    }
}