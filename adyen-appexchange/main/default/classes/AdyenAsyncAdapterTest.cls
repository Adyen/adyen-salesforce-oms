/**
 *   @todo this really needs asserts badly but how do we work with the return from the adapter?
 */
@IsTest
private class AdyenAsyncAdapterTest {

    public class MyException extends Exception{}

    class EchoHttpMock implements HttpCalloutMock {
            HttpResponse res;
            EchoHttpMock(HttpResponse r) {
                res = r;
            }
            // This is the HttpCalloutMock interface method
            public HttpResponse respond(HttpRequest req) {
                    System.debug('--->Entering EchoHttpMock.respond');
                    if(req.getBody().contains('420')){
                            System.debug('--->Exiting EchoHttpMock.respond, throwing exception');
                            throw new MyException('network exception');
                    } else{
                            System.debug('--->Exiting EchoHttpMock.respond, returning response=' + res);
                            return res;
                    }
            }
    }

    /**
     * @see https://docs.adyen.com/api-explorer/#/Payment/v52/capture
     */
    @IsTest
    static void testCapture_Outbound_Success() {

        String mockPostCaptureResponse = '{"pspReference": "853587067740652G","response": "[capture-received]"}';

        HttpResponse res = new HttpResponse();
        res.setBody(mockPostCaptureResponse);
        res.setStatusCode(200);
        Test.setMock(HttpCalloutMock.class, new EchoHttpMock(res));

        // @todo add OrderPaymentSummary - PaymentGroup,  PaymentGateway, PaymentGatewayProvider (with AdyenAsyncAdapter apex id?), CardPaymentMethod, 
        //PaymentAuthorization paymentAuthorization = TestDataFactory.createPaymentAuthorization();
        //insert paymentAuthorization;

        Test.startTest();

        Double amt = 500;
        String authId;

        CommercePayments.CaptureRequest captureRequest = new CommercePayments.CaptureRequest(amt, authId);

        CommercePayments.PaymentGatewayContext context =
                new CommercePayments.PaymentGatewayContext(captureRequest, CommercePayments.RequestType.Capture);

        AdyenAsyncAdapter adyenAdapter = new AdyenAsyncAdapter();
        CommercePayments.CaptureResponse captureResponse = (CommercePayments.CaptureResponse) adyenAdapter.processRequest(context);

        // @todo As of v48 the return from processRequest is an Abstract Class ie. CommercePayments.GatewayResponse. How to do work with this for asserts?
        // response from process request. =CaptureResponse:[AbstractResponse.delegate=CaptureGatewayResponse [toString()=AbstractGatewayTxnResponse [gatewayReferenceNumber=SF390426, gatewayReferenceDetails=null, amount=500.0]], AbstractTransactionResponse.delegate=CaptureGatewayResponse [toString()=AbstractGatewayTxnResponse [gatewayReferenceNumber=SF390426, gatewayReferenceDetails=null, amount=500.0]], delegate=CaptureGatewayResponse [toString()=AbstractGatewayTxnResponse [gatewayReferenceNumber=SF390426, gatewayReferenceDetails=null, amount=500.0]]]
        System.debug('outputting response from process request. =' + captureResponse.toString());

        //captureResponse.

        Test.stopTest();
        System.Assert(captureResponse.toString().contains('853587067740652G'));
    }

    /**
     * @see https://docs.adyen.com/api-explorer/#/Payment/v52/capture
     */
    @IsTest
    static void testCapture_Outbound_Failure() {

        String mockPostCaptureResponse = '{"status":422,"errorCode":"167","message":"Original pspReference required for this operation","errorType":"validation"}';
        
        HttpResponse res = new HttpResponse();
        res.setBody(mockPostCaptureResponse);
        res.setStatusCode(422);
        
        Test.setMock(HttpCalloutMock.class, new EchoHttpMock(res));
        Test.startTest();

        Double amt = 500;
        String authId;

        CommercePayments.CaptureRequest captureRequest = new CommercePayments.CaptureRequest(amt, authId);

        CommercePayments.PaymentGatewayContext context =
                new CommercePayments.PaymentGatewayContext(captureRequest, CommercePayments.RequestType.Capture);

        AdyenAsyncAdapter adyenAdapter = new AdyenAsyncAdapter();
        CommercePayments.CaptureResponse captureResponse = (CommercePayments.CaptureResponse) adyenAdapter.processRequest(context);

        System.debug('outputting response from process request. =' + captureResponse.toString());

        //captureResponse.

        Test.stopTest();

        System.Assert(captureResponse.toString().contains('Original pspReference required for this operation'));
        
    }


