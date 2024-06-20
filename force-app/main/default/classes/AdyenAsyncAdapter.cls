/**
 *  This adapter is called by the Payment Gateway.
 *  The http calls are delegated to the AdyenPaymentHelper Class.
 *
 *  This will process a CAPTURE and a REFUND Request as well as the corresponding Async callbacks.
 *
 *  @see AdyenPaymentHelper
 *  @see AdyenClient
 */
global with sharing class AdyenAsyncAdapter implements   CommercePayments.PaymentGatewayAdapter, CommercePayments.PaymentGatewayAsyncAdapter {

    global AdyenAsyncAdapter() {}

   /**
    * The entry point for processing payment requests. Returns the response from the payment gateway.
    * Accepts the gateway context request and handover the operation to AdyenPaymentHelper to call the appropriate capture or refund operation.
    *
    * @param paymentGatewayContext from SF Commerce Payments
    * @return CommercePayments.GatewayResponse
    *
    * @implNotes
    * [CAPTURE] is called after setting Fulfillment.Status to 'Fulfilled' which in turns fires processes
    * and flows to create invoices which ultimately fires this.
    *
    * [REFUND] is called by using the action on the order summary page (left hand side).
    *
    */
    global CommercePayments.GatewayResponse processRequest(CommercePayments.PaymentGatewayContext paymentGatewayContext) {
        try {
            return AdyenPaymentHelper.handleFulfillmentOrderStatusChange(paymentGatewayContext);
        } catch (Exception ex) {
            return new CommercePayments.GatewayErrorResponse('500', ex.getMessage());
        }
    }

   /**
    *  Listens to the incoming async notification callback from Adyen and handover to AdyenPaymentHelper for processing
    *
    * @param gatewayNotificationContext from SF Commerce Payments
    * @return CommercePayments.GatewayNotificationResponse
    */
    global CommercePayments.GatewayNotificationResponse processNotification(CommercePayments.PaymentGatewayNotificationContext gatewayNotificationContext) {
        String apexName = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));
        return AdyenPaymentHelper.handleAsyncNotificationCallback(gatewayNotificationContext, apexName);

    }

    public class GatewayException extends Exception {}
}
