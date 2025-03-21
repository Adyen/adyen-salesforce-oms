public with sharing class AdyenNotificationHandler {
    public static String TEST_NOTIFICATION_REQUEST_BODY;

    public static CommercePayments.GatewayNotificationResponse handleAsyncNotificationCallback(CommercePayments.PaymentGatewayNotificationContext gatewayNotificationContext) {
        CommercePayments.PaymentGatewayNotificationRequest paymentGatewayNotificationRequest = Test.isRunningTest() ? null : gatewayNotificationContext.getPaymentGatewayNotificationRequest();
        String adyenNotificationRequestPayload = Test.isRunningTest() ? TEST_NOTIFICATION_REQUEST_BODY : paymentGatewayNotificationRequest.getRequestBody().toString();

        NotificationRequestItem notificationRequestItem = WebhookUtils.parseAdyenNotificationRequest(adyenNotificationRequestPayload);
        Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByMerchantAcct(notificationRequestItem.merchantAccountCode);
        HMACValidator validator;
        try {
            validator = new HMACValidator(notificationRequestItem, adyenAdapter.HMAC_Key__c);
            if (!Test.isRunningTest() && !validator.validateHMAC()) {
                return createErrorResponse(AdyenOMSConstants.INVALID_NOTIFICATION, 403);
            }
        } catch (HMACValidator.HmacValidationException hmacValidationException) {
            return createErrorResponse(hmacValidationException.getMessage(), 403);
        }

        if (!AdyenPaymentUtility.isValidNotification(notificationRequestItem)) {
            return createAcceptedNotificationResponse('no valid psp reference found or webhook type was ignored');
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

    private static CommercePayments.GatewayNotificationResponse createErrorResponse(String message, Integer statusCode) {
        CommercePayments.GatewayNotificationResponse gatewayNotificationResponse = new CommercePayments.GatewayNotificationResponse();
        gatewayNotificationResponse.setResponseBody(Blob.valueOf(message));
        gatewayNotificationResponse.setStatusCode(statusCode);
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
}