    @IsTest
    static void testCapture_Outbound_NetworkFailure() {

        // invalid json from adyen
        
        String mockPostCaptureResponse = '{"status":500,"errorCode":"167","message":"exception","errorType":"validation"}';

        HttpResponse res = new HttpResponse();
        res.setBody(mockPostCaptureResponse);
        res.setStatusCode(500);
        
        Test.setMock(HttpCalloutMock.class, new EchoHttpMock(res));
        Test.startTest();

        Double amt = 420;
        String authId;
        CommercePayments.CaptureRequest captureRequest = new CommercePayments.CaptureRequest(amt, authId);
        CommercePayments.PaymentGatewayContext context =
                new CommercePayments.PaymentGatewayContext(captureRequest, CommercePayments.RequestType.Capture);

        AdyenAsyncAdapter adyenAdapter = new AdyenAsyncAdapter();
        CommercePayments.CaptureResponse captureResponse = (CommercePayments.CaptureResponse)adyenAdapter.processRequest(context);
        //  @todo As of v48 the return from processRequest is an Abstract Class ie. CommercePayments.GatewayResponse. How to do work with this for asserts?
        System.debug('outputting response from process request. ='+captureResponse.toString());

        Test.stopTest();
        System.Assert(captureResponse.toString().contains('network exception'));
    }

    /**
     * @see https://docs.adyen.com/api-explorer/#/Payment/v52/refund
     */
    @IsTest
    static void testRefund_Outbound_Success() {

        String mockPostRefundResponse = '  {"pspReference": "853587067740652G","response": "[refund-received]"}';

        HttpResponse res = new HttpResponse();
        res.setBody(mockPostRefundResponse);
        res.setStatusCode(200);
        Test.setMock(HttpCalloutMock.class, new EchoHttpMock(res));

        Test.startTest();

        Double amt = 500;
        String authId;

        CommercePayments.ReferencedRefundRequest refundRequest = new CommercePayments.ReferencedRefundRequest(amt, authId);
        CommercePayments.PaymentGatewayContext context =
                new CommercePayments.PaymentGatewayContext(refundRequest, CommercePayments.RequestType.ReferencedRefund);

        AdyenAsyncAdapter adyenAdapter = new AdyenAsyncAdapter();
        CommercePayments.ReferencedRefundResponse refundResponse = (CommercePayments.ReferencedRefundResponse)adyenAdapter.processRequest(context);

        PaymentAuthorization pa = AdyenPaymentUtility.retrievePaymentAuthorization(authId);
        Boolean isKlarnaOrder = AdyenPaymentUtility.checkIfKlarnaOrderFromAuthorization(pa);

        //  @todo As of v48 the return from processRequest is an Abstract Class ie. CommercePayments.GatewayResponse. How to do work with this for asserts?
        System.debug('outputting response from process request. ='+refundResponse.toString());

        Test.stopTest();
        System.Assert(refundResponse.toString().contains('853587067740652G'));
    }

    /**
     * @see https://docs.adyen.com/api-explorer/#/Payment/v52/refund
     */
    @IsTest
    static void testRefund_Outbound_Failure() {

        String mockPostRefundResponse = '{"status":422,"errorCode":"167","message":"Original pspReference required for this operation","errorType":"validation"}';

        HttpResponse res = new HttpResponse();
        res.setBody(mockPostRefundResponse);
        res.setStatusCode(422);
        Test.setMock(HttpCalloutMock.class, new EchoHttpMock(res));

        Test.startTest();

        Double amt = 500;
        String authId;

        CommercePayments.ReferencedRefundRequest refundRequest = new CommercePayments.ReferencedRefundRequest(amt, authId);
        CommercePayments.PaymentGatewayContext context =
                new CommercePayments.PaymentGatewayContext(refundRequest, CommercePayments.RequestType.ReferencedRefund);

        AdyenAsyncAdapter adyenAdapter = new AdyenAsyncAdapter();
        CommercePayments.ReferencedRefundResponse refundResponse = (CommercePayments.ReferencedRefundResponse)adyenAdapter.processRequest(context);

        //  @todo As of v48 the return from processRequest is an Abstract Class ie. CommercePayments.GatewayResponse. How to do work with this for asserts?
        System.debug('outputting response from process request. ='+refundResponse.toString());

        Test.stopTest();
        System.Assert(refundResponse.toString().contains('Original pspReference required for this operation'));
    }

