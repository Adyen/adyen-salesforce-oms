public with sharing class AdyenPaymentHelper {
    
    public static String TEST_NOTIFICATION_REQUEST_BODY;
    
    /**
    *  Receives Payment Gateway Context from AdyenAsyncAdapter, looks at the context type and then invokes the appropriate Capture or Refund operation
    * 
    * @param paymentGatewayContext
    * @returns `CommercePayments.GatewayResponse`
    */
    public static CommercePayments.GatewayResponse handleFulfillmentOrderStatusChange(CommercePayments.paymentGatewayContext paymentGatewayContext) {
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
        System.debug('----> Entering AdyenPaymentHelper.handleAsyncNotificationCallback PaymentGatewayNotificationContext= ' + gatewayNotificationContext);
        CommercePayments.PaymentGatewayNotificationRequest paymentGatewayNotificationRequest = Test.isRunningTest() ? null : gatewayNotificationContext.getPaymentGatewayNotificationRequest();
        CommercePayments.GatewayNotificationResponse gatewayNotificationResponse = new CommercePayments.GatewayNotificationResponse();
        
        CommercePayments.NotificationSaveResult notificationSaveResult;
        NotificationRequestItem notificationRequestItem = parseAdyenNotificationRequest( paymentGatewayNotificationRequest );
        String adapterIdFromNotificationData;
        if (notificationRequestItem.originalReference != null) {
            adapterIdFromNotificationData = AdyenPaymentUtility.retrieveApexAdapterId(notificationRequestItem.originalReference);
        }
        
        Id adyenAdapterId = [SELECT Id FROM ApexClass WHERE Name = :apexName AND (NamespacePrefix = :AdyenOMSConstants.ADYEN_2GP_NAMESPACE OR NamespacePrefix = '') LIMIT 1].Id;
        
        if(adapterIdFromNotificationData == adyenAdapterId) {
            
            notificationSaveResult = createNotificationSaveResult( notificationRequestItem );
            
            if (notificationSaveResult != null) {
                if(notificationSaveResult.isSuccess()){ // Notification is accepted by the platform
                    gatewayNotificationResponse.setStatusCode(AdyenConstants.HTTP_SUCCESS_CODE);
                    gatewayNotificationResponse.setResponseBody(Blob.valueOf(AdyenConstants.NOTIFICATION_ACCEPTED_RESPONSE ));
                    System.debug('----> Exiting AdyenPaymentHelper.handleAsyncNotificationCallback after the notification is accepted: ' + gatewayNotificationResponse);
                    return gatewayNotificationResponse;
                } else { // Notification is not accepted by the platform, generate system event
                    gatewayNotificationResponse.setStatusCode(integer.valueOf(AdyenConstants.HTTP_SERVER_ERROR_CODE));
                    String msg = '[accepted] ';
                    if (notificationSaveResult != null && notificationSaveResult.getErrorMessage() != null) {
                        msg += notificationSaveResult.getErrorMessage();
                    }
                    gatewayNotificationResponse.setResponseBody(Blob.valueOf(msg));
                    return gatewayNotificationResponse;
                }
            } else {
                String msg = '[accepted] But unsupported notification type: ' + notificationRequestItem.eventCode;
                gatewayNotificationResponse.setResponseBody(Blob.valueOf( msg ));
                gatewayNotificationResponse.setStatusCode(AdyenConstants.HTTP_SUCCESS_CODE);
                return gatewayNotificationResponse;
            }
            
        } else {
            String msg = '[accepted] ';
            if (notificationRequestItem.originalReference == null) {
                msg += 'Notification skipped, original reference is not available';
                gatewayNotificationResponse.setResponseBody(Blob.valueOf(msg));
                gatewayNotificationResponse.setStatusCode(AdyenConstants.HTTP_SUCCESS_CODE);
                System.debug('----> Exiting AdyenPaymentHelper.handleAsyncNotificationCallback, originalReference is n/a: ' + gatewayNotificationResponse);
            } else {
                msg += 'But not processed - wrong payment adapter or wrong instance';
                gatewayNotificationResponse.setResponseBody(Blob.valueOf(msg));
                gatewayNotificationResponse.setStatusCode(AdyenConstants.HTTP_SUCCESS_CODE);
                System.debug('----> Exiting AdyenPaymentHelper.handleAsyncNotificationCallback after identifying that it was the wrong payment adapter: ' + gatewayNotificationResponse);
            }
            return gatewayNotificationResponse;
        }
    }
    
    /**
    * Take the http request from the async notification callback and deserializes it into AdyenNotificationResponse.
    *
    * @param adyenNotificationRequestPayload   The body of the Adyen notification request.
    * @return AdyenNotificationRequest         The deserialized version of the Adyen nodification request.
    *
    * @see https://docs.adyen.com/development-resources/webhooks/understand-notifications
    */
    public static NotificationRequestItem parseAdyenNotificationRequest(CommercePayments.PaymentGatewayNotificationRequest notificationRequest) {
        String adyenNotificationRequestPayload = Test.isRunningTest() ? TEST_NOTIFICATION_REQUEST_BODY : AdyenPaymentUtility.makeSalesforceCompatible(notificationRequest.getRequestBody().toString());
        AdyenNotification adyenNotification  = (AdyenNotification) JSON.deserialize(adyenNotificationRequestPayload, AdyenNotification.class);
        NotificationRequestItem notificationRequestItem = new NotificationRequestItem();
        if(adyenNotification != null) {
            for(NotificationItems notificationItem : adyenNotification.notificationItems) {
                if(notificationItem.NotificationRequestItem != null) {
                    notificationRequestItem = notificationItem.NotificationRequestItem;
                }
            }
        }
        return notificationRequestItem;
    }
    
    
    /**
    * Creates and records (ie saves) the notificationsaveresult.
    *
    * @param adyenNotificationResponse
    * @return CommercePayments.NotificationSaveResult.
    */
    private static CommercePayments.NotificationSaveResult createNotificationSaveResult( NotificationRequestItem notificationRequestItem ) {
        Boolean unsupportedNotificationType = false;
        CommercePayments.BaseNotification notification = null;
        CommercePayments.NotificationStatus notificationStatus = null;
        CommercePayments.SalesforceResultCode notificationStatusSF = null;
        
        if (!Boolean.valueOf(notificationRequestItem.success)){
            notificationStatus = CommercePayments.NotificationStatus.Failed;
            notificationStatusSF = CommercePayments.SalesforceResultCode.Decline;
        } else {
            notificationStatus = CommercePayments.NotificationStatus.Success;
            notificationStatusSF = CommercePayments.SalesforceResultCode.Success;
        }
        
        if (AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE.equalsIgnoreCase(notificationRequestItem.eventCode)) {
            notification = new CommercePayments.CaptureNotification();
        } else if (AdyenConstants.NOTIFICATION_REQUEST_TYPE_REFUND.equalsIgnoreCase(notificationRequestItem.eventCode)) {
            notification = new CommercePayments.ReferencedRefundNotification();
        } else {
            unsupportedNotificationType = true;
        }
        
        CommercePayments.NotificationSaveResult notificationSaveResult;
        if(!unsupportedNotificationType) {
            notification.setStatus(notificationStatus);
            notification.setSalesforceResultCodeInfo(new CommercePayments.SalesforceResultCodeInfo(notificationStatusSF));
            notification.setGatewayReferenceNumber(notificationRequestItem.pspReference);
            notification.setGatewayResultCode(notificationRequestItem.eventCode);
            notification.setGatewayResultCodeDescription(notificationRequestItem.reason);
            if(String.isBlank(notificationRequestItem.reason) && notificationStatus == CommercePayments.NotificationStatus.Success) {
                if (AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE.equalsIgnoreCase(notificationRequestItem.eventCode)) {
                    notification.setGatewayMessage('[capture-complete]');
                } else if (AdyenConstants.NOTIFICATION_REQUEST_TYPE_REFUND.equalsIgnoreCase(notificationRequestItem.eventCode)) {
                    notification.setGatewayMessage('[refund-complete]');
                }
            } else{
                notification.setGatewayMessage(notificationRequestItem.reason);
            }
            
            Decimal value;
            if(notificationRequestItem.amount != null) {
                value = notificationRequestItem.amount.value;
            }
            value = value / AdyenPaymentUtility.getAmountMultiplier(notificationRequestItem.amount.currency_x);
            
            Double dValue = value;
            notification.setAmount(dValue);
            notificationSaveResult = CommercePayments.NotificationClient.record(notification);
            System.debug(JSON.serialize(notificationSaveResult));
            return notificationSaveResult;
        } else {
            notificationSaveResult = null;
            System.debug('---> Exiting AdyenPaymentHelper.createNotificationSaveResult after ignoring unsupported notification= ' + notificationRequestItem.eventCode);
            return notificationSaveResult;
        }
    }
}