@isTest
private class AdyenConfigPageControllerTest {

    @isTest
    static void createPaymentGatewaysValidInputTest() {
        // Given
        List<AdyenConfigPageController.PaymentGatewayInput> inputs = new List<AdyenConfigPageController.PaymentGatewayInput>();
        AdyenConfigPageController.PaymentGatewayInput input1 = new AdyenConfigPageController.PaymentGatewayInput();
        input1.gatewayName = 'Gateway1';
        input1.externalReference = AdyenOMSConstants.PAYMENT_INSTRUMENT_ADYEN_COMPONENT;

        AdyenConfigPageController.PaymentGatewayInput input2 = new AdyenConfigPageController.PaymentGatewayInput();
        input2.gatewayName = 'Gateway2';
        input2.externalReference = AdyenOMSConstants.PAYMENT_INSTRUMENT_ADYEN_POS;

        inputs.add(input1);
        inputs.add(input2);

        // When
        List<Id> createdGatewayIds = AdyenConfigPageController.createPaymentGateways(inputs);

        // Then
        Assert.areNotEqual(createdGatewayIds, null);
        Assert.areEqual(createdGatewayIds.size(), 2);
    }

    @isTest
    static void createPaymentGatewaysMissingNameOrExternalRefTest() {
        // Given
        List<AdyenConfigPageController.PaymentGatewayInput> inputs = new List<AdyenConfigPageController.PaymentGatewayInput>();
        AdyenConfigPageController.PaymentGatewayInput input1 = new AdyenConfigPageController.PaymentGatewayInput();
        input1.gatewayName = '';
        input1.externalReference = AdyenOMSConstants.PAYMENT_INSTRUMENT_ADYEN_COMPONENT;
        inputs.add(input1);

        // When & Then
        try {
            AdyenConfigPageController.createPaymentGateways(inputs);
            Assert.fail('Expected exception was not thrown');
        } catch (AuraHandledException e) {
            Assert.areEqual(e.getMessage(), 'Script-thrown exception');
        }
    }

    @isTest
    static void createPaymentGatewaysNullOrEmptyInputTest() {
        // Given & When
        try {
            AdyenConfigPageController.createPaymentGateways(null);
            Assert.fail('Expected exception was not thrown');
        } catch (AuraHandledException e) {
            // Then
            Assert.areEqual(e.getMessage(), 'Script-thrown exception');
        }

        // Given & When
        List<AdyenConfigPageController.PaymentGatewayInput> inputs = new List<AdyenConfigPageController.PaymentGatewayInput>();
        try {
            AdyenConfigPageController.createPaymentGateways(inputs);
            Assert.fail('Expected exception was not thrown');
        } catch (AuraHandledException e) {
            // Then
            Assert.areEqual(e.getMessage(), 'Script-thrown exception');
        }
    }

    @isTest
    static void getSetupPageUrlsTest() {
        // Given
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();

        // When
        Test.startTest();
        Map<String, String> urls = AdyenConfigPageController.getSetupPageUrls();
        Test.stopTest();

        // Then
        Assert.areNotEqual(null, urls);
        Assert.areEqual(3, urls.size());

        Assert.isTrue(urls.containsKey('checkoutNamedCredential'));
        Assert.isTrue(urls.containsKey('managementApiNamedCredential'));
        Assert.isTrue(urls.containsKey('permissionSet'));
        Assert.isTrue(urls.get('checkoutNamedCredential').startsWith(baseUrl + '/lightning/setup/NamedCredential/'));
        Assert.isTrue(urls.get('managementApiNamedCredential').startsWith(baseUrl + '/lightning/setup/NamedCredential/'));
    }
}