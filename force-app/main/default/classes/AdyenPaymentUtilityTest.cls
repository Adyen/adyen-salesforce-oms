@IsTest
private class AdyenPaymentUtilityTest {
    private static String ASSERT_PRICE_MESSAGE = 'For input price of ';
    @IsTest
    static void createAuthorisationRequestTest() {
        // given
        Adyen_Adapter__mdt adyenAdapterMdt = AdyenPaymentUtility.retrieveGatewayMetadata(AdyenConstants.DEFAULT_ADAPTER_NAME);
        AuthorisationRequest adyenAuthRequest;
        Double price;
        CommercePayments.AuthorizationRequest authRequest;
        Long expectedValue;
        for (Integer i = 0; i < 10; i++) {
            price = 1008.90 + (0.01 * i);
            authRequest = new CommercePayments.AuthorizationRequest(price);
            authRequest.currencyIsoCode = 'USD';
            // when
            adyenAuthRequest = AdyenPaymentUtility.createAuthorisationRequest(authRequest, adyenAdapterMdt);
            // then
            expectedValue = (Decimal.valueOf(price) * 100).longValue();
            Assert.areEqual(expectedValue, adyenAuthRequest.amount.value, ASSERT_PRICE_MESSAGE + price);
        }
        // given a higher amount of decimals
        for (Integer i = 0; i < 10; i++) {
            price = 1008.900 + (i * 0.001);
            authRequest = new CommercePayments.AuthorizationRequest(price);
            authRequest.currencyIsoCode = 'USD';
            // when
            adyenAuthRequest = AdyenPaymentUtility.createAuthorisationRequest(authRequest, adyenAdapterMdt);
            // then
            expectedValue = (Decimal.valueOf(price) * 100).round(RoundingMode.HALF_UP);
            Assert.areEqual(expectedValue, adyenAuthRequest.amount.value, ASSERT_PRICE_MESSAGE + price);
        }
        // given 0 decimals currency
        for (Integer i = 0; i < 10; i++) {
            price = 100890 + i;
            authRequest = new CommercePayments.AuthorizationRequest(price);
            authRequest.currencyIsoCode = 'JPY';
            // when
            adyenAuthRequest = AdyenPaymentUtility.createAuthorisationRequest(authRequest, adyenAdapterMdt);
            // then
            expectedValue = Decimal.valueOf(price).longValue();
            Assert.areEqual(expectedValue, adyenAuthRequest.amount.value, ASSERT_PRICE_MESSAGE + price);
        }
        // given 3 decimals currency
        for (Integer i = 0; i < 10; i++) {
            price = 100.890 + (i * 0.001);
            authRequest = new CommercePayments.AuthorizationRequest(price);
            authRequest.currencyIsoCode = 'JOD';
            // when
            adyenAuthRequest = AdyenPaymentUtility.createAuthorisationRequest(authRequest, adyenAdapterMdt);
            // then
            expectedValue = (Decimal.valueOf(price) * 1000).longValue();
            Assert.areEqual(expectedValue, adyenAuthRequest.amount.value, ASSERT_PRICE_MESSAGE + price);
        }
    }

    @IsTest
    private static void createModificationRequestTest() {
        //given
        CommercePayments.RequestType paymentType = CommercePayments.RequestType.Capture;
        String currencyCode = 'USD';
        Double price; // request comes as Double value
        String merchantAccount = 'test_merchant';
        String reference = 'test_reference';
        String systemIntegratorName = 'test_integrator';
        Decimal expectedPrice;
        CheckoutCaptureRequest modificationRequest;
        for (Integer i = 0; i < 10; i++) {
            price = 100.90 + (0.01 * i);
            // when
            modificationRequest = (CheckoutCaptureRequest)AdyenPaymentUtility.createModificationRequest(paymentType, currencyCode, price, merchantAccount, reference, systemIntegratorName);
            // then
            expectedPrice = 100 * Decimal.valueOf(price);
            Assert.areEqual(expectedPrice.longValue(), modificationRequest.amount.value, ASSERT_PRICE_MESSAGE + price);
        }
        // given 3 decimals currency
        currencyCode = 'JOD';
        for (Integer i = 0; i < 10; i++) {
            price = 100.990 + (0.001 * i);
            // when
            modificationRequest = (CheckoutCaptureRequest)AdyenPaymentUtility.createModificationRequest(paymentType, currencyCode, price, merchantAccount, reference, systemIntegratorName);
            // then
            expectedPrice = 1000 * Decimal.valueOf(price);
            Assert.areEqual(expectedPrice.longValue(), modificationRequest.amount.value, ASSERT_PRICE_MESSAGE + price);
        }
        // given no decimals currency
        currencyCode = 'JPY';
        for (Integer i = 0; i < 10; i++) {
            price = 100990 + i;
            // when
            modificationRequest = (CheckoutCaptureRequest)AdyenPaymentUtility.createModificationRequest(paymentType, currencyCode, price, merchantAccount, reference, systemIntegratorName);
            // then
            expectedPrice = Decimal.valueOf(price);
            Assert.areEqual(expectedPrice.longValue(), modificationRequest.amount.value, ASSERT_PRICE_MESSAGE + price);
        }
        // given more decimals than necessary
        currencyCode = 'EUR';
        for (Integer i = 0; i < 10; i++) {
            price = 10.990 + (0.001 * i);
            // when
            modificationRequest = (CheckoutCaptureRequest)AdyenPaymentUtility.createModificationRequest(paymentType, currencyCode, price, merchantAccount, reference, systemIntegratorName);
            // then
            expectedPrice = 100 * Decimal.valueOf(price);
            Assert.areEqual(expectedPrice.longValue(), modificationRequest.amount.value, ASSERT_PRICE_MESSAGE + price);
        }
        // checking other properties
        Assert.areEqual(currencyCode, modificationRequest.amount.currency_x);
        Assert.areEqual(reference, modificationRequest.getReference());
        Assert.areEqual(merchantAccount, modificationRequest.getMerchantAccount());
        Assert.areEqual(systemIntegratorName, modificationRequest.getApplicationInfo().externalPlatform.integrator);
    }

    @IsTest(SeeAllData=true) // for ConnectApi use only
    static void addInvoiceData() {
        Integer productPrice = 100;
        Integer taxValue = 5;
        Decimal percentage = Decimal.valueOf(taxValue)/Decimal.valueOf(productPrice).setScale(4, RoundingMode.HALF_UP);
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
        Decimal percentage = Decimal.valueOf(taxValue)/Decimal.valueOf(productPrice).setScale(4, RoundingMode.HALF_UP);
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
        OrderPaymentSummary orderPaymentSummary = TestDataFactory.createOrderSummaryRecords(order.Id);
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