public with sharing class PaymentLinkGenerateAction {
    @InvocableMethod(Label = 'Create Payment Link' Category = 'Payment Link' Callout = true)
    public static List<PBLCreateResponse> handlePaymentLinkCreation(List<PBLCreateRequest> pblCreateRequests) {
        PBLCreateRequest pblCreateRequest = pblCreateRequests[0];
        Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByDeveloperName(AdyenConstants.DEFAULT_ADAPTER_NAME);

        Amount amount = new Amount();
        amount.value = (pblCreateRequest.amount * AdyenPaymentUtility.getAmountMultiplier(pblCreateRequest.currencyIsoCode)).round(System.RoundingMode.HALF_UP);
        amount.currency_x = pblCreateRequest.currencyIsoCode;

        System.Address sfBillingAddress = (System.Address)JSON.deserialize(pblCreateRequest.billingAddressJson, System.Address.class);
        Address adyenBillingAddress = AdyenPBLHelper.makeAdyenAddressCompatible(sfBillingAddress);
        PaymentLinkRequest paymentLinkRequest = AdyenPBLHelper.buildPaymentLinkRequest(adyenAdapter, amount, pblCreateRequest.merchantReference, adyenBillingAddress);
        PaymentLinkResponse paymentLinkResponse = AdyenPBLHelper.generatePaymentLink(adyenAdapter, paymentLinkRequest);

        PBLCreateResponse linkGenerationResponse = new PBLCreateResponse();
        if (pblCreateRequest.paymentGatewayId != null) { // the presence of a payment gateway id indicates post auth is needed
            ConnectApi.PostAuthorizationResponse postAuthorizationResponse = callPostAuth(pblCreateRequest, paymentLinkResponse.id);
            linkGenerationResponse.paymentMethodId = postAuthorizationResponse.paymentMethod.id;
            linkGenerationResponse.paymentGroupId = postAuthorizationResponse.paymentGroup.id;
        }
        linkGenerationResponse.paymentLink = paymentLinkResponse.url;
        linkGenerationResponse.linkExpiresAt = paymentLinkResponse.expiresAt;
        linkGenerationResponse.expirationDateTime = AdyenPBLHelper.parseDateTime(paymentLinkResponse.expiresAt);
        linkGenerationResponse.paymentLinkId = paymentLinkResponse.id;
        return new List<PBLCreateResponse> { linkGenerationResponse };
    }

    private static ConnectApi.PostAuthorizationResponse callPostAuth(PBLCreateRequest postAuthRequestInput, String paymentLinkId) {
        ConnectApi.PostAuthRequest postAuthRequest = new ConnectApi.PostAuthRequest();
        postAuthRequest.accountId = postAuthRequestInput.accountId;
        postAuthRequest.amount = postAuthRequestInput.amount;
        postAuthRequest.currencyIsoCode = postAuthRequestInput.currencyIsoCode;
        postAuthRequest.effectiveDate = System.now();
        postAuthRequest.paymentGatewayId = postAuthRequestInput.paymentGatewayId;
        postAuthRequest.paymentMethod = new ConnectApi.PostAuthApiPaymentMethodRequest();

        ConnectApi.AlternativePaymentMethod apmRequest = new ConnectApi.AlternativePaymentMethod();
        apmRequest.gatewayToken = paymentLinkId;
        apmRequest.gatewayTokenDetails = AdyenOMSConstants.PBL_GATEWAY_TOKEN_DETAILS;
        postAuthRequest.paymentMethod.alternativePaymentMethod = apmRequest;
        postAuthRequest.paymentMethod.alternativePaymentMethod.accountId = postAuthRequestInput.accountId;
        postAuthRequest.paymentMethod.alternativePaymentMethod.name = AdyenOMSConstants.PBL_PAYMENT_METHOD_NAME;

        postAuthRequest.paymentGroup = new ConnectApi.PaymentGroupRequest();
        postAuthRequest.paymentGroup.createPaymentGroup = true;
        postAuthRequest.paymentGroup.currencyIsoCode = postAuthRequestInput.currencyIsoCode;

        Map<String, String> additionalData = new Map<String, String> {
                AdyenOMSConstants.PBL_ID_KEY => paymentLinkId
        };
        postAuthRequest.additionalData = additionalData;

        return Test.isRunningTest() ? mockPostAuthResponse() : ConnectApi.Payments.postAuth(postAuthRequest);
    }

    @TestVisible
    private static ConnectApi.PostAuthorizationResponse mockPostAuthResponse() {
        ConnectApi.PostAuthorizationResponse postAuthorizationResponse = new ConnectApi.PostAuthorizationResponse();
        postAuthorizationResponse.gatewayResponse = new ConnectApi.PostAuthGatewayResponse();
        postAuthorizationResponse.gatewayResponse.gatewayResultCode = AdyenOMSConstants.GATEWAY_RESULT_SUCCESS;
        postAuthorizationResponse.paymentGroup = new ConnectApi.PaymentGroupResponse();
        postAuthorizationResponse.paymentMethod = new ConnectApi.PaymentMethodResponse();
        return postAuthorizationResponse;
    }

    public class PBLCreateRequest {
        @InvocableVariable
        public Id paymentGatewayId;

        @InvocableVariable
        public Id accountId;

        @InvocableVariable(Required=true)
        public String currencyIsoCode;

        @InvocableVariable(Required=true)
        public Decimal amount;

        @InvocableVariable(Required=true)
        public String merchantReference;

        @InvocableVariable(Required=true)
        public String billingAddressJson;
    }

    public class PBLCreateResponse {
        @InvocableVariable
        public String paymentMethodId;

        @InvocableVariable
        public String paymentGroupId;

        @InvocableVariable
        public String paymentLink;

        @InvocableVariable
        public String linkExpiresAt;

        @InvocableVariable
        public Datetime expirationDateTime;

        @InvocableVariable
        public String paymentLinkId;
    }
}
