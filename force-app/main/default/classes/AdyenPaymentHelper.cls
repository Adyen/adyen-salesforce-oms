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
}
