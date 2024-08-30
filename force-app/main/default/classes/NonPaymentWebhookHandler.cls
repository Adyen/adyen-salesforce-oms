@RestResource(UrlMapping='/nonPaymentWebhook/v1/*')
global with sharing class NonPaymentWebhookHandler {
    @HttpPost
    global static String doPost() {
        NotificationRequestItem notificationRequestItem;
        RestRequest req = RestContext.request;
        String acceptedResponse = '[accepted]';
        try {
            notificationRequestItem = WebhookUtils.parseAdyenNotificationRequest(req.requestBody.toString());
            Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByMerchantAcct(notificationRequestItem.merchantAccountCode);
            HMACValidator validator;
            validator = new HMACValidator(notificationRequestItem, adyenAdapter.HMAC_Key__c);
            if (!Test.isRunningTest() && !validator.validateHMAC()) {
                return acceptedResponse + ', but not a valid notification request';
            }
            // TODO: CAPTURE/REFUND and its failed counterparts should not be valid here
            if (!AdyenPaymentUtility.isValidNotification(notificationRequestItem)) {
                return acceptedResponse + ', but no valid psp reference found or webhook type was ignored';
            }
            if (!AdyenPaymentUtility.relatedPaymentFound(notificationRequestItem.originalReference)) {
                return acceptedResponse + ', but no related payment record found';
            }
            // TODO: create gateway log
            return acceptedResponse;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, ex.getMessage());
            if (ex instanceof HMACValidator.HmacValidationException) {
                return '[accepted] but not valid notification request';
            } else {
                return '[accepted] but an exception happened: ' + ex.getMessage();
            }
        }
    }
}