public with sharing class AdyenPaymentHelper {
    /**
    *  Receives Payment Gateway Context from AdyenAsyncAdapter, looks at the context type and then invokes the appropriate Capture or Refund operation
    * 
    * @param paymentGatewayContext from commerce api
    * @return `CommercePayments.GatewayResponse`
    */
    public static CommercePayments.GatewayResponse handleFulfillmentOrderStatusChange(CommercePayments.PaymentGatewayContext paymentGatewayContext) {
        CommercePayments.RequestType paymentRequestType = paymentGatewayContext.getPaymentRequestType();
        CommercePayments.PaymentGatewayRequest paymentRequest = paymentGatewayContext.getPaymentRequest();
        
        if (paymentRequestType == CommercePayments.RequestType.Authorize) {
            return AdyenAuthorisationHelper.authorise((CommercePayments.AuthorizationRequest)paymentRequest);
        } else if (paymentRequestType == CommercePayments.RequestType.PostAuth) {
            return AdyenAuthorisationHelper.createPostAuthResponse((CommercePayments.PostAuthorizationRequest) paymentRequest);
        } else if (paymentRequestType == CommercePayments.RequestType.AuthorizationReversal) {
            return AdyenAuthorisationHelper.reverseAuth((CommercePayments.AuthorizationReversalRequest)paymentRequest);
        } else if (paymentRequestType == CommercePayments.RequestType.Capture) {
            return AdyenCaptureHelper.capture((CommercePayments.CaptureRequest)paymentRequest);
        } else if (paymentRequestType == CommercePayments.RequestType.ReferencedRefund) {
            return AdyenRefundHelper.refund((CommercePayments.ReferencedRefundRequest)paymentRequest);
        } else {
            CommercePayments.GatewayResponse paymentGatewayResponse;
            return paymentGatewayResponse;
        }
    }

    @InvocableMethod
    public static List<PBLPostAuthResponse> callPostAuthorize(List<PBLPostAuthRequest> postAuthRequests) {
        PBLPostAuthRequest postAuthRequestInput = postAuthRequests[0];
        Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByDeveloperName(AdyenConstants.DEFAULT_ADAPTER_NAME);

        Amount amount = new Amount();
        amount.value = (postAuthRequestInput.amount * AdyenPaymentUtility.getAmountMultiplier(postAuthRequestInput.currencyIsoCode)).round(System.RoundingMode.HALF_UP);
        amount.currency_x = postAuthRequestInput.currencyIsoCode;

        PaymentLinkRequest paymentLinkRequest = AdyenPBLHelper.buildPaymentLinkRequest(adyenAdapter, amount, postAuthRequestInput.cartId);
        PaymentLinkResponse paymentLinkResponse = AdyenPBLHelper.generatePaymentLink(adyenAdapter, paymentLinkRequest);

        ConnectApi.PostAuthRequest postAuthRequest = new ConnectApi.PostAuthRequest();
        postAuthRequest.accountId = postAuthRequestInput.accountId;
        postAuthRequest.amount = postAuthRequestInput.amount;
        postAuthRequest.currencyIsoCode = postAuthRequestInput.currencyIsoCode;
        postAuthRequest.effectiveDate = System.now();
        postAuthRequest.paymentGatewayId = postAuthRequestInput.paymentGatewayId;
        postAuthRequest.paymentMethod = new ConnectApi.PostAuthApiPaymentMethodRequest();

        ConnectApi.AlternativePaymentMethod apmRequest = new ConnectApi.AlternativePaymentMethod();
        apmRequest.gatewayToken = paymentLinkResponse.id;
        apmRequest.gatewayTokenDetails = AdyenOMSConstants.PBL_GATEWAY_TOKEN_DETAILS;
        postAuthRequest.paymentMethod.alternativePaymentMethod = apmRequest;
        postAuthRequest.paymentMethod.alternativePaymentMethod.accountId = postAuthRequestInput.accountId;
        postAuthRequest.paymentMethod.alternativePaymentMethod.name = AdyenOMSConstants.PBL_PAYMENT_METHOD_NAME;

        postAuthRequest.paymentGroup = new ConnectApi.PaymentGroupRequest();
        postAuthRequest.paymentGroup.createPaymentGroup = true;
        postAuthRequest.paymentGroup.currencyIsoCode = postAuthRequestInput.currencyIsoCode;

        Map<String, String> additionalData = new Map<String, String> {
            AdyenOMSConstants.PBL_ID_KEY => paymentLinkResponse.id
        };
        postAuthRequest.additionalData = additionalData;

        ConnectApi.PostAuthorizationResponse postAuthorizationResponse = Test.isRunningTest() ? mockPostAuthResponse() : ConnectApi.Payments.postAuth(postAuthRequest);

        PBLPostAuthResponse postAuthResponse = new PBLPostAuthResponse();
        postAuthResponse.paymentMethodId = postAuthorizationResponse.paymentMethod.id;
        postAuthResponse.paymentGroupId = postAuthorizationResponse.paymentGroup.id;
        postAuthResponse.paymentLink = paymentLinkResponse.url;
        postAuthResponse.linkExpiresAt = paymentLinkResponse.expiresAt;
        return new List<PBLPostAuthResponse> { postAuthResponse };
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
    
    public class PBLPostAuthRequest {
        @InvocableVariable(Required=true)
        public String paymentGatewayId;
        
        @InvocableVariable(Required=true)
        public String accountId;
        
        @InvocableVariable(Required=true)
        public String currencyIsoCode;
        
        @InvocableVariable(Required=true)
        public Decimal amount;

        @InvocableVariable(Required=true)
        public String cartId;
    }

    public class PBLPostAuthResponse {
        @InvocableVariable
        public String paymentMethodId;
        
        @InvocableVariable
        public String paymentGroupId;

        @InvocableVariable
        public String paymentLink;

        @InvocableVariable
        public String linkExpiresAt;
    }
}