@IsTest
public class TestDataFactory {
    // constants
    public static final String TEST_PSP_REFERENCE = '853587067740652G';
    public static final String TEST_PAYMENT_TOKEN = 'TEST_PAYMENT_TOKEN';
    public static final String TEST_AUTH_CODE = 'TEST_AUTH_CODE';
    public static final String RESULT_CODE_SUCCESS = 'Authorised';
    public static final String RESULT_CODE_FAIL = 'Failure';
    public static final String GATEWAY_REF = '0000000000000000';
    public static final Double TEST_PRICE_AMOUNT = 19.99;
    public static final Double TEST_TAX_AMOUNT = TEST_PRICE_AMOUNT * 0.05;
    public static final String ACTIVE_CURRENCY = [SELECT IsoCode FROM CurrencyType WHERE IsActive = TRUE LIMIT 1].IsoCode;
    public static final String ASSERT_PRICE_MESSAGE = 'For input price of ';
    public static final String US_JSON_ADDRESS = '{"city": "San Francisco", "country": "USA", "postalCode": "94103", "state": "CA", "street": "123 Market St"}';
    public static final String NL_JSON_ADDRESS = '{"city": "Amsterdam", "country": "Netherlands", "postalCode": "1012 JS", "state": "", "street": "Dam Square 1"}';
    public static final String NO_NUMBER_JSON_ADDRESS = '{"city": "Amsterdam", "country": "Netherlands", "postalCode": "1012 JS", "state": "", "street": "Dam Square"}';


    public static AdyenGatewayAdapter adyenAdapter = new AdyenGatewayAdapter();

    public static Account createAccount() {
        return new Account(Name = 'Test Account');
    }

    public static Contact insertAccountWithContact() {
        Account newAccount = createAccount();
        insert newAccount;
        Contact newContact = new Contact(FirstName = 'Test', LastName = 'last', AccountId = newAccount.Id, Email = 'test@email.com');
        insert newContact;
        return newContact;
    }

    public static CardPaymentMethod createCardPaymentMethod() {
        return new CardPaymentMethod(
            GatewayToken = TEST_PAYMENT_TOKEN,
            GatewayTokenEncrypted = TEST_PAYMENT_TOKEN,
            CardHolderName = 'Test Cardholder',
            Email = 'test@asdf.com',
            Status = 'Active',
            ProcessingMode = AdyenOMSConstants.ProcessingMode.EXTERNAL.name()
        );
    }

    public static AlternativePaymentMethod createAlternativePaymentMethod() {
        return new AlternativePaymentMethod(
            GatewayToken = TEST_PAYMENT_TOKEN,
            Email = 'test@asdf.com',
            Status = 'Active',
            ProcessingMode = AdyenOMSConstants.ProcessingMode.EXTERNAL.name()
        );
    }

    public static PaymentAuthorization createPaymentAuthorization(Id acctId, Id cardPayMetId, Id payGatId, Id orderPaySummaryId, String pspReference) {
        return createPaymentAuthorizationWithStatus(acctId, cardPayMetId, payGatId, orderPaySummaryId, pspReference, AdyenOMSConstants.PaymentAuthorizationStatus.PROCESSED.name());
    }

    public static PaymentAuthorization createPaymentAuthorizationWithStatus(Id acctId, Id cardPayMetId, Id payGatId, Id orderPaySummaryId, String pspReference, String status) {
        return new PaymentAuthorization(
            AccountId = acctId,
            PaymentMethodId = cardPayMetId,
            Amount = TEST_PRICE_AMOUNT,
            GatewayRefNumber = pspReference,
            Status = status,
            ProcessingMode = AdyenOMSConstants.ProcessingMode.EXTERNAL.name(),
            PaymentGatewayId = payGatId,
            CurrencyIsoCode = ACTIVE_CURRENCY,
            OrderPaymentSummaryId = orderPaySummaryId
        );
    }

    public static Payment createPayment(Id acctId, Id cardPayMetId, Id payGatId, Id payAuthId, Id orderPaySummaryId) {
        return new Payment(
            AccountId = acctId,
            PaymentMethodId = cardPayMetId,
            Amount = TEST_PRICE_AMOUNT,
            GatewayRefNumber = TEST_PSP_REFERENCE,
            Status = AdyenOMSConstants.PaymentAuthorizationStatus.PROCESSED.name(),
            ProcessingMode = AdyenOMSConstants.ProcessingMode.EXTERNAL.name(),
            Type = AdyenOMSConstants.PaymentType.CAPTURE.name(),
            PaymentGatewayId = payGatId,
            PaymentAuthorizationId = payAuthId,
            OrderPaymentSummaryId = orderPaySummaryId
        );
    }

