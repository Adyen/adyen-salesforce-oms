@isTest
private class AdyenAsyncAdapterTest {
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
        CommercePayments.CaptureRequest captureRequest = new CommercePayments.CaptureRequest(TestDataFactory.TEST_AMOUNT, authId);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(captureRequest, CommercePayments.RequestType.Capture);
        CommercePayments.GatewayResponse captureResponse = (CommercePayments.GatewayResponse) TestDataFactory.adyenAdapter.processRequest(context);
        Test.stopTest();

        Assert.isTrue(captureResponse.toString().contains('[capture-received]'));
        Assert.isTrue(captureResponse.toString().contains(TestDataFactory.TEST_PSP_REFERENCE));
    }
    
    @IsTest
    static void testCaptureOutboundFailure() {
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());

        Test.startTest();
        AdyenPaymentUtility.skipMerchantAccount = true;
        Id authId = [SELECT Id FROM PaymentAuthorization ORDER BY CreatedDate DESC LIMIT 1].Id;
        CommercePayments.CaptureRequest captureRequest = new CommercePayments.CaptureRequest(TestDataFactory.TEST_AMOUNT, authId);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(captureRequest, CommercePayments.RequestType.Capture);
        CommercePayments.GatewayResponse captureResponse = (CommercePayments.GatewayResponse) TestDataFactory.adyenAdapter.processRequest(context);
        Test.stopTest();

        Assert.isTrue(captureResponse.toString().contains('SYSTEMERROR'));
    }
    
    @IsTest
    static void testCaptureOutboundMissingPaymentAuthorization() {
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());
        try {
            Test.startTest();
            CommercePayments.CaptureRequest captureRequest = new CommercePayments.CaptureRequest(TestDataFactory.TEST_AMOUNT, null);
            CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(captureRequest, CommercePayments.RequestType.Capture);
            CommercePayments.GatewayResponse captureResponse = (CommercePayments.GatewayResponse) TestDataFactory.adyenAdapter.processRequest(context);
            Test.stopTest();
            Assert.fail('Exception expected');
        } catch(Exception ex) {
            Assert.areEqual('Payment Authorization Missing', ex.getMessage(), 'Payment Authorization is available');
        }
    }
    
    @IsTest
    static void testCaptureOutboundMissingAmount() {
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());
        Id authId = [SELECT Id FROM PaymentAuthorization ORDER BY CreatedDate DESC LIMIT 1].Id;
        try {
            Test.startTest();
            CommercePayments.CaptureRequest captureRequest = new CommercePayments.CaptureRequest(null, authId);
            CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(captureRequest, CommercePayments.RequestType.Capture);
            CommercePayments.GatewayResponse captureResponse = (CommercePayments.GatewayResponse) TestDataFactory.adyenAdapter.processRequest(context);
            Test.stopTest();
            Assert.fail('Exception expected');
        } catch(Exception ex) {
            Assert.areEqual('Payment Amount Missing', ex.getMessage(), 'Payment Amount is available.');
        }
    }
    
    @IsTest
    static void testCaptureInboundSuccess() {
        AdyenPaymentHelper.TEST_NOTIFICATION_REQUEST_BODY = TestDataFactory.createNotificationRequestBody('CAPTURE', TestDataFactory.GATEWAY_REF);

        Test.startTest();
        CommercePayments.GatewayNotificationResponse captureResponse = TestDataFactory.adyenAdapter.processNotification(null);
        Test.stopTest();
        
        Assert.isFalse(captureResponse.toString().containsIgnoreCase('error'));
    }
    
    @IsTest
    static void testRefundInboundSuccess() {
        AdyenPaymentHelper.TEST_NOTIFICATION_REQUEST_BODY = TestDataFactory.createNotificationRequestBody('REFUND', TestDataFactory.GATEWAY_REF);

        Test.startTest();
        CommercePayments.GatewayNotificationResponse captureResponse = TestDataFactory.adyenAdapter.processNotification(null);
        Test.stopTest();
        
        Assert.isFalse(captureResponse.toString().containsIgnoreCase('error'));
    }
    
    @IsTest
    static void testRefundOutboundSuccess() {
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());

        Test.startTest();
        Id paymentId = [SELECT Id FROM Payment ORDER BY CreatedDate DESC LIMIT 1].Id;
        CommercePayments.ReferencedRefundRequest refundRequest = new CommercePayments.ReferencedRefundRequest(TestDataFactory.TEST_AMOUNT, paymentId);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(refundRequest, CommercePayments.RequestType.ReferencedRefund);
        CommercePayments.GatewayResponse refundResponse = (CommercePayments.GatewayResponse) TestDataFactory.adyenAdapter.processRequest(context);
        Test.stopTest();

        Assert.isTrue(refundResponse.toString().contains(TestDataFactory.TEST_SHOPPER_REFERENCE));
    }
    
    @IsTest
    static void testRefundOutboundFailure() {
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());

        Test.startTest();
        AdyenPaymentUtility.skipMerchantAccount = true;
        Id paymentId = [SELECT Id FROM Payment ORDER BY CreatedDate DESC LIMIT 1].Id;
        CommercePayments.ReferencedRefundRequest refundRequest = new CommercePayments.ReferencedRefundRequest(TestDataFactory.TEST_AMOUNT, paymentId);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(refundRequest, CommercePayments.RequestType.ReferencedRefund);
        CommercePayments.GatewayResponse refundResponse = (CommercePayments.GatewayResponse) TestDataFactory.adyenAdapter.processRequest(context);
        Test.stopTest();

        Assert.isTrue(refundResponse.toString().contains('SYSTEMERROR'));
    }
    
    @IsTest
    static void testRefundOutboundMissingPayment() {
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());
        try {
            Test.startTest();
            CommercePayments.ReferencedRefundRequest refundRequest = new CommercePayments.ReferencedRefundRequest(TestDataFactory.TEST_AMOUNT, null);
            CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(refundRequest, CommercePayments.RequestType.ReferencedRefund);
            CommercePayments.GatewayResponse refundResponse = (CommercePayments.GatewayResponse) TestDataFactory.adyenAdapter.processRequest(context);
            Test.stopTest();
            Assert.fail('Exception expected');
        } catch(Exception ex) {
            Assert.areEqual('Payment Info Missing', ex.getMessage(), 'Payment Info is available.');
        }
    }
    
    @IsTest
    static void testRefundOutboundMissingAmount() {
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());
        Id paymentId = [SELECT Id FROM Payment ORDER BY CreatedDate DESC LIMIT 1].Id;
        try {
            Test.startTest();
            CommercePayments.ReferencedRefundRequest refundRequest = new CommercePayments.ReferencedRefundRequest(null, paymentId);
            CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(refundRequest, CommercePayments.RequestType.ReferencedRefund);
            CommercePayments.GatewayResponse refundResponse = (CommercePayments.GatewayResponse) TestDataFactory.adyenAdapter.processRequest(context);
            Test.stopTest();
            Assert.fail('Exception expected');
        } catch(Exception ex) {
            Assert.areEqual('Payment Amount Missing', ex.getMessage(), 'Payment Amount is available.');
        }
    }
}