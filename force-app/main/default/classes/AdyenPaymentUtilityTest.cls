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