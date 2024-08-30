public with sharing class WebhookUtils {
    public static NotificationRequestItem parseAdyenNotificationRequest(String notificationRequestBody) {
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
}
