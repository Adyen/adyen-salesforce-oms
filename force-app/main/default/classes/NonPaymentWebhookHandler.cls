@RestResource(UrlMapping='/nonPaymentWebhook/v1/*')
global without sharing class NonPaymentWebhookHandler {
    public static final String ACCEPTED_RESPONSE = '[accepted]';
    public static final String INVALID_NOTIFICATION = 'but not a valid notification request';
    public static final String INVALID_WEBHOOK = 'but no valid psp reference found or webhook type was ignored';
    public static final String NO_PAYMENT_FOUND = 'but no related payment record found';
    public static final String EXCEPTION_OCCURRED = 'but an exception happened: ';

    @HttpPost
    global static String doPost() {
        String requestBody = RestContext.request.requestBody.toString();
        try {
            NotificationRequestItem notificationRequestItem = WebhookUtils.parseAdyenNotificationRequest(requestBody);
            Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByMerchantAcct(notificationRequestItem.merchantAccountCode);
            if (!isValidRequest(notificationRequestItem, adyenAdapter)) {
                return responseWithReason(INVALID_NOTIFICATION);
            }
            if (!AdyenPaymentUtility.isValidNonPaymentWebhook(notificationRequestItem)) {
                return responseWithReason(INVALID_WEBHOOK);
            }
            PaymentAuthorization paymentAuthorization = findPaymentAuthorization(notificationRequestItem);
            if (paymentAuthorization == null) {
                return responseWithReason(NO_PAYMENT_FOUND);
            }
            processNotification(paymentAuthorization, notificationRequestItem);
            createGatewayLog(paymentAuthorization, notificationRequestItem, requestBody);
            return ACCEPTED_RESPONSE;
        } catch (HMACValidator.HmacValidationException ex) {
            return responseWithReason(INVALID_NOTIFICATION);
        } catch (Exception ex) {
            return responseWithReason(EXCEPTION_OCCURRED + ex.getMessage());
        }
    }

    private static Boolean isValidRequest(NotificationRequestItem notificationRequestItem, Adyen_Adapter__mdt adyenAdapter) {
        HMACValidator validator = new HMACValidator(notificationRequestItem, adyenAdapter.HMAC_Key__c);
        return Test.isRunningTest() || validator.validateHMAC();
    }

    @TestVisible
    private static String responseWithReason(String reason) {
        return ACCEPTED_RESPONSE + ', ' + reason;
    }

    private static void createGatewayLog(PaymentAuthorization paymentAuthorization, NotificationRequestItem notificationRequestItem, String requestBody) {
        String interactionStatus = notificationRequestItem.success == 'true' ? AdyenOMSConstants.PaymentGatewayLogStatus.SUCCESS.name() : AdyenOMSConstants.PaymentGatewayLogStatus.FAILED.name();
        String event = notificationRequestItem.eventCode.toLowerCase();
        String gatewayMessage = notificationRequestItem.success == 'true' ? '[' + event + '-completed]' : '[' + event + '-failed]';
        String interactionType = AdyenOMSConstants.INTERACTION_TYPE_MAP.get(notificationRequestItem.eventCode);

        PaymentGatewayLog paymentGatewayLog = new PaymentGatewayLog();
        paymentGatewayLog.IsNotification = 'Yes';
        paymentGatewayLog.ReferencedEntityId = paymentAuthorization.Id;
        paymentGatewayLog.OrderPaymentSummaryId = paymentAuthorization.OrderPaymentSummaryId;
        paymentGatewayLog.PaymentGatewayId = paymentAuthorization.PaymentGatewayId;
        paymentGatewayLog.GatewayRefNumber = notificationRequestItem.pspReference;
        paymentGatewayLog.CurrencyIsoCode = notificationRequestItem.amount.currency_x;
        paymentGatewayLog.GatewayResultCode = notificationRequestItem.success;
        paymentGatewayLog.GatewayResultCodeDescription = notificationRequestItem.reason;
        paymentGatewayLog.Request = requestBody;
        paymentGatewayLog.GatewayMessage = gatewayMessage;
        paymentGatewayLog.Response = ACCEPTED_RESPONSE;
        paymentGatewayLog.InteractionType = interactionType;
        paymentGatewayLog.InteractionStatus = interactionStatus;

        insert paymentGatewayLog;
    }

    private static void processNotification(PaymentAuthorization payAuth, NotificationRequestItem requestItem) {
        if (requestItem.eventCode == AdyenConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE) {
            if (requestItem.success == 'true' && payAuth.Status.equalsIgnoreCase(AdyenOMSConstants.PaymentAuthorizationStatus.PENDING.name())) {
                payAuth.GatewayRefNumber = requestItem.pspReference;
                payAuth.Status = AdyenOMSConstants.PaymentAuthorizationStatus.PROCESSED.name();
                update payAuth;
            }
        }
    }

    private static PaymentAuthorization findPaymentAuthorization(NotificationRequestItem requestItem) {
        if (requestItem.eventCode == AdyenConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE) {
            return findPaymentAuthByCartId(requestItem.merchantReference);
        } else {
            return findPaymentAuthByGatewayRef(requestItem.originalReference);
        }
    }

    private static PaymentAuthorization findPaymentAuthByGatewayRef(String gatewayReference) {
        List<PaymentAuthorization> paymentAuthorizations = [
            SELECT Status, OrderPaymentSummaryId, PaymentGatewayId
            FROM PaymentAuthorization
            WHERE GatewayRefNumber = :gatewayReference AND OrderPaymentSummaryId != NULL
            LIMIT 1
        ];
        return paymentAuthorizations.isEmpty() ? null : paymentAuthorizations[0];
    }

    private static PaymentAuthorization findPaymentAuthByCartId(String cartId) {
        List<WebCart> webCarts = [SELECT PaymentGroupId FROM WebCart WHERE Id = :cartId];
        if (webCarts.isEmpty()) {
            return null;
        }
        List<PaymentAuthorization> paymentAuthorizations = [
            SELECT Status, OrderPaymentSummaryId, PaymentGatewayId
            FROM PaymentAuthorization
            WHERE PaymentGroupId = :webCarts[0].PaymentGroupId AND OrderPaymentSummaryId != NULL
            LIMIT 1
        ];
        return paymentAuthorizations.isEmpty() ? null : paymentAuthorizations[0];
    }
}