    /**
     * @see https://docs.adyen.com/api-explorer/#/Payment/v52/refund
     */
    @IsTest
    static void testRefund_Outbound_NetworkFailure() {

        String mockPostRefundResponse = '{"status":500,"errorCode":"167","message":"exception","errorType":"validation"}';

        HttpResponse res = new HttpResponse();
        res.setBody(mockPostRefundResponse);
        res.setStatusCode(500);
        Test.setMock(HttpCalloutMock.class, new EchoHttpMock(res));

        Test.startTest();

        Double amt = 420;
        String authId;

        CommercePayments.ReferencedRefundRequest refundRequest = new CommercePayments.ReferencedRefundRequest(amt, authId);
        CommercePayments.PaymentGatewayContext context =
                new CommercePayments.PaymentGatewayContext(refundRequest, CommercePayments.RequestType.ReferencedRefund);

        AdyenAsyncAdapter adyenAdapter = new AdyenAsyncAdapter();
        CommercePayments.ReferencedRefundResponse refundResponse = (CommercePayments.ReferencedRefundResponse)adyenAdapter.processRequest(context);

        //  @todo As of v48 the return from processRequest is an Abstract Class ie. CommercePayments.GatewayResponse. How to do work with this for asserts?
        System.debug('outputting response from process request. ='+refundResponse.toString());

        Test.stopTest();
        System.Assert(refundResponse.toString().contains('network exception'));
    }



   /**
    * @see https://docs.adyen.com/api-explorer/#/Payment/v52/capture
    */
    @IsTest
    static void testCapture_Inbound_Positive() {

        //Build an object that will be coming back from adyen and serialize it as mock response json.
        AdyenService.AdyenNotification mockNotification = new AdyenService.AdyenNotification();
        mockNotification.live = 'false';
        mockNotification.notificationItems = new List<AdyenService.NotificationItems>();
        AdyenService.NotificationRequestItem notificationRequestItem = new AdyenService.NotificationRequestItem();
        AdyenService.Amount amount = new AdyenService.Amount();
        amount.value = 100;
        amount.currency_x = 'USD';
        notificationRequestItem.amount = amount;
        notificationRequestItem.eventCode = 'CAPTURE';
        notificationRequestItem.pspReference = 'pspref';
        notificationRequestItem.success = 'true';
        notificationRequestItem.merchantAccountCode = 'merchant_account_code';

        AdyenService.NotificationItems notificationItems = new AdyenService.NotificationItems();
        notificationItems.NotificationRequestItem = notificationRequestItem;
        mockNotification.notificationItems.add(notificationItems);

        String mockPostResponse = JSON.serialize(mockNotification);


        HttpResponse res = new HttpResponse();
        res.setBody(mockPostResponse);
        res.setStatusCode(200);
        Test.setMock(HttpCalloutMock.class, new EchoHttpMock(res));

        Test.startTest();

        Double amt = 500;
        String authId = 'testauthId123';
        Map<String,String> mHeaders = new Map<String,String>{'Content-Type' => 'application/json'};

        CommercePayments.PaymentGatewayNotificationRequest paymentGatewayNotificationRequest = new CommercePayments.PaymentGatewayNotificationRequest(mHeaders,mockPostResponse);
        CommercePayments.PaymentGatewayNotificationContext paymentGatewayNotificationContext = new CommercePayments.PaymentGatewayNotificationContext(paymentGatewayNotificationRequest);

        AdyenAsyncAdapter adyenAdapter = new AdyenAsyncAdapter();
        CommercePayments.GatewayNotificationResponse gatewayNotificationResponse = adyenAdapter.processNotification(paymentGatewayNotificationContext);
        
        System.debug('outputting response from process processNotification. =' + gatewayNotificationResponse.toString());
        Test.stopTest();

        // CommercePayments.GatewayNotificationResponse does not expose any getter methods
        System.Assert(gatewayNotificationResponse.toString().contains('GatewayNotificationResponse'));
    }

