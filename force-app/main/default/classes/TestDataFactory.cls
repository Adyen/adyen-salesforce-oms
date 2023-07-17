@isTest
public class TestDataFactory {
    // constants
    public static final String TEST_PSP_REFERENCE = '853587067740652G';
    public static final String TEST_PSP_REFERENCE_FAIL = '853587067740652F';
    public static final String TEST_MERCHANT_ACCOUNT = 'TEST_MERCHANT_ACCOUNT';
    public static final String TEST_MERCHANT_REFERENCE = 'TEST_MERCHANT_REFERENCE';
    public static final String TEST_SHOPPER_REFERENCE = 'TEST_SHOPPER_REFERENCE';
    public static final String TEST_CARD_SUCCESS = '4242424242424242';
    public static final String TEST_PAYMENT_TOKEN = 'TEST_PAYMENT_TOKEN';
    public static final String TEST_AUTH_CODE = 'TEST_AUTH_CODE';
    public static final String RESULT_CODE_SUCCESS = 'Authorised';
    public static final String RESULT_CODE_FAIL = 'Failure';
    public static final String GATEWAY_REF = 'gatewayReference';
    public static final Double TEST_AMOUNT = 19.99;
    public static final String ACTIVE_CURRENCY = [SELECT IsoCode FROM CurrencyType WHERE IsActive = true LIMIT 1].IsoCode;

    public static AdyenAsyncAdapter adyenAdapter = new AdyenAsyncAdapter();

    public static Account createAccount() {
        return new Account(Name = 'Test Account');
    }

    public static CardPaymentMethod createCardPaymentMethod() {
        return new CardPaymentMethod(
            GatewayToken = TEST_PAYMENT_TOKEN,
            GatewayTokenEncrypted = TEST_PAYMENT_TOKEN,
            CardHolderName = 'Test Cardholder',
            Email = 'test@asdf.com',
            Status = 'Active',
            ProcessingMode = 'External'
        );
    }

    public static AlternativePaymentMethod createAlternativePaymentMethod() {
        return new AlternativePaymentMethod(
            GatewayToken = TEST_PAYMENT_TOKEN,
            Email = 'test@asdf.com',
            Status = 'Active',
            ProcessingMode = 'External'
        );
    }

    public static PaymentGateway createPaymentGateway() {
        return new PaymentGateway(
            PaymentGatewayName = 'Adyen_Test',
            Status = 'Active',
            ExternalReference = 'Adyen_Component_Test',
            MerchantCredentialId = [SELECT Id FROM NamedCredential LIMIT 1]?.Id,
            PaymentGatewayProviderId = [SELECT Id FROM PaymentGatewayProvider LIMIT 1]?.Id
        );
    }

    public static PaymentAuthorization createPaymentAuthorization(Id acctId, Id cardPayMetId, Id payGatId, Id orderPaySummaryId) {
        return new PaymentAuthorization(
            AccountId = acctId,
            PaymentMethodId = cardPayMetId,
            Amount = TEST_AMOUNT,
            GatewayRefNumber = TEST_PSP_REFERENCE,
            Status = 'Processed',
            ProcessingMode = 'External',
            PaymentGatewayId = payGatId,
            CurrencyIsoCode = ACTIVE_CURRENCY,
            OrderPaymentSummaryId = orderPaySummaryId
        );
    }

    public static Payment createPayment(Id acctId, Id cardPayMetId, Id payGatId, Id payAuthId, Id orderPaySummaryId) {
        return new Payment(
            AccountId = acctId,
            PaymentMethodId = cardPayMetId,
            Amount = TEST_AMOUNT,
            GatewayRefNumber = TEST_PSP_REFERENCE,
            Status = 'Processed',
            ProcessingMode = 'External',
            Type = 'Capture',
            PaymentGatewayId = payGatId,
            PaymentAuthorizationId = payAuthId,
            OrderPaymentSummaryId = orderPaySummaryId
        );
    }

    public static void insertBasicPaymentRecords(Id accId, Id orderPaySummaryId) {
        CardPaymentMethod cardPayMeth = createCardPaymentMethod();
        insert cardPayMeth;
        
        PaymentGateway payGat = createPaymentGateway();
        insert payGat;
        
        PaymentAuthorization payAuth = createPaymentAuthorization(accId, cardPayMeth.Id, payGat.Id, orderPaySummaryId);
        insert payAuth;
        
        Payment payment = createPayment(accId, cardPayMeth.Id, payGat.Id, payAuth.Id, orderPaySummaryId);
        insert payment;
    }

