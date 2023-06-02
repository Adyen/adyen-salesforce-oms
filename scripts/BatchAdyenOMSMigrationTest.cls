@isTest
public with sharing class BatchAdyenOMSMigrationTest {
    private static final String TEST_PAYMENT_TOKEN = 'TEST_PAYMENT_TOKEN';
    private static final Double TEST_AMOUNT = 19.99;

    @IsTest(SeeAllData=true) // needed only for ConnectApi call
    private static void batchTest() {
        OrderPaymentSummary orderPaymentSummary = insertOrderPaymentSummary();
        orderPaymentSummary.OrderSummary = [
            SELECT SalesChannel.adyensompackage__AdyenMerchantID__c, adyensompackage__Adyen_paymentMethod__c
            FROM OrderSummary
            WHERE Id = :orderPaymentSummary.OrderSummaryId
        ];

        orderPaymentSummary.OrderSummary.SalesChannel.adyensompackage__AdyenMerchantID__c = 'MyMerchantId';
        update orderPaymentSummary.OrderSummary.SalesChannel;
        
        orderPaymentSummary.OrderSummary.adyensompackage__Adyen_paymentMethod__c = 'Card';
        update orderPaymentSummary.OrderSummary;

        Test.startTest();
        Database.executeBatch(new BatchAdyenOMSMigration());
        Test.stopTest();

        orderPaymentSummary = [
            SELECT OrderSummary.SalesChannel.adyensompackage__AdyenMerchantID__c, OrderSummary.adyensompackage__Adyen_paymentMethod__c, OrderSummary.SalesChannel.AdyenMerchantID__c
            FROM OrderPaymentSummary 
            WHERE Id = :orderPaymentSummary.Id
            LIMIT 1
        ];

        PaymentAuthorization paymentAuthorization = [
            SELECT Adyen_Payment_Method__c, Adyen_Payment_Method_Variant__c
            FROM PaymentAuthorization
            WHERE OrderPaymentSummaryId = :orderPaymentSummary.Id
            LIMIT 1
        ];

        Payment payment = [
            SELECT Adyen_Payment_Method__c, Adyen_Payment_Method_Variant__c
            FROM Payment
            WHERE OrderPaymentSummaryId = :orderPaymentSummary.Id
            LIMIT 1
        ];

        System.Assert.areEqual('MyMerchantId', orderPaymentSummary.OrderSummary.SalesChannel.AdyenMerchantID__c);

        System.Assert.areEqual('Card', paymentAuthorization.Adyen_Payment_Method__c);
        System.Assert.areEqual('Card', paymentAuthorization.Adyen_Payment_Method_Variant__c);

        System.Assert.areEqual('Card', payment.Adyen_Payment_Method__c);
        System.Assert.areEqual('Card', payment.Adyen_Payment_Method_Variant__c);
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
            OrderDeliveryGroupId = orderDeliveryGroup.Id
        );
        insert orderItem;

        order.Status = 'Activated';
        update order;

        ConnectApi.OrderSummaryInputRepresentation osir = new ConnectApi.OrderSummaryInputRepresentation();
        osir.orderId = order.Id;
        osir.orderLifeCycleType = 'UNMANAGED';
        ConnectApi.OrderSummaryOutputRepresentation osor = ConnectApi.OrderSummaryCreation.createOrderSummary(osir);

        OrderSummary orderSummary = [
            SELECT OrderNumber 
            FROM OrderSummary 
            WHERE OriginalOrderId = :order.Id 
            LIMIT 1
        ];
        orderSummary.SalesChannelId = salesChannel.Id;
        update orderSummary;

        OrderPaymentSummary orderPaymentSummary = new OrderPaymentSummary(
            OrderSummaryId = orderSummary.Id,
            Method = 'Visa',
            Type = 'Unknown'
        );
        insert orderPaymentSummary;

        CardPaymentMethod cardPaymentMethod = new CardPaymentMethod(
            GatewayToken = TEST_PAYMENT_TOKEN,
            CardHolderName = 'Test Cardholder',
            Email = 'test@asdf.com',
            Status = 'Active',
            ProcessingMode = 'External'
        );
        insert cardPaymentMethod;

        PaymentAuthorization paymentAuthorization = new PaymentAuthorization(
            OrderPaymentSummaryId = orderPaymentSummary.Id,
            Amount = TEST_AMOUNT,
            Status = 'Processed',
            ProcessingMode = 'External',
            PaymentMethodId = cardPaymentMethod.Id
        );
        insert paymentAuthorization;

        Payment payment = new Payment(
            OrderPaymentSummaryId = orderPaymentSummary.Id,
            Amount = TEST_AMOUNT,
            Status = 'Processed',
            ProcessingMode = 'External',
            PaymentMethodId = cardPaymentMethod.Id,
            Type = 'Capture'
        );
        insert payment;

        return orderPaymentSummary;
    }
}