    public static void insertBasicPaymentRecords(Id accId, Id orderPaySummaryId) {
        CardPaymentMethod cardPayMeth = createCardPaymentMethod();
        insert cardPayMeth;
        
        PaymentAuthorization payAuth = createPaymentAuthorization(accId, cardPayMeth.Id, null, orderPaySummaryId, TEST_PSP_REFERENCE);
        insert payAuth;
        
        Payment payment = createPayment(accId, cardPayMeth.Id, null, payAuth.Id, orderPaySummaryId);
        insert payment;
    }

    public static String createNotificationRequestBody(String eventCode, String originalRef) {
        NotificationItems notificationItems = new NotificationItems();
        notificationItems.NotificationRequestItem = createNotificationRequestItem(eventCode, originalRef);
        AdyenNotification adyenNotification = new AdyenNotification();
        adyenNotification.live = 'false';
        adyenNotification.notificationItems = new List<NotificationItems>{notificationItems};
        return JSON.serialize(adyenNotification);
    }

    public static NotificationRequestItem createNotificationRequestItem(String eventCode, String originalRef) {
        NotificationRequestItem nri = new NotificationRequestItem();
        Amount a = new Amount();
        a.currency_x = ACTIVE_CURRENCY;
        a.value = (Long)Integer.valueOf(TEST_PRICE_AMOUNT *10);
        nri.amount = a;
        nri.eventCode = eventCode;
        nri.pspReference = GATEWAY_REF;
        nri.eventDate = String.valueOf(System.today());
        nri.success = 'true';
        nri.merchantAccountCode = [SELECT Merchant_Account__c FROM Adyen_Adapter__mdt LIMIT 1].Merchant_Account__c;
        nri.originalReference = originalRef;
        return nri;
    }

    public static CommercePayments.AuthorizationRequest createAuthorisationRequest(Id payMethodId) {
        return createAuthorisationRequest(payMethodId, TEST_PRICE_AMOUNT);
    }

    public static CommercePayments.AuthorizationRequest createAuthorisationRequest(Id payMethodId, Double price) {
        CommercePayments.AuthorizationRequest authRequest = new CommercePayments.AuthorizationRequest(price);
        authRequest.currencyIsoCode = ACTIVE_CURRENCY;

        CommercePayments.CardPaymentMethodRequest cardPayMeth = new CommercePayments.CardPaymentMethodRequest(CommercePayments.CardCategory.CreditCard);
        authRequest.paymentMethod = new CommercePayments.AuthApiPaymentMethodRequest(cardPayMeth);
        authRequest.paymentMethod.id = payMethodId;

        CommercePayments.PaymentGatewayContext payGateContext = new CommercePayments.PaymentGatewayContext(authRequest, CommercePayments.RequestType.Authorize);
        CommercePayments.PaymentGatewayRequest paymentRequest = payGateContext.getPaymentRequest();
        return (CommercePayments.AuthorizationRequest)paymentRequest;
    }

    public static OrderPaymentSummary insertAccountAndOrderPaymentSummary() {
        Account acct = createAccount();
        insert acct;
        Order order = insertOrderAndRelatedRecords(acct.Id, TEST_PRICE_AMOUNT, TEST_TAX_AMOUNT);
        return createOrderSummaryRecords(order.Id);
    }

    public static PaymentAuthorization insertAccountOrderAndPayAuth(String status) {
        OrderPaymentSummary orderPaymentSummary = TestDataFactory.insertAccountAndOrderPaymentSummary();
        Id accountId = [SELECT OrderSummary.AccountId FROM OrderPaymentSummary WHERE Id = :orderPaymentSummary.Id].OrderSummary.AccountId;
        PaymentAuthorization payAuth = TestDataFactory.createPaymentAuthorizationWithStatus(accountId, null, null, orderPaymentSummary.Id, TEST_PSP_REFERENCE, status);
        insert payAuth;
        return payAuth;
    }

    public static PaymentAuthorization insertCartAndRelatedPA() {
        CartExtension.Cart cartObject = CartExtension.CartTestUtil.createCart(CartExtension.WebStoreTypeEnum.B2CE);
        PaymentGroup testPaymentGroup = new PaymentGroup();
        insert testPaymentGroup;
        WebCart testCart = [SELECT Id, PaymentGroupId FROM WebCart WHERE Id = :cartObject.getId()];
        testCart.PaymentGroupId = testPaymentGroup.Id;
        update testCart;
        PaymentAuthorization payAuth = TestDataFactory.insertAccountOrderAndPayAuth(AdyenOMSConstants.PaymentAuthorizationStatus.PENDING.name());
        payAuth.PaymentGroupId = testPaymentGroup.Id;
        update payAuth;
        return payAuth;
    }

