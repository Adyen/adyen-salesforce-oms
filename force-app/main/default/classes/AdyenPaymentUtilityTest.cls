@IsTest
private class AdyenPaymentUtilityTest {
    @IsTest(SeeAllData=true) // for ConnectApi use only
    static void addInvoiceData() {
        Integer productPrice = 100;
        Integer taxValue = 5;
        Decimal percentage = Decimal.valueOf(taxValue)/Decimal.valueOf(productPrice).setScale(4, RoundingMode.HALF_EVEN);
        OrderPaymentSummary orderPaySum = createInvoiceAndRelatedRecords(productPrice, taxValue);
        Id invoiceId = [SELECT Id FROM Invoice WHERE ReferenceEntityId = :orderPaySum.OrderSummaryId].Id;

        Test.startTest();
        List<LineItem> lineItems = AdyenPaymentUtility.addInvoiceData(invoiceId);
        Test.stopTest();

        Assert.areEqual(1, lineItems.size());
        Assert.areEqual(taxValue*100, lineItems[0].taxAmount);
        Assert.areEqual(Integer.valueOf(percentage*10000), lineItems[0].taxPercentage);
        Assert.areEqual(productPrice*100, lineItems[0].amountExcludingTax);
        Assert.areEqual((productPrice+taxValue)*100, lineItems[0].amountIncludingTax);
    }
    @IsTest(SeeAllData=true) // for ConnectApi use only
    static void addCreditMemoDataTest() {
        Integer productPrice = 100;
        Integer taxValue = 5;
        Decimal percentage = Decimal.valueOf(taxValue)/Decimal.valueOf(productPrice).setScale(4, RoundingMode.HALF_EVEN);
        OrderPaymentSummary orderPaySum = createInvoiceAndRelatedRecords(productPrice, taxValue);
        createCreditMemoAndRelatedRecords(orderPaySum.OrderSummaryId);

        Test.startTest();
        List<LineItem> lineItems = AdyenPaymentUtility.addCreditMemoData(orderPaySum.OrderSummaryId);
        Test.stopTest();

        Assert.areEqual(1, lineItems.size());
        Assert.areEqual(taxValue*100, lineItems[0].taxAmount);
        Assert.areEqual(Integer.valueOf(percentage*10000), lineItems[0].taxPercentage);
        Assert.areEqual(productPrice*100, lineItems[0].amountExcludingTax);
        Assert.areEqual((productPrice+taxValue)*100, lineItems[0].amountIncludingTax);
    }

    @IsTest(SeeAllData=true) // for ConnectApi use only
    static void addInvoiceDataNoTaxTest() {
        Integer productPrice = 100;
        OrderPaymentSummary orderPaySum = createInvoiceAndRelatedRecords(productPrice, 0);
        Id invoiceId = [SELECT Id FROM Invoice WHERE ReferenceEntityId = :orderPaySum.OrderSummaryId].Id;

        Test.startTest();
        List<LineItem> lineItems = AdyenPaymentUtility.addInvoiceData(invoiceId);
        Test.stopTest();

        Assert.areEqual(0, lineItems[0].taxAmount);
        Assert.areEqual(0, lineItems[0].taxPercentage);
    }

    @IsTest
    static void retrieveApexAdapterIdTest() {
        PaymentGatewayProvider payGatProvider = [SELECT ApexAdapterId FROM PaymentGatewayProvider WHERE ApexAdapterId != NULL LIMIT 1];
        PaymentGateway payGateway = TestDataFactory.createPaymentGateway();
        payGateway.PaymentGatewayProviderId = payGatProvider.Id;
        insert payGateway;
        PaymentAuthorization payAuth = TestDataFactory.createPaymentAuthorization(null, null, payGateway.Id, null);
        payAuth.GatewayRefNumber = TestDataFactory.GATEWAY_REF;
        insert payAuth;

        Test.startTest();
        Id apexAdapterId = AdyenPaymentUtility.retrieveApexAdapterId(TestDataFactory.GATEWAY_REF);
        Test.stopTest();

        Assert.areEqual(payGatProvider.ApexAdapterId, apexAdapterId);
    }

    @IsTest
    static void retrieveApexAdapterIdFallbackTest() {
        PaymentGatewayProvider payGatProvider = [SELECT ApexAdapterId FROM PaymentGatewayProvider WHERE ApexAdapterId != NULL LIMIT 1];
        PaymentGateway payGateway = TestDataFactory.createPaymentGateway();
        payGateway.PaymentGatewayProviderId = payGatProvider.Id;
        insert payGateway;
        Payment payment = TestDataFactory.createPayment(null, null, payGateway.Id, null, null);
        payment.GatewayRefNumber = TestDataFactory.GATEWAY_REF;
        insert payment;

        Test.startTest();
        Id apexAdapterId = AdyenPaymentUtility.retrieveApexAdapterId(TestDataFactory.GATEWAY_REF);
        Test.stopTest();

        Assert.areEqual(payGatProvider.ApexAdapterId, apexAdapterId);
    }

