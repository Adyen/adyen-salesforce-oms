@IsTest
private class AdyenAuthorisationHelperTest {
    @IsTest
    static void createAuthorisationRequestTest() {
        // given
        Adyen_Adapter__mdt adyenAdapterMdt = AdyenPaymentUtility.retrieveAdapterByDeveloperName(AdyenConstants.DEFAULT_ADAPTER_NAME);
        AuthorisationRequest adyenAuthRequest;
        Double price;
        CommercePayments.AuthorizationRequest authRequest;
        Long expectedValue;
        for (Integer i = 0; i < 10; i++) {
            price = 1008.90 + (0.01 * i);
            authRequest = TestDataFactory.createAuthorisationRequest(null, price);
            authRequest.currencyIsoCode = 'USD';
            // when
            adyenAuthRequest = AdyenAuthorisationHelper.createAuthorisationRequest(authRequest, adyenAdapterMdt);
            // then
            expectedValue = (Decimal.valueOf(price) * 100).longValue();
            Assert.areEqual(expectedValue, adyenAuthRequest.amount.value, TestDataFactory.ASSERT_PRICE_MESSAGE + price);
        }
        // given a higher amount of decimals
        for (Integer i = 0; i < 10; i++) {
            price = 1008.900 + (i * 0.001);
            authRequest = TestDataFactory.createAuthorisationRequest(null, price);
            authRequest.currencyIsoCode = 'USD';
            // when
            adyenAuthRequest = AdyenAuthorisationHelper.createAuthorisationRequest(authRequest, adyenAdapterMdt);
            // then
            expectedValue = (Decimal.valueOf(price) * 100).round(RoundingMode.HALF_UP);
            Assert.areEqual(expectedValue, adyenAuthRequest.amount.value, TestDataFactory.ASSERT_PRICE_MESSAGE + price);
        }
        // given 0 decimals currency
        for (Integer i = 0; i < 10; i++) {
            price = 100890 + i;
            authRequest = TestDataFactory.createAuthorisationRequest(null, price);
            authRequest.currencyIsoCode = 'JPY';
            // when
            adyenAuthRequest = AdyenAuthorisationHelper.createAuthorisationRequest(authRequest, adyenAdapterMdt);
            // then
            expectedValue = Decimal.valueOf(price).longValue();
            Assert.areEqual(expectedValue, adyenAuthRequest.amount.value, TestDataFactory.ASSERT_PRICE_MESSAGE + price);
        }
        // given 3 decimals currency
        for (Integer i = 0; i < 10; i++) {
            price = 100.890 + (i * 0.001);
            authRequest = TestDataFactory.createAuthorisationRequest(null, price);
            authRequest.currencyIsoCode = 'JOD';
            // when
            adyenAuthRequest = AdyenAuthorisationHelper.createAuthorisationRequest(authRequest, adyenAdapterMdt);
            // then
            expectedValue = (Decimal.valueOf(price) * 1000).longValue();
            Assert.areEqual(expectedValue, adyenAuthRequest.amount.value, TestDataFactory.ASSERT_PRICE_MESSAGE + price);
        }
    }

    @IsTest
    static void authoriseCardPaymentTest() {
        CardPaymentMethod cardPayMethodRec = TestDataFactory.createCardPaymentMethod();
        insert cardPayMethodRec;

        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());

        Test.startTest();
        CommercePayments.GatewayResponse gatewayResponse = AdyenAuthorisationHelper.authorise(TestDataFactory.createAuthorisationRequest(cardPayMethodRec.Id));
        Test.stopTest();
        
