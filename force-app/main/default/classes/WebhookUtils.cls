public with sharing class WebhookUtils {
    public static NotificationRequestItem parseAdyenNotificationRequest(String notificationRequestBody) {
        if (String.isBlank(notificationRequestBody)) {
            throw new AdyenGatewayAdapter.GatewayException('Notification Request Body is invalid');
        }
        String notificationRequestCompatibleBody = AdyenPaymentUtility.makeSalesforceCompatible(notificationRequestBody);
        AdyenNotification adyenNotification  = (AdyenNotification) JSON.deserialize(notificationRequestCompatibleBody, AdyenNotification.class);
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

    public static String getPaymentGatewayProviderId() {
        List<PaymentGatewayProvider> gatewayProviders = [
            SELECT Id
            FROM PaymentGatewayProvider
            WHERE DeveloperName = :AdyenOMSConstants.PAYMENT_GATEWAY_PROVIDER
            LIMIT 1
        ];
        return gatewayProviders.isEmpty() ? null : gatewayProviders[0].Id;
    }

    public static Boolean isStandardOMSNotification(NotificationRequestItem requestItem) {
        if (!AdyenPaymentUtility.isValidNotification(requestItem)) {
            return false;
        }

        if (requestItem.eventCode == AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE || requestItem.eventCode == AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE_FAILED) {
            return relatedPaymentFound(requestItem.pspReference);
        }
        if (requestItem.eventCode == AdyenConstants.NOTIFICATION_REQUEST_TYPE_REFUND || requestItem.eventCode == AdyenConstants.NOTIFICATION_REQUEST_TYPE_REFUND_FAILED) {
            return relatedRefundFound(requestItem.pspReference);
        }
    
        return false;
    }

    public static Boolean relatedPaymentFound(String gatewayReference) {
        List<Payment> payments = [
            SELECT Id
            FROM Payment
            WHERE GatewayRefNumber = :gatewayReference 
            AND OrderPaymentSummaryId != NULL
        ];
        return !payments.isEmpty();
    }

    public static Boolean relatedRefundFound(String gatewayReference) {
        List<Refund> refunds = [
            SELECT Id
            FROM Refund
            WHERE GatewayRefNumber = :gatewayReference 
            AND OrderPaymentSummaryId != NULL
        ];
        return !refunds.isEmpty();
    }
}