    public static String createNotificationRequestBody(String eventCode, String originalRef) {
        NotificationRequestItem nri = new NotificationRequestItem();
        Amount a = new Amount();
        a.currency_x = ACTIVE_CURRENCY;
        a.value = (Long)Integer.valueOf(TEST_AMOUNT*10);
        nri.amount = a;
        nri.eventCode = eventCode;
        nri.pspReference = GATEWAY_REF;
        nri.eventDate = String.valueOf(System.TODAY());
        nri.paymentpspReference = 'paymentpspref';
        nri.success = 'true';
        nri.merchantAccountCode = 'merchant_account_code';
        nri.originalReference = originalRef;
        
        NotificationItems notificationItems = new NotificationItems();
        notificationItems.NotificationRequestItem = nri;
        AdyenNotification adyenNotification = new AdyenNotification();
        adyenNotification.live = 'false';
        adyenNotification.notificationItems = new List<NotificationItems>{notificationItems};
        return JSON.serialize(adyenNotification);
    }

    public static CommercePayments.AuthorizationRequest createAuthorisationRequest(Id payMethodId) {
        CommercePayments.AuthorizationRequest authRequest = new CommercePayments.AuthorizationRequest(TEST_AMOUNT);
        authRequest.currencyIsoCode = ACTIVE_CURRENCY;
        
        CommercePayments.CardPaymentMethodRequest cardPayMeth = new CommercePayments.CardPaymentMethodRequest(CommercePayments.CardCategory.CreditCard);
        authRequest.paymentMethod = new CommercePayments.AuthApiPaymentMethodRequest(cardPayMeth);
        authRequest.paymentMethod.Id = payMethodId;

        CommercePayments.PaymentGatewayContext payGatecontext = new CommercePayments.PaymentGatewayContext(authRequest, CommercePayments.RequestType.Authorize);
        CommercePayments.PaymentGatewayRequest paymentRequest = payGatecontext.getPaymentRequest();
        return (CommercePayments.AuthorizationRequest)paymentRequest;
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
            OrderItemId = OrderItem.Id,
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

    public static OrderPaymentSummary createOrderSummaryRecords(Id accId, Id orderId) {
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
            List<OrderItemSummary> orderItemSummaryList = [SELECT Id, quantity FROM OrderItemSummary WHERE OrderSummaryId =: orderSummaryId AND OrderDeliveryGroupSummaryId =: orderDeliveryGroupSummary.Id];
            
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
        
        ConnectApi.FulfillmentOrderOutputRepresentation result = ConnectAPI.FulfillmentOrder.createFulfillmentOrders(fulfillmentOrderInput);
        return result.fulfillmentOrderIds;
    }

    public static Id createInvoiceAndLineItems(Id fulfillmentOrderId) {
        ConnectApi.FulfillmentOrderInvoiceInputRepresentation invoiceInput = new ConnectApi.FulfillmentOrderInvoiceInputRepresentation();
        ConnectAPI.FulfillmentOrderInvoiceOutputRepresentation result = ConnectApi.FulfillmentOrder.createInvoice(fulfillmentOrderId, invoiceInput);
        return result.invoiceId;
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
            
            String endpoint = req.getEndpoint();System.debug('endpoint : ' + endpoint);
            Map<String, Object> requestBody = (Map<String, Object>)JSON.deserializeUntyped(req.getBody());
            
            if(endpoint.containsIgnoreCase('payment')) {
                Map<String, Object> paymentMethod = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize((requestBody.get('paymentMethod'))));
                Object spm = requestBody.get('storePaymentMethod');
                responseBody.put('resultCode', RESULT_CODE_SUCCESS);
                // Authorize
                if(TEST_PAYMENT_TOKEN.equals(paymentMethod.get('storedPaymentMethodId'))) { // Successful Auth
                    additionalData.put('authCode', TEST_AUTH_CODE);
                    amount.put('value', Integer.valueOf(TEST_AMOUNT*10));
                } else { // Failed Auth
                    responseBody.put('resultCode', RESULT_CODE_FAIL);
                    res.setStatusCode(AdyenConstants.HTTP_ERROR_CODE);
                }
                responseBody.put('additionalData', additionalData);
            } else if(endpoint.containsIgnoreCase('capture')) {
                // Capture
                responseBody.put('reference', TEST_SHOPPER_REFERENCE);
                if(requestBody.get('merchantAccount') != '' && requestBody.get('amount') != null) { // Successful Capture
                    amount.put('value', Integer.valueOf(TEST_AMOUNT*10));
                } else { // Failed Capture
                    res.setStatusCode(AdyenConstants.HTTP_ERROR_CODE);
                }
            } else if(endpoint.containsIgnoreCase('refund')) {
                // Refund
                responseBody.put('reference', TEST_SHOPPER_REFERENCE);
                if(requestBody.get('merchantAccount') != '' && requestBody.get('amount') != null) { // Successful Refund
                    amount.put('value', Integer.valueOf(TEST_AMOUNT*10));
                } else { // Failed Refund
                    res.setStatusCode(AdyenConstants.HTTP_ERROR_CODE);
                }
            }
            res.setBody(JSON.serialize(responseBody));
            return res;
        }
    }
}