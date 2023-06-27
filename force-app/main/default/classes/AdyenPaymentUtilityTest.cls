@isTest
private class AdyenPaymentUtilityTest {
    @isTest(SeeAllData=true) // for ConnectApi use only
    static void addInvoiceData() {
        Decimal productPrice = 100;
        Decimal taxValue = 5;
        OrderPaymentSummary orderPaySum = createInvoiceAndRelatedRecords(productPrice, taxValue);
        Id invoiceId = [SELECT Id FROM Invoice WHERE ReferenceEntityId = :orderPaySum.OrderSummaryId].Id;
        PaymentAuthorization payAuth = [SELECT CurrencyIsoCode FROM PaymentAuthorization WHERE OrderPaymentSummaryId = :orderPaySum.Id];

        Test.startTest();
        Map<String, Object> additionalData = AdyenPaymentUtility.addInvoiceData(invoiceId, payAuth);
        Test.stopTest();
   
        Assert.areEqual(String.valueOf(taxValue*100), additionalData.get('openinvoicedata.line1.itemVatAmount'));
        Assert.areEqual(String.valueOf(Integer.valueOf((taxValue/productPrice)*100)), additionalData.get('openinvoicedata.line1.itemVatPercentage'));
        Assert.areEqual(TestDataFactory.ACTIVE_CURRENCY, additionalData.get('openinvoicedata.line1.currencyCode'));
        Assert.areEqual(String.valueOf(productPrice*100), additionalData.get('openinvoicedata.line1.itemAmount'));
    }

    @isTest(SeeAllData=true) // for ConnectApi use only
    static void addInvoiceDataNoTaxTest() {
        Decimal productPrice = 100;
        Decimal taxValue = 0;
        OrderPaymentSummary orderPaySum = createInvoiceAndRelatedRecords(productPrice, taxValue);
        Id invoiceId = [SELECT Id FROM Invoice WHERE ReferenceEntityId = :orderPaySum.OrderSummaryId].Id;
        PaymentAuthorization payAuth = [SELECT CurrencyIsoCode FROM PaymentAuthorization WHERE OrderPaymentSummaryId = :orderPaySum.Id];

        Test.startTest();
        Map<String, Object> additionalData = AdyenPaymentUtility.addInvoiceData(invoiceId, payAuth);
        Test.stopTest();
   
        Assert.areEqual(String.valueOf(taxValue*100), additionalData.get('openinvoicedata.line1.itemVatAmount'));
        Assert.areEqual(String.valueOf(Integer.valueOf((taxValue/productPrice)*100)), additionalData.get('openinvoicedata.line1.itemVatPercentage'));
    }

    @isTest
    static void retrieveApexAdapterIdTest() {
        String gatewayRefNum = 'REF_NUMBER';
        PaymentGatewayProvider payGatProvider = [SELECT ApexAdapterId FROM PaymentGatewayProvider WHERE ApexAdapterId != NULL LIMIT 1];
        PaymentGateway payGateway = TestDataFactory.createPaymentGateway();
        payGateway.PaymentGatewayProviderId = payGatProvider.Id;
        insert payGateway;
        PaymentAuthorization payAuth = TestDataFactory.createPaymentAuthorization(null, null, payGateway.Id, null);
        payAuth.GatewayRefNumber = gatewayRefNum;
        insert payAuth;

        Test.startTest();
        Id apexAdapterId = AdyenPaymentUtility.retrieveApexAdapterId(gatewayRefNum);
        Test.stopTest();

        Assert.areEqual(payGatProvider.ApexAdapterId, apexAdapterId);
    }

    @isTest
    static void retrieveApexAdapterIdFallbackTest() {
        String gatewayRefNum = 'REF_NUMBER';
        PaymentGatewayProvider payGatProvider = [SELECT ApexAdapterId FROM PaymentGatewayProvider WHERE ApexAdapterId != NULL LIMIT 1];
        PaymentGateway payGateway = TestDataFactory.createPaymentGateway();
        payGateway.PaymentGatewayProviderId = payGatProvider.Id;
        insert payGateway;
        Payment payment = TestDataFactory.createPayment(null, null, payGateway.Id, null, null);
        payment.GatewayRefNumber = gatewayRefNum;
        insert payment;

        Test.startTest();
        Id apexAdapterId = AdyenPaymentUtility.retrieveApexAdapterId(gatewayRefNum);
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
        Id invoiceId = TestDataFactory.createInvoiceAndLineItems(fulfillmentOrderId);
        return orderPaymentSummary;
    }
}