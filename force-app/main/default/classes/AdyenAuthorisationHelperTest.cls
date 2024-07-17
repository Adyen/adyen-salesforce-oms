@IsTest
private class AdyenAuthorisationHelperTest {
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
            Assert.isInstanceOfType(ex, AdyenAsyncAdapter.GatewayException.class);
            Assert.isTrue(ex.getMessage().containsIgnoreCase('400'));
        }
        Test.stopTest();
    }
}