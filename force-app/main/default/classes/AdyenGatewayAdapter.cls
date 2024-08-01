global with sharing class AdyenGatewayAdapter implements CommercePayments.PaymentGatewayAdapter, CommercePayments.PaymentGatewayAsyncAdapter {

    global AdyenGatewayAdapter() {}

    global CommercePayments.GatewayResponse processRequest(CommercePayments.PaymentGatewayContext paymentGatewayContext) {
        try {
            return AdyenPaymentHelper.handleFulfillmentOrderStatusChange(paymentGatewayContext);
        } catch (Exception ex) {
            return new CommercePayments.GatewayErrorResponse('500', ex.getMessage());
        }
    }

    global CommercePayments.GatewayNotificationResponse processNotification(CommercePayments.PaymentGatewayNotificationContext gatewayNotificationContext) {
        return AdyenPaymentHelper.handleAsyncNotificationCallback(gatewayNotificationContext);
    }

    public class GatewayException extends Exception {}
}