    public static Order insertOrderAndRelatedRecords(Id acctId, Decimal productUnitPrice, Decimal prodTaxAmount) {        
        Product2 product = new Product2(
            Name = 'Test Product',
            Description = 'Test Description'
        );
        insert(product);
        
        PricebookEntry pricebookEntry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = product.Id,
            UnitPrice = productUnitPrice,
            IsActive = true,
            UseStandardPrice = false
        );
        insert pricebookEntry;
        
        Order order = new Order(
            AccountId = acctId,
            EffectiveDate = Date.newInstance(2023, 1, 1),
            OrderedDate = Date.newInstance(2023, 1, 1),
            Status = 'Draft',
            Pricebook2Id = pricebookEntry.Pricebook2Id
        );
        insert(order);
        
        OrderDeliveryMethod orderDeliveryMethod = new OrderDeliveryMethod(
            Name = 'Order Delivery Method',
            ProductId = product.Id
        );
        insert orderDeliveryMethod;
        
        OrderDeliveryGroup orderDeliveryGroup = new OrderDeliveryGroup(
            DeliverToName = 'Buyer User',
            DeliverToStreet = 'test Street',
            DeliverToCity = 'Minneapolis',
            DeliverToState = 'MN',
            DeliverToPostalCode = '55402',
            DeliverToCountry = 'US',
            OrderDeliveryMethodId = orderDeliveryMethod.Id,
            OrderId = order.Id
        );
        insert orderDeliveryGroup;
        
        OrderItem orderItem = new OrderItem(
            Description = 'Test Product',
            OrderId = order.Id,
            Product2Id = product.Id,
            PricebookEntryId = pricebookEntry.Id,
            UnitPrice = productUnitPrice,
            Quantity = 1,
            TotalLineAmount = productUnitPrice,
            Type = 'Order Product',
            OrderDeliveryGroupId = orderDeliveryGroup.Id
        );
        insert orderItem;

        OrderItemTaxLineItem tax = new OrderItemTaxLineItem(
            OrderItemId = orderItem.Id,
            Amount = prodTaxAmount,
            Name = 'Tax for product',
            Type = 'Estimated',
            TaxEffectiveDate = System.today()
        );
        insert tax;
        
        order.Status = 'Activated';
        update order;