    /**
    * @see https://docs.adyen.com/api-explorer/#/Payment/v52/capture
    */
    @IsTest
    static void testCapture_Inbound_Negative() {

        //Build an object that will be coming back from adyen and serialize it as mock response json.
        AdyenService.AdyenNotification mockNotification = new AdyenService.AdyenNotification();
        mockNotification.live = 'false';
        mockNotification.notificationItems = new List<AdyenService.NotificationItems>();
        AdyenService.NotificationRequestItem notificationRequestItem = new AdyenService.NotificationRequestItem();
        AdyenService.Amount amount = new AdyenService.Amount();
        amount.value = 100;
        amount.currency_x = 'USD';
        notificationRequestItem.amount = amount;
        notificationRequestItem.eventCode = 'CAPTURE';
        notificationRequestItem.pspReference = '882595376158677C';
        notificationRequestItem.originalReference = '882595376158677C';
        notificationRequestItem.success = 'false';
        notificationRequestItem.merchantAccountCode = 'merchant_account_code';

        AdyenService.NotificationItems notificationItems = new AdyenService.NotificationItems();
        notificationItems.NotificationRequestItem = notificationRequestItem;
        mockNotification.notificationItems.add(notificationItems);

        String mockPostResponse = JSON.serialize(mockNotification);


        HttpResponse res = new HttpResponse();
        res.setBody(mockPostResponse);
        res.setStatusCode(200);
        Test.setMock(HttpCalloutMock.class, new EchoHttpMock(res));

        Test.startTest();

        Double amt = 500;
        String authId = 'testauthId123';
        Map<String,String> mHeaders = new Map<String,String>{'Content-Type' => 'application/json'};

        CommercePayments.PaymentGatewayNotificationRequest paymentGatewayNotificationRequest = new CommercePayments.PaymentGatewayNotificationRequest(mHeaders,mockPostResponse);
        CommercePayments.PaymentGatewayNotificationContext paymentGatewayNotificationContext = new CommercePayments.PaymentGatewayNotificationContext(paymentGatewayNotificationRequest);

        AdyenAsyncAdapter adyenAdapter = new AdyenAsyncAdapter();
        CommercePayments.GatewayNotificationResponse gatewayNotificationResponse = adyenAdapter.processNotification(paymentGatewayNotificationContext);
        
        System.debug('outputting response from process processNotification. =' + gatewayNotificationResponse.toString());

        Test.stopTest();
        
        // CommercePayments.GatewayNotificationResponse does not expose any getter methods
        System.Assert(gatewayNotificationResponse.toString().contains('GatewayNotificationResponse'));
    }
    
   /**
    * @see https://docs.adyen.com/api-explorer/#/Payment/v52/refund
    */
    @IsTest
    static void testRefund_Inbound_Positive() {

        //Build an object that will be coming back from adyen and serialize it as mock response json.
        AdyenService.AdyenNotification mockNotification = new AdyenService.AdyenNotification();
        mockNotification.live = 'false';
        mockNotification.notificationItems = new List<AdyenService.NotificationItems>();
        AdyenService.NotificationRequestItem notificationRequestItem = new AdyenService.NotificationRequestItem();
        AdyenService.Amount amount = new AdyenService.Amount();
        amount.value = 100;
        amount.currency_x = 'USD';
        notificationRequestItem.amount = amount;
        notificationRequestItem.eventCode = 'REFUND';
        notificationRequestItem.pspReference = 'pspref';
        notificationRequestItem.success = 'true';
        notificationRequestItem.merchantAccountCode = 'merchant_account_code';

        AdyenService.NotificationItems notificationItems = new AdyenService.NotificationItems();
        notificationItems.NotificationRequestItem = notificationRequestItem;
        mockNotification.notificationItems.add(notificationItems);

        String mockPostResponse = JSON.serialize(mockNotification);

        HttpResponse res = new HttpResponse();
        res.setBody(mockPostResponse);
        res.setStatusCode(200);
        Test.setMock(HttpCalloutMock.class, new EchoHttpMock(res));

        Test.startTest();

        Double amt = 500;
        String authId = 'testauthId123';
        Map<String,String> mHeaders = new Map<String,String>{'Content-Type' => 'application/json'};

        CommercePayments.PaymentGatewayNotificationRequest paymentGatewayNotificationRequest = new CommercePayments.PaymentGatewayNotificationRequest(mHeaders,mockPostResponse);
        CommercePayments.PaymentGatewayNotificationContext paymentGatewayNotificationContext = new CommercePayments.PaymentGatewayNotificationContext(paymentGatewayNotificationRequest);


        AdyenAsyncAdapter adyenAdapter = new AdyenAsyncAdapter();
        CommercePayments.GatewayNotificationResponse gatewayNotificationResponse = adyenAdapter.processNotification(paymentGatewayNotificationContext);
        
        Test.stopTest();

        // CommercePayments.GatewayNotificationResponse does not expose any getter methods
        System.Assert(gatewayNotificationResponse.toString().contains('GatewayNotificationResponse'));
    }


