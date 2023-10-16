@isTest
private class AdyenAuthorisationHelperTest {

    @isTest
    static void authoriseCardPaymentTest() {
        CardPaymentMethod cardPayMethodRec = TestDataFactory.createCardPaymentMethod();
        insert cardPayMethodRec;

        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());

        Test.startTest();
        CommercePayments.GatewayResponse gatewayResponse = AdyenAuthorisationHelper.authorise(TestDataFactory.createAuthorisationRequest(cardPayMethodRec.Id));
        Test.stopTest();
        
        Assert.isTrue(gatewayResponse.toString().contains(TestDataFactory.TEST_AUTH_CODE));
    }

    @isTest
    static void authoriseAlternativePaymentTest() {
        AlternativePaymentMethod alternativePayMethodRec = TestDataFactory.createAlternativePaymentMethod();
        insert alternativePayMethodRec;

        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());

        Test.startTest();
        CommercePayments.GatewayResponse gatewayResponse = AdyenAuthorisationHelper.authorise(TestDataFactory.createAuthorisationRequest(alternativePayMethodRec.Id));
        Test.stopTest();
        
        Assert.isTrue(gatewayResponse.toString().contains(TestDataFactory.TEST_AUTH_CODE));
    }

    @isTest
    static void authorisePaymentFailTest() {
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.EchoHttpMock());

        Test.startTest();
        CommercePayments.GatewayResponse gatewayResponse = AdyenAuthorisationHelper.authorise(TestDataFactory.createAuthorisationRequest(null));
        Test.stopTest();
        
        Assert.isFalse(gatewayResponse.toString().contains(TestDataFactory.TEST_AUTH_CODE));
    }
}