        return order;
    }

    public static OrderPaymentSummary createOrderSummaryRecords(Id orderId) {
        ConnectApi.OrderSummaryInputRepresentation osir = new ConnectApi.OrderSummaryInputRepresentation();
        osir.orderId = orderId;
        osir.orderLifeCycleType = 'MANAGED';
        ConnectApi.OrderSummaryOutputRepresentation osor = ConnectApi.OrderSummaryCreation.createOrderSummary(osir);
        
        OrderPaymentSummary orderPaymentSummary = new OrderPaymentSummary(
            OrderSummaryId = osor.orderSummaryId,
            Method = 'Visa',
            Type = 'Unknown'
        );
        insert orderPaymentSummary;
        
        return orderPaymentSummary;
    }

    public static Payment_Link__c createPaymentLink(Id orderSummaryId, String status, Datetime expireDate) {
        return new Payment_Link__c(
            Name = 'PL03437B5F04798D20E',
            Amount__c = TEST_PRICE_AMOUNT,
            Shopper_Email__c = 'test@email.com',
            Expire_Date__c = expireDate,
            Order_Summary__c = orderSummaryId,
            Status__c = status
        );
    }

    public static List<Id> createFulfillmentOrder(Id orderSummaryId) {
        String fulfillmentType = 'warehouse';
        
        Schema.Location warehouse = new Schema.Location(Name = 'New York', LocationType = 'Warehouse');
        insert warehouse;
        
        ConnectApi.FulfillmentOrderInputRepresentation fulfillmentOrderInput = new ConnectApi.FulfillmentOrderInputRepresentation();
        fulfillmentOrderInput.orderSummaryId = orderSummaryId;
        
        List<OrderDeliveryGroupSummary> orderDeliveryGroupSummaryList = [SELECT Id FROM OrderDeliveryGroupSummary WHERE OrderSummaryId =: orderSummaryId];
        for (OrderDeliveryGroupSummary orderDeliveryGroupSummary: orderDeliveryGroupSummaryList) {
            fulfillmentOrderInput.orderDeliveryGroupSummaryId = orderDeliveryGroupSummary.Id;
            List<ConnectApi.FulfillmentGroupInputRepresentation> fulfillmentGroups = new List<ConnectApi.FulfillmentGroupInputRepresentation>();
            ConnectApi.FulfillmentGroupInputRepresentation fulfillmentGroup = new ConnectApi.FulfillmentGroupInputRepresentation();
            fulfillmentGroup.fulfilledFromLocationId = warehouse.Id;
            fulfillmentGroup.fulfillmentType = fulfillmentType;
            
            List<ConnectApi.OrderItemSummaryInputRepresentation> orderItemSummaries = new List<ConnectApi.OrderItemSummaryInputRepresentation>();
            List<OrderItemSummary> orderItemSummaryList = [SELECT Id, Quantity FROM OrderItemSummary WHERE OrderSummaryId =: orderSummaryId AND OrderDeliveryGroupSummaryId =: orderDeliveryGroupSummary.Id];
            
            for(OrderItemSummary orderItemSummary : orderItemSummaryList){
                ConnectApi.OrderItemSummaryInputRepresentation oisInputRepresentation = new ConnectApi.OrderItemSummaryInputRepresentation();
                oisInputRepresentation.orderItemSummaryId = orderItemSummary.Id;
                oisInputRepresentation.quantity = orderItemSummary.Quantity;
                orderItemSummaries.add(oisInputRepresentation);
            }
            
            fulfillmentGroup.orderItemSummaries = orderItemSummaries;
            fulfillmentGroups.add(fulfillmentGroup);      
            fulfillmentOrderInput.fulfillmentGroups = fulfillmentGroups;
        }
        
        ConnectApi.FulfillmentOrderOutputRepresentation result = ConnectApi.FulfillmentOrder.createFulfillmentOrders(fulfillmentOrderInput);
        return result.fulfillmentOrderIds;
    }

    public static Id createInvoiceAndLineItems(Id fulfillmentOrderId) {
        ConnectApi.FulfillmentOrderInvoiceInputRepresentation invoiceInput = new ConnectApi.FulfillmentOrderInvoiceInputRepresentation();
        ConnectApi.FulfillmentOrderInvoiceOutputRepresentation result = ConnectApi.FulfillmentOrder.createInvoice(fulfillmentOrderId, invoiceInput);
        return result.invoiceId;
    }

    public static Id submitReturn(Id orderSummaryId) {
        ConnectApi.ChangeItemInputRepresentation changeItemInputRep = new ConnectApi.ChangeItemInputRepresentation();
        changeItemInputRep.shippingReductionFlag = true;
        changeItemInputRep.quantity = 1;
        changeItemInputRep.orderItemSummaryId = [SELECT Id FROM OrderItemSummary WHERE OrderSummaryId = :orderSummaryId].Id;
        changeItemInputRep.reason = 'Unknown';
        ConnectApi.ChangeInputRepresentation changeInputRep = new ConnectApi.ChangeInputRepresentation();
        changeInputRep.changeItems = new List<ConnectApi.ChangeItemInputRepresentation>{changeItemInputRep};
        ConnectApi.SubmitReturnOutputRepresentation submitReturnOutRep = ConnectApi.OrderSummary.submitReturn(orderSummaryId, changeInputRep);
        return submitReturnOutRep.changeOrderId;
    }

    public static Id createCreditMemo(Id orderSummaryId, Id changeOrderId) {
        ConnectApi.CreateCreditMemoInputRepresentation creditMemoInput = new ConnectApi.CreateCreditMemoInputRepresentation();
        creditMemoInput.changeOrderIds = new List<Id>{changeOrderId};
        ConnectApi.CreateCreditMemoOutputRepresentation creditMemoOutput = ConnectApi.OrderSummary.createCreditMemo(orderSummaryId, creditMemoInput);
        return creditMemoOutput.creditMemoId;
    }

    public class EchoHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(AdyenConstants.HTTP_SUCCESS_CODE);
            Map<String, Object> responseBody = new Map<String, Object> {
                'pspReference' => TEST_PSP_REFERENCE,
                'status' => AdyenConstants.NOTIFICATION_RECEIVED_CHECKOUT
            };
            Map<String, Object> additionalData = new Map<String, Object>();
            Map<String, Object> amount = new Map<String, Object> {
                'currency' => ACTIVE_CURRENCY,
                'value' => 0
            };
            
            String endpoint = req.getEndpoint();
            Map<String, Object> requestBody = (Map<String, Object>)JSON.deserializeUntyped(req.getBody());
            if (endpoint.containsIgnoreCase('capture') || endpoint.containsIgnoreCase('refund')) {
                amount.put('value', Integer.valueOf(TEST_PRICE_AMOUNT *10));
            } else {
                Map<String, Object> paymentMethod = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize((requestBody.get('paymentMethod'))));
                responseBody.put('resultCode', RESULT_CODE_SUCCESS);
                // Authorize
                if (TEST_PAYMENT_TOKEN.equals(paymentMethod.get('storedPaymentMethodId'))) { // Successful Auth
                    additionalData.put('authCode', TEST_AUTH_CODE);
                    amount.put('value', Integer.valueOf(TEST_PRICE_AMOUNT * 10));
                } else { // Failed Auth
                    responseBody.put('resultCode', RESULT_CODE_FAIL);
                    res.setStatusCode(AdyenConstants.HTTP_ERROR_CODE);
                }
                responseBody.put('additionalData', additionalData);
            }
            res.setBody(JSON.serialize(responseBody));
            return res;
        }
    }

    public class FailureResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            return mockHttpResponse(genericErrorResponse(), 400);
        }
    }

    public class CancelsMockResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            return mockHttpResponse(cancelResponse(), 200);
        }
    }

    public class PBLMockResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            return mockHttpResponse(pblResponse(), 201);
        }
    }

    public class PBLExpiredMockResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            return mockHttpResponse(pblExpiredResponse(), 200);
        }
    }

    public static HttpResponse mockHttpResponse(String body, Integer code) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'text/json');
        res.setBody(body);
        res.setStatusCode(code);
        return res;
    }

    private static String genericErrorResponse() {
        return '{"status": 400, "errorCode": "702", "message": "Empty input which would have resulted in a null result.", "errorType": "validation"}';
    }

    private static String cancelResponse() {
        return '{"merchantAccount":"PluginDemo_Danilo_TEST","paymentPspReference":"NWQTRSVVQ8Q94875","pspReference":"M4CV9RJFPT4CZX65","reference":"PA-000000037","status":"received"}';
    }

    private static String pblResponse() {
        return '{ "url": "https://test.payment.link", "expiresAt": "2024-01-01T12:00:00+00:00", "status": "active", "id":"PLE5B4575C5A026A2B2"}';
    }

    private static String pblExpiredResponse() {
        return '{ "url": "https://test.payment.link", "expiresAt": "2024-01-01T12:00:00+00:00", "status": "expired", "id":"PLE5B4575C5A026A2B2"}';
    }

    public static String mockWebhookRequest(String eventCode, String pspReference, String originalReference, String merchantRef, Boolean success) {
        String merchantAccountName = [SELECT Merchant_Account__c FROM Adyen_Adapter__mdt LIMIT 1].Merchant_Account__c;
        return '{"live": "false", "notificationItems": [{"NotificationRequestItem": {"additionalData": {"hmacSignature": "testsignature"}, "amount": {"currency": "'+ ACTIVE_CURRENCY +'", "value": 1000}, "eventCode": "' + eventCode + '", "eventDate": "2024-01-01T01:00:00+01:00", "merchantAccountCode": "' + merchantAccountName + '", "merchantReference": "' + merchantRef + '", "paymentMethod": "visa", "pspReference": "' + pspReference + '", "originalReference": "' + originalReference + '", "reason": "null", "success": "' + success + '"}}]}';
    }

    public static String mockPblWebhookRequest(String eventCode, String pspReference, String paymentLinkId, String merchantRef, Boolean success) {
        String merchantAccountName = [SELECT Merchant_Account__c FROM Adyen_Adapter__mdt LIMIT 1].Merchant_Account__c;
        return '{"live": "false", "notificationItems": [{"NotificationRequestItem": {"additionalData": {"hmacSignature": "testsignature", "paymentLinkId": "'+ paymentLinkId +'"}, "amount": {"currency": "'+ ACTIVE_CURRENCY +'", "value": 1000}, "eventCode": "' + eventCode + '", "eventDate": "2024-01-01T01:00:00+01:00", "merchantAccountCode": "' + merchantAccountName + '", "merchantReference": "' + merchantRef + '", "paymentMethod": "visa", "pspReference": "' + pspReference + '", "reason": "null", "success": "' + success + '"}}]}';
    }
}