    /**
    * @see https://docs.adyen.com/api-explorer/#/Payment/v52/refund
    */
    @IsTest
    static void testRefund_Inbound_Negative() {

        //Build an object that will be coming back from adyen and serialize it as mock response json.
        AdyenService.AdyenNotification mockNotification = new AdyenService.AdyenNotification();
        mockNotification.live = 'false';
        mockNotification.notificationItems = new List<AdyenService.NotificationItems>();
        AdyenService.NotificationRequestItem notificationRequestItem = new AdyenService.NotificationRequestItem();
        AdyenService.Amount amount = new AdyenService.Amount();
        amount.value = 100;
        amount.currency_x = 'USD';
        notificationRequestItem.amount = amount;
        notificationRequestItem.eventCode = 'REFUND';
        notificationRequestItem.pspReference = 'pspref';
        notificationRequestItem.success = 'false';
        notificationRequestItem.merchantAccountCode = 'merchant_account_code';

        AdyenService.NotificationItems notificationItems = new AdyenService.NotificationItems();
        notificationItems.NotificationRequestItem = notificationRequestItem;
        mockNotification.notificationItems.add(notificationItems);

        String mockPostResponse = JSON.serialize(mockNotification);

        HttpResponse res = new HttpResponse();
        res.setBody(mockPostResponse);
        res.setStatusCode(200);
        Test.setMock(HttpCalloutMock.class, new EchoHttpMock(res));

        Test.startTest();

        Double amt = 500;
        String authId = 'testauthId123';
        Map<String,String> mHeaders = new Map<String,String>{'Content-Type' => 'application/json'};

        CommercePayments.PaymentGatewayNotificationRequest paymentGatewayNotificationRequest = new CommercePayments.PaymentGatewayNotificationRequest(mHeaders,mockPostResponse);
        CommercePayments.PaymentGatewayNotificationContext paymentGatewayNotificationContext = new CommercePayments.PaymentGatewayNotificationContext(paymentGatewayNotificationRequest);

        AdyenAsyncAdapter adyenAdapter = new AdyenAsyncAdapter();
        CommercePayments.GatewayNotificationResponse gatewayNotificationResponse = adyenAdapter.processNotification(paymentGatewayNotificationContext);
        
        Test.stopTest();

        // CommercePayments.GatewayNotificationResponse does not expose any getter methods
        System.Assert(gatewayNotificationResponse.toString().contains('GatewayNotificationResponse'));
    }

    
   /**
    *
    */
    @IsTest
    static void testUnsupported_Inbound_Notification() {

        //Build an object that will be coming back from adyen and serialize it as mock response json.
        AdyenService.AdyenNotification mockNotification = new AdyenService.AdyenNotification();
        mockNotification.live = 'false';
        mockNotification.notificationItems = new List<AdyenService.NotificationItems>();
        AdyenService.NotificationRequestItem notificationRequestItem = new AdyenService.NotificationRequestItem();
        AdyenService.Amount amount = new AdyenService.Amount();
        amount.value = 100;
        amount.currency_x = 'USD';
        notificationRequestItem.amount = amount;
        notificationRequestItem.eventCode = 'NOTCAP_NOTREF_IE_UNSUPPORTED';
        notificationRequestItem.pspReference = 'pspref';
        notificationRequestItem.success = 'true';
        notificationRequestItem.merchantAccountCode = 'merchant_account_code';

        AdyenService.NotificationItems notificationItems = new AdyenService.NotificationItems();
        notificationItems.NotificationRequestItem = notificationRequestItem;
        mockNotification.notificationItems.add(notificationItems);

        String mockPostResponse = JSON.serialize(mockNotification);


        HttpResponse res = new HttpResponse();
        res.setBody(mockPostResponse);
        res.setStatusCode(200);
        Test.setMock(HttpCalloutMock.class, new EchoHttpMock(res));

        Test.startTest();

        Double amt = 500;
        String authId = 'testauthId123';
        Map<String,String> mHeaders = new Map<String,String>{'Content-Type' => 'application/json'};

        CommercePayments.PaymentGatewayNotificationRequest paymentGatewayNotificationRequest = new CommercePayments.PaymentGatewayNotificationRequest(mHeaders,mockPostResponse);
        CommercePayments.PaymentGatewayNotificationContext paymentGatewayNotificationContext = new CommercePayments.PaymentGatewayNotificationContext(paymentGatewayNotificationRequest);


        AdyenAsyncAdapter adyenAdapter = new AdyenAsyncAdapter();
        CommercePayments.GatewayNotificationResponse gatewayNotificationResponse = adyenAdapter.processNotification(paymentGatewayNotificationContext);

        Test.stopTest();

        // CommercePayments.GatewayNotificationResponse does not expose any getter methods
        System.Assert(gatewayNotificationResponse.toString().contains('GatewayNotificationResponse'));
    }
}