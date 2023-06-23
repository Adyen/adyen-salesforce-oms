@isTest
private class AdyenPaymentUtilityTest {
    @isTest(SeeAllData=true) // for ConnectApi use only
    static void addInvoiceData() {
        OrderPaymentSummary orderPaymentSummary = insertOrderPaymentSummary();
        createFulfillmentOrder(orderPaymentSummary.OrderSummaryId);
        Id fulfillmentOrderId = [SELECT Id FROM FulFillmentOrder WHERE OrderSummaryId = :orderPaymentSummary.OrderSummaryId].Id;
        ConnectApi.FulfillmentOrderInvoiceInputRepresentation invoiceInput = new ConnectApi.FulfillmentOrderInvoiceInputRepresentation();
        ConnectAPI.FulfillmentOrderInvoiceOutputRepresentation result = ConnectApi.FulfillmentOrder.createInvoice(fulfillmentOrderId, invoiceInput);
        Invoice invoice = [SELECT Id FROM Invoice WHERE ReferenceEntityId = :orderPaymentSummary.OrderSummaryId];
        InvoiceLine invoiceLine = [SELECT Product2.Name, Quantity, CurrencyIsoCode, ChargeAmount, ChargeTaxAmount FROM InvoiceLine WHERE InvoiceId = :invoice.Id];
        System.debug(invoiceLine);

        PaymentAuthorization paymentAuthorization = [
            SELECT CurrencyIsoCode
            FROM PaymentAuthorization
            WHERE OrderPaymentSummaryId = :orderPaymentSummary.Id
            LIMIT 1
        ];
        Map<String, Object> additionalData = AdyenPaymentUtility.addInvoiceData(invoice.Id, paymentAuthorization);
        Assert.isNotNull(additionalData);
    }
    
    private static void createFulfillmentOrder(Id orderSummaryId) {
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
    }
    
    private static OrderPaymentSummary insertOrderPaymentSummary() {
        Account account = new Account(Name = 'Batch Account');
        insert account;
        
        SalesChannel salesChannel = new SalesChannel(
        SalesChannelName = 'RefArch'
        );
        insert salesChannel;
        
        Product2 product = new Product2(
        Name = 'Test Product',
        Description = 'Test Description'
        );
        insert(product);
        
        PricebookEntry pricebookEntry = new PricebookEntry(
        Pricebook2Id = Test.getStandardPricebookId(),
        Product2Id = product.Id,
        UnitPrice = 200,
        IsActive = true,
        UseStandardPrice = false
        );
        insert pricebookEntry;
        
        Order order = new Order(
        AccountId = account.Id,
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
        UnitPrice = 100,
        Quantity = 1,
        TotalLineAmount = 100,
        Type = 'Order Product',
        OrderDeliveryGroupId = orderDeliveryGroup.Id
        );
        insert orderItem;
        
        order.Status = 'Activated';
        // order.SalesChannelId = salesChannel.Id;
        update order;
        
        ConnectApi.OrderSummaryInputRepresentation osir = new ConnectApi.OrderSummaryInputRepresentation();
        osir.orderId = order.Id;
        osir.orderLifeCycleType = 'MANAGED';
        ConnectApi.OrderSummaryOutputRepresentation osor = ConnectApi.OrderSummaryCreation.createOrderSummary(osir);
        
        OrderSummary orderSummary = [
        SELECT OrderNumber 
        FROM OrderSummary 
        WHERE OriginalOrderId = :order.Id 
        LIMIT 1
        ];
        
        OrderPaymentSummary orderPaymentSummary = new OrderPaymentSummary(
        OrderSummaryId = orderSummary.Id,
        Method = 'Visa',
        Type = 'Unknown'
        );
        insert orderPaymentSummary;
        
        CardPaymentMethod cardPaymentMethod = new CardPaymentMethod(
        GatewayToken = TestDataFactory.TEST_PAYMENT_TOKEN,
        CardHolderName = 'Test Cardholder',
        Email = 'test@asdf.com',
        Status = 'Active',
        ProcessingMode = 'External'
        );
        insert cardPaymentMethod;
        
        PaymentAuthorization paymentAuthorization = new PaymentAuthorization(
        OrderPaymentSummaryId = orderPaymentSummary.Id,
        Amount = TestDataFactory.TEST_AMOUNT,
        Status = 'Processed',
        ProcessingMode = 'External',
        PaymentMethodId = cardPaymentMethod.Id
        );
        insert paymentAuthorization;
        
        Payment payment = new Payment(
        OrderPaymentSummaryId = orderPaymentSummary.Id,
        Amount = TestDataFactory.TEST_AMOUNT,
        Status = 'Processed',
        ProcessingMode = 'External',
        PaymentMethodId = cardPaymentMethod.Id,
        Type = 'Capture'
        );
        insert payment;
        
        return orderPaymentSummary;
    }
}