    @IsTest(SeeAllData=true) // for ConnectApi use only
    static void getFulfillmentOrderTest() {
        OrderPaymentSummary orderPaySum = createInvoiceAndRelatedRecords(100, 5);
        Test.startTest();
        FulfillmentOrder fulfillmentOrder = AdyenPaymentUtility.getFulfillmentOrder(orderPaySum.OrderSummaryId, 105);
        Test.stopTest();
        Assert.isNotNull(fulfillmentOrder);
    }

    @IsTest
    static void getFulfillmentOrderFailTest() {
        Test.startTest();
        FulfillmentOrder fulfillmentOrder = AdyenPaymentUtility.getFulfillmentOrder(null, 0);
        Test.stopTest();
        Assert.isNull(fulfillmentOrder);
    }

    @IsTest(SeeAllData=true) // for ConnectApi use only
    static void getReferenceTest() {
        OrderPaymentSummary orderPaySum = createInvoiceAndRelatedRecords(100, 5);
        PaymentAuthorization payAuth = [
            SELECT OrderPaymentSummary.OrderSummaryId
            FROM PaymentAuthorization
            WHERE OrderPaymentSummaryId = :orderPaySum.Id
        ];
        Payment payment = [
            SELECT OrderPaymentSummary.OrderSummaryId
            FROM Payment
            WHERE OrderPaymentSummaryId = :orderPaySum.Id
        ];
        FulfillmentOrder fulfillmentOrder = [
            SELECT FulfillmentOrderNumber
            FROM FulfillmentOrder
            WHERE OrderSummaryId = :orderPaySum.OrderSummaryId
        ];

        Test.startTest();
        String referencePayAuth = AdyenPaymentUtility.getReference(payAuth, 105);
        String referencePayment = AdyenPaymentUtility.getReference(payment, 105);
        Test.stopTest();

        Assert.areEqual(fulfillmentOrder.FulfillmentOrderNumber, referencePayAuth);
        Assert.areEqual(fulfillmentOrder.FulfillmentOrderNumber, referencePayment);
    }

    @IsTest
    static void getReferenceRandomTest() {
        OrderPaymentSummary  orderPaymentSummary = new OrderPaymentSummary(Id = '0bM7Q000000QP0uUAG', OrderSummaryId = '1Os7Q000000Uh77SAC');
        PaymentAuthorization payAuth = new PaymentAuthorization(OrderPaymentSummary = orderPaymentSummary);

        Test.startTest();
        String reference = AdyenPaymentUtility.getReference(payAuth, 23);
        String referenceNullOrderPaySum = AdyenPaymentUtility.getReference(new PaymentAuthorization(), 23);
        Test.stopTest();

        Assert.isNotNull(reference);
        Assert.isNotNull(referenceNullOrderPaySum);
        Assert.areEqual(16, reference.length());
        Assert.areEqual(16, referenceNullOrderPaySum.length());
    }
    
    private static OrderPaymentSummary createInvoiceAndRelatedRecords(Decimal price, Decimal taxValue) {
        Account acct = TestDataFactory.createAccount();
        insert acct;
        Order order = TestDataFactory.insertOrderAndRelatedRecords(acct.Id, price, taxValue);
        OrderPaymentSummary orderPaymentSummary = TestDataFactory.createOrderSummaryRecords(order.AccountId, order.Id);
        TestDataFactory.insertBasicPaymentRecords(acct.Id, orderPaymentSummary.Id);
        Id fulfillmentOrderId = TestDataFactory.createFulfillmentOrder(orderPaymentSummary.OrderSummaryId)[0];
        TestDataFactory.createInvoiceAndLineItems(fulfillmentOrderId);
        return orderPaymentSummary;
    }

    private static Id createCreditMemoAndRelatedRecords(Id orderSummaryId) {
        FulfillmentOrder fulfillmentOrder = [SELECT Status FROM FulfillmentOrder WHERE OrderSummaryId = :orderSummaryId];
        fulfillmentOrder.Status = 'Fulfilled';
        update fulfillmentOrder;

        Id changeOrderId = TestDataFactory.submitReturn(orderSummaryId);
        Id creditMemoId = TestDataFactory.createCreditMemo(orderSummaryId, changeOrderId);
        return creditMemoId;
    }
}