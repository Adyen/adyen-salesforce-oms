@RestResource(UrlMapping='/nonPaymentWebhook/v1/*')
global without sharing class NonPaymentWebhookHandler {

    private static final String ACCEPTED_RESPONSE = '[accepted]';

    @HttpPost
    global static String doPost() {
        PaymentAuthorization paymentAuthorization;
        NotificationRequestItem notificationRequestItem;
        RestRequest req = RestContext.request;
        String requestBody = req.requestBody.toString();
        String acceptedResponse = '[accepted]';
        try {
            notificationRequestItem = WebhookUtils.parseAdyenNotificationRequest(requestBody);
            Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByMerchantAcct(notificationRequestItem.merchantAccountCode);
            HMACValidator validator = new HMACValidator(notificationRequestItem, adyenAdapter.HMAC_Key__c);
            if (!Test.isRunningTest() && !validator.validateHMAC()) {
                return ACCEPTED_RESPONSE + ', but not a valid notification request';
            }
            if (!AdyenPaymentUtility.isValidNotification(notificationRequestItem)) {
                return ACCEPTED_RESPONSE + ', but no valid psp reference found or webhook type was ignored';
            }
            if (notificationRequestItem.eventCode.toUpperCase() != AdyenConstants.NOTIFICATION_REQUEST_TYPE_CANCEL) {
                return ACCEPTED_RESPONSE + ', but webhook type was ignored';
            }
            if (!AdyenPaymentUtility.relatedPaymentFound(notificationRequestItem.originalReference)) {
                return ACCEPTED_RESPONSE + ', but no related payment record found';
            }

            paymentAuthorization = findPaymentAuthorization(notificationRequestItem.originalReference);
            createGatewayLog(paymentAuthorization, notificationRequestItem, requestBody);
            return acceptedResponse;
        } catch (Exception ex) {
            if (ex instanceof HMACValidator.HmacValidationException) {
                return ACCEPTED_RESPONSE + ', but not valid notification request';
            } else {
                return ACCEPTED_RESPONSE + ', but an exception happened: ' + ex.getMessage();
            }
        }
    }

    private static void createGatewayLog(PaymentAuthorization paymentAuthorization, NotificationRequestItem notificationRequestItem, String requestBody) {
        PaymentGatewayLog paymentGatewayLog = new PaymentGatewayLog();
        String interactionStatus = notificationRequestItem.success == 'true' ? 'Success' : 'Failed';
        String gatewayMessage = notificationRequestItem.success == 'true' ? '[cancellation-completed]' : '[cancellation-failed]';
        paymentGatewayLog.IsNotification = 'Yes';
        paymentGatewayLog.ReferencedEntityId = paymentAuthorization?.Id;
        paymentGatewayLog.OrderPaymentSummaryId = paymentAuthorization?.OrderPaymentSummaryId;
        paymentGatewayLog.PaymentGatewayId = paymentAuthorization?.PaymentGatewayId;
        paymentGatewayLog.GatewayRefNumber = notificationRequestItem?.pspReference;
        paymentGatewayLog.CurrencyIsoCode = notificationRequestItem?.amount.currency_x;
        paymentGatewayLog.GatewayResultCode = notificationRequestItem?.success;
        paymentGatewayLog.GatewayResultCodeDescription = notificationRequestItem?.reason;
        paymentGatewayLog.Request = requestBody;
        paymentGatewayLog.GatewayMessage = gatewayMessage;
        paymentGatewayLog.Response = ACCEPTED_RESPONSE;
        paymentGatewayLog.InteractionType = 'AuthorizationReversal';
        paymentGatewayLog.InteractionStatus = interactionStatus;
        insert paymentGatewayLog;
    }

    private static PaymentAuthorization findPaymentAuthorization(String pspReference) {
        List<PaymentAuthorization> paymentAuthorizations = [
            SELECT Status, OrderPaymentSummaryId, PaymentGatewayId
            FROM PaymentAuthorization
            WHERE GatewayRefNumber = :pspReference AND OrderPaymentSummaryId != NULL
            LIMIT 1
        ];
        return paymentAuthorizations.isEmpty() ? null : paymentAuthorizations[0];
    }
}