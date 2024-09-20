public with sharing class AdyenPaymentHelper {
    
    public static String TEST_NOTIFICATION_REQUEST_BODY;
    
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
    
    public static CommercePayments.GatewayNotificationResponse handleAsyncNotificationCallback(CommercePayments.PaymentGatewayNotificationContext gatewayNotificationContext) {
        CommercePayments.PaymentGatewayNotificationRequest paymentGatewayNotificationRequest = Test.isRunningTest() ? null : gatewayNotificationContext.getPaymentGatewayNotificationRequest();
        String adyenNotificationRequestPayload = Test.isRunningTest() ? TEST_NOTIFICATION_REQUEST_BODY : paymentGatewayNotificationRequest.getRequestBody().toString();
        NotificationRequestItem notificationRequestItem = WebhookUtils.parseAdyenNotificationRequest(adyenNotificationRequestPayload);
        Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByMerchantAcct(notificationRequestItem.merchantAccountCode);
        HMACValidator validator;
        try {
            validator = new HMACValidator(notificationRequestItem, adyenAdapter.HMAC_Key__c);
            if (!Test.isRunningTest() && !validator.validateHMAC()) {
                return createAcceptedNotificationResponse('not a valid notification request');
            }
        } catch (HMACValidator.HmacValidationException hmacValidationException) {
            return createAcceptedNotificationResponse(hmacValidationException.getMessage());
        }

        if (!AdyenPaymentUtility.isValidNotification(notificationRequestItem)) {
            return createAcceptedNotificationResponse('no valid psp reference found or webhook type was ignored');
        }

        if (AdyenConstants.NOTIFICATION_REQUEST_TYPE_CANCEL.equalsIgnoreCase(notificationRequestItem.eventCode)) {
            return createAcceptedNotificationResponse('webhook type was ignored');
        }

        if (!AdyenPaymentUtility.relatedPaymentFound(notificationRequestItem.originalReference)) {
            return createAcceptedNotificationResponse('no related payment record found');
        }

        createNotificationSaveResult(notificationRequestItem);
        return createAcceptedNotificationResponse(null);
    }

    private static CommercePayments.GatewayNotificationResponse createAcceptedNotificationResponse(String reason) {
        String responseMessage = AdyenConstants.NOTIFICATION_ACCEPTED_RESPONSE;
        if (!String.isBlank(reason)) {
            responseMessage += ' But not processed, ' + reason;
        }

        CommercePayments.GatewayNotificationResponse gatewayNotificationResponse = new CommercePayments.GatewayNotificationResponse();
        gatewayNotificationResponse.setResponseBody(Blob.valueOf(responseMessage));
        gatewayNotificationResponse.setStatusCode(AdyenConstants.HTTP_SUCCESS_CODE);
        return gatewayNotificationResponse;
    }

    /**
    * Creates and records (ie saves) the notification save result.
    *
    * @param notificationRequestItem parsed from Adyen web hook
    * @return CommercePayments.NotificationSaveResult.
    */
    @TestVisible
    private static CommercePayments.NotificationSaveResult createNotificationSaveResult( NotificationRequestItem notificationRequestItem ) {
        CommercePayments.BaseNotification notification;
        CommercePayments.NotificationStatus notificationStatus;
        CommercePayments.SalesforceResultCode notificationStatusSF;
        String gatewayMessageTemplate;
        Boolean isCaptureRequest = AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE.equalsIgnoreCase(notificationRequestItem.eventCode);
        Boolean isRefundRequest = AdyenConstants.NOTIFICATION_REQUEST_TYPE_REFUND.equalsIgnoreCase(notificationRequestItem.eventCode);
        Boolean isCaptureFailedRequest = AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE_FAILED.endsWithIgnoreCase(notificationRequestItem.eventCode);
        Boolean isRefundFailedRequest = AdyenConstants.NOTIFICATION_REQUEST_TYPE_REFUND_FAILED.endsWithIgnoreCase(notificationRequestItem.eventCode);

        if (isCaptureRequest || isCaptureFailedRequest) {
            notification = new CommercePayments.CaptureNotification();
            gatewayMessageTemplate = '[capture-{0}] {1}';
        } else if (isRefundRequest || isRefundFailedRequest) {
            notification = new CommercePayments.ReferencedRefundNotification();
            gatewayMessageTemplate = '[refund-{0}] {1}';
        } else {
            throw new AdyenGatewayAdapter.GatewayException('Notification of type ' + notificationRequestItem.eventCode + ' does not match criteria');
        }

        String result;
        Boolean isSuccessfulNotification = Boolean.valueOf(notificationRequestItem.success);
        if (isSuccessfulNotification && !isCaptureFailedRequest && !isRefundFailedRequest) {
            notificationStatus = CommercePayments.NotificationStatus.Success;
            notificationStatusSF = CommercePayments.SalesforceResultCode.Success;
            result = 'complete';
        } else {
            notificationStatus = CommercePayments.NotificationStatus.Failed;
            notificationStatusSF = CommercePayments.SalesforceResultCode.Decline;
            result = 'fail';
        }
        String gatewayMessage = String.format(gatewayMessageTemplate, new List<String>{result, notificationRequestItem.reason});
        Decimal priceMinorUnits = notificationRequestItem.amount != null ? notificationRequestItem.amount.value : 0;
        Decimal price = priceMinorUnits / AdyenPaymentUtility.getAmountMultiplier(notificationRequestItem.amount.currency_x);

        notification.setGatewayMessage(gatewayMessage);
        notification.setStatus(notificationStatus);
        notification.setSalesforceResultCodeInfo(new CommercePayments.SalesforceResultCodeInfo(notificationStatusSF));
        notification.setGatewayReferenceNumber(notificationRequestItem.pspReference);
        notification.setGatewayResultCode(notificationRequestItem.eventCode);
        notification.setAmount(Double.valueOf(price));

        return CommercePayments.NotificationClient.record(notification);
    }

    @InvocableMethod
    public static List<PBLPostAuthResponse> callPostAuthorize(List<PBLPostAuthRequest> postAuthRequests) {
        PBLPostAuthRequest postAuthRequestInput = postAuthRequests[0];
        Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByDeveloperName(AdyenConstants.DEFAULT_ADAPTER_NAME);

        Amount amount = new Amount();
        amount.value = (postAuthRequestInput.amount * AdyenPaymentUtility.getAmountMultiplier(postAuthRequestInput.currencyIsoCode)).intValue();
        amount.currency_x = postAuthRequestInput.currencyIsoCode;

        PaymentLinkRequest paymentLinkRequest = AdyenPBLHelper.buildPaymentLinkRequest(adyenAdapter, amount, postAuthRequestInput.accountId);
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
        apmRequest.gatewayTokenDetails = 'PBL Id';
        postAuthRequest.paymentMethod.alternativePaymentMethod = apmRequest;
        postAuthRequest.paymentMethod.alternativePaymentMethod.accountId = postAuthRequestInput.accountId;
        postAuthRequest.paymentMethod.alternativePaymentMethod.name = 'pbl';

        postAuthRequest.paymentGroup = new ConnectApi.PaymentGroupRequest();
        postAuthRequest.paymentGroup.createPaymentGroup = true;
        postAuthRequest.paymentGroup.currencyIsoCode = postAuthRequestInput.currencyIsoCode;

        Map<String, String> additionalData = new Map<String, String> {
            'pblId' => paymentLinkResponse.id
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
        postAuthorizationResponse.gatewayResponse.gatewayResultCode = 'success';
        postAuthorizationResponse.paymentGroup = new ConnectApi.PaymentGroupResponse();
        postAuthorizationResponse.paymentMethod = new ConnectApi.PaymentMethodResponse();
        return postAuthorizationResponse;
    }
    
    public class PBLPostAuthRequest {
        @InvocableVariable(required=true)
        public String paymentGatewayId;
        
        @InvocableVariable(required=true)
        public String accountId;
        
        @InvocableVariable(required=true)
        public String currencyIsoCode;
        
        @InvocableVariable(required=true)
        public Double amount;
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