        Assert.isTrue(gatewayResponse.toString().contains(TestDataFactory.TEST_AUTH_CODE));
    }

    @IsTest
    static void authoriseAlternativePaymentTest() {
        AlternativePaymentMethod alternativePayMethodRec = TestDataFactory.createAlternativePaymentMethod();
        insert alternativePayMethodRec;

        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());

        Test.startTest();
        CommercePayments.GatewayResponse gatewayResponse = AdyenAuthorisationHelper.authorise(TestDataFactory.createAuthorisationRequest(alternativePayMethodRec.Id));
        Test.stopTest();
        
        Assert.isTrue(gatewayResponse.toString().contains(TestDataFactory.TEST_AUTH_CODE));
    }

    @IsTest
    static void authorisePaymentFailTest() {
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());

        Test.startTest();
        try {
            AdyenAuthorisationHelper.authorise(TestDataFactory.createAuthorisationRequest(null));
            Assert.fail();
        } catch (Exception ex) {
            Assert.isInstanceOfType(ex, AdyenGatewayAdapter.GatewayException.class);
            Assert.isTrue(ex.getMessage().containsIgnoreCase('400'));
        }
        Test.stopTest();
    }

    @IsTest(SeeAllData = true)
    static void reverseAuthTest() {
        // given
        Account acct = TestDataFactory.createAccount();
        insert acct;
        Order order = TestDataFactory.insertOrderAndRelatedRecords(acct.Id, 33.42, 0.96);
        OrderPaymentSummary orderPaymentSummary = TestDataFactory.createOrderSummaryRecords(order.Id);
        Double price = [SELECT AvailableToCaptureAmount FROM OrderPaymentSummary WHERE Id = :orderPaymentSummary.Id].AvailableToCaptureAmount;
        TestDataFactory.insertBasicPaymentRecords(acct.Id, orderPaymentSummary.Id);
        PaymentAuthorization payAuth = [SELECT Id, GatewayRefNumber FROM PaymentAuthorization WHERE OrderPaymentSummaryId = :orderPaymentSummary.Id];
        CommercePayments.AuthorizationReversalRequest authReversalRequest = new CommercePayments.AuthorizationReversalRequest(price, payAuth.Id);
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.CancelsMockResponse());
        // when
        Test.startTest();
        CommercePayments.GatewayResponse gatewayResponse = AdyenAuthorisationHelper.reverseAuth(authReversalRequest);
        Test.stopTest();
        // then
        Assert.isTrue(gatewayResponse.toString().containsIgnoreCase('cancellation-received'));
    }

    @IsTest(SeeAllData = true)
    static void reverseAuthValidationErrorTest() {
        // no PA with gateway reference
        Account acct = TestDataFactory.createAccount();
        insert acct;
        Order order = TestDataFactory.insertOrderAndRelatedRecords(acct.Id, 33.42, 0.96);
        OrderPaymentSummary orderPaymentSummary = TestDataFactory.createOrderSummaryRecords(order.Id);
        PaymentAuthorization payAuth = TestDataFactory.createPaymentAuthorization(acct.Id, null, null, orderPaymentSummary.Id, null);
        insert payAuth;
        CommercePayments.AuthorizationReversalRequest authReversalRequest = new CommercePayments.AuthorizationReversalRequest(Double.valueOf(1.99), payAuth.Id);
        try {
            AdyenAuthorisationHelper.reverseAuth(authReversalRequest);
            Assert.fail();
        } catch (Exception ex) {
            Assert.areEqual(ex.getMessage(), AdyenAuthorisationHelper.PSP_MISSING_ERROR);
        }
        // Authorization Amount is null
        payAuth = TestDataFactory.createPaymentAuthorization(acct.Id, null, null, orderPaymentSummary.Id, TestDataFactory.TEST_PSP_REFERENCE);
        insert payAuth;
        authReversalRequest = new CommercePayments.AuthorizationReversalRequest(null, payAuth.Id);
        try {
            AdyenAuthorisationHelper.reverseAuth(authReversalRequest);
            Assert.fail();
        } catch (Exception ex) {
            Assert.areEqual(ex.getMessage(), AdyenAuthorisationHelper.AMOUNT_MISSING_ERROR);
        }
        // Amount mismatch
        Decimal availableToCapture = [SELECT AvailableToCaptureAmount FROM OrderPaymentSummary WHERE Id = :orderPaymentSummary.Id].AvailableToCaptureAmount;
        Double price = availableToCapture - 1;
        authReversalRequest = new CommercePayments.AuthorizationReversalRequest(price, payAuth.Id);
        try {
            AdyenAuthorisationHelper.reverseAuth(authReversalRequest);
            Assert.fail();
        } catch (Exception ex) {
            Assert.areEqual(ex.getMessage(), String.format(AdyenAuthorisationHelper.AMOUNT_MISMATCH_ERROR, new List<Object>{price,availableToCapture}));
        }
    }

    @IsTest
    static void createPostAuthResponseTest() {
        // Given
        Double price = 19.99;
        CommercePayments.PostAuthorizationRequest postAuthRequest = new CommercePayments.PostAuthorizationRequest(price);
        postAuthRequest.amount = 5000;
        postAuthRequest.additionalData = new Map<String, String> {
            'pblId' => 'testPblId123'
        };
        
        // When
        CommercePayments.GatewayResponse response = AdyenAuthorisationHelper.createPostAuthResponse(postAuthRequest);

        // Then
        Assert.isTrue(response.toString().contains('success'));
        Assert.isTrue(response.toString().contains('testPblId123'));
    }
}