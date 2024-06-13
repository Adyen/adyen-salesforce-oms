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
        
        if(paymentRequestType == CommercePayments.RequestType.Authorize){
            return AdyenAuthorisationHelper.authorise((CommercePayments.AuthorizationRequest)paymentRequest);
        } else if (paymentRequestType == CommercePayments.RequestType.Capture) {
            return AdyenCaptureHelper.capture((CommercePayments.CaptureRequest)paymentRequest);
        } else if (paymentRequestType == CommercePayments.RequestType.ReferencedRefund) {
            return AdyenRefundHelper.refund((CommercePayments.ReferencedRefundRequest)paymentRequest);
        } else {
            CommercePayments.GatewayResponse paymentGatewayResponse;
            return paymentGatewayResponse;
        }
    }
    
    public static CommercePayments.GatewayNotificationResponse handleAsyncNotificationCallback(CommercePayments.PaymentGatewayNotificationContext gatewayNotificationContext, String apexName) {
        CommercePayments.PaymentGatewayNotificationRequest paymentGatewayNotificationRequest = Test.isRunningTest() ? null : gatewayNotificationContext.getPaymentGatewayNotificationRequest();
        NotificationRequestItem notificationRequestItem = parseAdyenNotificationRequest( paymentGatewayNotificationRequest );

        if (notificationRequestItem.originalReference == null) {
            String msg = '[accepted] Notification skipped, original reference is not available';
            return createNotificationResponse(msg, AdyenConstants.HTTP_SUCCESS_CODE);
        }

        String adapterIdFromNotificationData = AdyenPaymentUtility.retrieveApexAdapterId(notificationRequestItem.originalReference);
        Id adyenAdapterId = [SELECT Id FROM ApexClass WHERE Name = :apexName AND (NamespacePrefix = :AdyenOMSConstants.ADYEN_2GP_NAMESPACE OR NamespacePrefix = '') LIMIT 1].Id;
        Boolean isAdapterSameAsThis = adapterIdFromNotificationData == adyenAdapterId;
        if (isAdapterSameAsThis) {
            CommercePayments.NotificationSaveResult notificationSaveResult = createNotificationSaveResult( notificationRequestItem );
            if (notificationSaveResult != null) {
                return createNotificationResponse(AdyenConstants.NOTIFICATION_ACCEPTED_RESPONSE, AdyenConstants.HTTP_SUCCESS_CODE);
            } else {
                String msg = '[accepted] But unsupported notification type: ' + notificationRequestItem.eventCode;
                return createNotificationResponse(msg, AdyenConstants.HTTP_SUCCESS_CODE);
            }
        } else {
            String msg = '[accepted] But not processed - wrong payment adapter or wrong instance';
            return createNotificationResponse(msg, AdyenConstants.HTTP_SUCCESS_CODE);
        }
    }

    private static CommercePayments.GatewayNotificationResponse createNotificationResponse(String message, Integer httpCode) {
        CommercePayments.GatewayNotificationResponse gatewayNotificationResponse = new CommercePayments.GatewayNotificationResponse();
        gatewayNotificationResponse.setResponseBody(Blob.valueOf(message));
        gatewayNotificationResponse.setStatusCode(httpCode);
        return gatewayNotificationResponse;
    }
    
    /**
    * Take the http request from the async notification callback and deserializes it into AdyenNotificationResponse.
    *
    * @param notificationRequest The body of the Adyen notification request.
    * @return AdyenNotificationRequest  The deserialized version of the Adyen notification request.
    *
    * @see https://docs.adyen.com/development-resources/webhooks/understand-notifications
    */
    public static NotificationRequestItem parseAdyenNotificationRequest(CommercePayments.PaymentGatewayNotificationRequest notificationRequest) {
        System.debug('Notification Request From Commerce');
        System.debug(notificationRequest);
        String adyenNotificationRequestPayload = Test.isRunningTest() ? TEST_NOTIFICATION_REQUEST_BODY : AdyenPaymentUtility.makeSalesforceCompatible(notificationRequest.getRequestBody().toString());
        AdyenNotification adyenNotification  = (AdyenNotification) JSON.deserialize(adyenNotificationRequestPayload, AdyenNotification.class);
        NotificationRequestItem notificationRequestItem = new NotificationRequestItem();
        if (adyenNotification != null) {
            for (NotificationItems notificationItem : adyenNotification.notificationItems) {
                if (notificationItem.NotificationRequestItem != null) {
                    notificationRequestItem = notificationItem.NotificationRequestItem;
                }
            }
        }
        return notificationRequestItem;
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
        if (isCaptureRequest || isCaptureFailedRequest) {
            notification = new CommercePayments.CaptureNotification();
            gatewayMessageTemplate = '[capture-{0}] {1}';
        } else if (isRefundRequest) {
            notification = new CommercePayments.ReferencedRefundNotification();
            gatewayMessageTemplate = '[refund-{0}] {1}';
        } else {
            return null; // unsupported notification request
        }

        String result;
        Boolean isSuccessfulNotification = Boolean.valueOf(notificationRequestItem.success);
        if (isSuccessfulNotification && !isCaptureFailedRequest) {
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