@IsTest
private class PaymentLinkGenerateActionTest {
    @IsTest(SeeAllData=true)
    static void callPostAuthorizeTest() {
        // Given
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        PaymentLinkGenerateAction.PBLCreateRequest postAuthRequest = new PaymentLinkGenerateAction.PBLCreateRequest();
        postAuthRequest.paymentGatewayId = null;
        postAuthRequest.accountId = testAccount.Id;
        postAuthRequest.currencyIsoCode = 'EUR';
        postAuthRequest.amount = 55.55;
        postAuthRequest.billingAddressJson = TestDataFactory.NL_JSON_ADDRESS;

        List<PaymentLinkGenerateAction.PBLCreateRequest> postAuthRequests = new List<PaymentLinkGenerateAction.PBLCreateRequest>{ postAuthRequest };
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.PBLMockResponse());
        // when
        List<PaymentLinkGenerateAction.PBLCreateResponse> postAuthResponses =  PaymentLinkGenerateAction.callPostAuthorize(postAuthRequests);
        Test.stopTest();

        // then
        Assert.isTrue(postAuthResponses.size() == 1);
        Assert.areEqual('https://test.payment.link', postAuthResponses[0].paymentLink);
        Assert.areEqual('2024-01-01T12:00:00+00:00', postAuthResponses[0].linkExpiresAt);
        Assert.areEqual(AdyenPBLHelper.parseDateTime('2024-01-01T12:00:00+00:00'), postAuthResponses[0].expirationDateTime);
        Assert.areEqual('PLE5B4575C5A026A2B2', postAuthResponses[0].paymentLinkId);
    }
}
