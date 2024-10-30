@IsTest
private class AdyenPBLHelperTest {

    @IsTest
    static void buildPaymentLinkRequestSuccessTest() {
        // Given
        Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByDeveloperName(AdyenConstants.DEFAULT_ADAPTER_NAME);
        Amount amount = new Amount();
        amount.currency_x = 'EUR';
        amount.value = 1000;
        String reference = 'TestReference123';

        // When
        PaymentLinkRequest paymentLinkRequest = AdyenPBLHelper.buildPaymentLinkRequest(adyenAdapter, amount, reference);

        // Then
        Assert.areNotEqual(null, paymentLinkRequest);
        Assert.areEqual(amount, paymentLinkRequest.amount);
        Assert.areEqual(reference, paymentLinkRequest.reference);
        Assert.areEqual(adyenAdapter.Merchant_Account__c, paymentLinkRequest.merchantAccount);
        Assert.areEqual(adyenAdapter.Payment_Link_Return_Url__c, paymentLinkRequest.returnUrl);
        Assert.areEqual(adyenAdapter.Payment_Link_Theme_Id__c, paymentLinkRequest.themeId);
    }

    @IsTest
    static void generatePaymentLinkSuccessTest() {
        // Given
        Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByDeveloperName(AdyenConstants.DEFAULT_ADAPTER_NAME);
        Amount amount = new Amount();
        amount.currency_x = 'USD';
        amount.value = 2000;
        String reference = 'TestReference456';

        PaymentLinkRequest paymentLinkRequest = AdyenPBLHelper.buildPaymentLinkRequest(adyenAdapter, amount, reference);

        Test.setMock(HttpCalloutMock.class, new TestDataFactory.PBLMockResponse());

        // When
        PaymentLinkResponse response = AdyenPBLHelper.generatePaymentLink(adyenAdapter, paymentLinkRequest);

        // Then
        Assert.areNotEqual(null, response);
        Assert.areEqual('https://test.payment.link', response.url);
        Assert.areEqual('2024-01-01T12:00:00+00:00', response.expiresAt);
    }

    @IsTest
    static void generatePaymentLinkNullParametersTest() {
        // Given
        Adyen_Adapter__mdt adyenAdapter = null;
        PaymentLinkRequest paymentLinkRequest = null;

        // When/Then
        try {
            AdyenPBLHelper.generatePaymentLink(adyenAdapter, paymentLinkRequest);
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            Assert.isInstanceOfType(e, IllegalArgumentException.class);
        }
    }

    @IsTest
    static void generatePaymentLinkErrorResponseTest() {
        // Given
        Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByDeveloperName(AdyenConstants.DEFAULT_ADAPTER_NAME);
        Amount amount = new Amount();
        amount.currency_x = 'EUR';
        amount.value = 2000;
        String reference = 'TestReference789';

        PaymentLinkRequest paymentLinkRequest = AdyenPBLHelper.buildPaymentLinkRequest(adyenAdapter, amount, reference);

        Test.setMock(HttpCalloutMock.class, new TestDataFactory.FailureResponse());

        // When/Then
        try {
            AdyenPBLHelper.generatePaymentLink(adyenAdapter, paymentLinkRequest);
            Assert.fail('Expected Exception was not thrown');
        } catch (Exception e) {
            Assert.isInstanceOfType(e, AdyenGatewayAdapter.GatewayException.class);
        }
    }

    @IsTest
    static void testGetLinkExpiryDate() {
        // Given
        Integer days = 5;

        // When
        String expectedDate = Datetime.now().addDays(days).format('yyyy-MM-dd\'T\'HH:mm:ssXXX');
        String expiryDate = AdyenPBLHelper.getLinkExpiryDate(days);

        // Then
        Assert.isTrue(expiryDate.contains(expectedDate), 'Expiry date should contain the correct future date.');
    }
}
