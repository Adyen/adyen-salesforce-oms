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
        Assert.areEqual(8, urls.size());

        Assert.isTrue(urls.containsKey('checkoutNamedCredential'));
        Assert.isTrue(urls.containsKey('managementApiNamedCredential'));
        Assert.isTrue(urls.containsKey('permissionSet'));
        Assert.isTrue(urls.containsKey('salesChannelLayouts'));
        Assert.isTrue(urls.containsKey('paymentLayouts'));
        Assert.isTrue(urls.containsKey('paymentAuthorizationLayouts'));
        Assert.isTrue(urls.get('checkoutNamedCredential').startsWith(baseUrl + '/lightning/setup/NamedCredential/'));
        Assert.isTrue(urls.get('managementApiNamedCredential').startsWith(baseUrl + '/lightning/setup/NamedCredential/'));
        Assert.isTrue(urls.get('webhookNamedCredential').startsWith(baseUrl + '/lightning/setup/NamedCredential/'));
        Assert.isTrue(urls.get('salesChannelLayouts').startsWith(baseUrl + '/lightning/setup/ObjectManager/SalesChannel/PageLayouts/'));
        Assert.isTrue(urls.get('paymentLayouts').startsWith(baseUrl + '/lightning/setup/ObjectManager/Payment/PageLayouts/'));
        Assert.isTrue(urls.get('paymentAuthorizationLayouts').startsWith(baseUrl + '/lightning/setup/ObjectManager/PaymentAuthorization/PageLayouts/'));
    }

    @isTest 
    static void testGetPermissionSetUrls() {
        // Given
        List<PermissionSet> existingPermSets = [
            SELECT Id
            FROM PermissionSet 
            WHERE Name = :AdyenOMSConstants.ORDER_MANAGEMENT_B2C_SERVICE_PERMISSION_SET
            LIMIT 1
        ];
        
        PermissionSet permSet;
        if (existingPermSets.isEmpty()) {
            permSet = new PermissionSet(
                Name = AdyenOMSConstants.ORDER_MANAGEMENT_B2C_SERVICE_PERMISSION_SET,
                Label = 'OMS Order Management B2C Service'
            );
            insert permSet;
        } else {
            
            permSet = existingPermSets[0];
        }
        
        // When
        Test.startTest();
        Map<String, String> urls = AdyenConfigPageController.getPermissionSetUrls();
        Test.stopTest();
        
        // Then
        Assert.isNotNull(urls);
        Assert.isTrue(urls.containsKey('omsB2cPermissionSetUrl'));
        Assert.isTrue(urls.get('omsB2cPermissionSetUrl').contains(permSet.Id));
        
    }

    @isTest
    static void testIsProductionOrg() {
        // Given
        Organization currentOrg = [SELECT IsSandbox, OrganizationType FROM Organization LIMIT 1];

        // When
        Test.startTest();
        Boolean result = AdyenConfigPageController.isProductionOrg();
        Test.stopTest();

        // Then
        
        Boolean expectedResult = !currentOrg.IsSandbox && currentOrg.OrganizationType != 'Developer Edition';
        System.assertEquals(expectedResult, result, 'The isProductionOrg method should correctly reflect the current org type.');
    }
}