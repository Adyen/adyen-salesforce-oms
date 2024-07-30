/**
 *  This adapter is called by the Payment Gateway.
 *  The http calls are delegated to the AdyenPaymentHelper Class.
 *
 *  This will process a CAPTURE and a REFUND Request as well as the corresponding Async callbacks.
 *
 *  @see AdyenPaymentHelper
 */
global with sharing class AdyenAsyncAdapter implements   CommercePayments.PaymentGatewayAdapter,
        CommercePayments.PaymentGatewayAsyncAdapter {


    global AdyenAsyncAdapter() {}

    /**
     * The entry point for processing payment requests. Returns the response from the payment gateway.
     * Accepts the gateway context request and handover the operation to AdyenPaymentHelper to call the appropriate capture or refund operation.
     *
     * @param   paymentGatewayContext from SF
     * @return  CommercePayments.GatewayResponse
     *
     * @implNotes
     * [CAPTURE] is called after setting Fulfillment.Status to 'Fulfilled' which in turns fires processes
     * and flows to create invoices which ultimately fires this.
     *
     * [REFUND] is called by using the action on the order summary page (left hand side).
     *
     */
    global CommercePayments.GatewayResponse processRequest(CommercePayments.PaymentGatewayContext paymentGatewayContext) {
        return AdyenPaymentHelper.handleFulfillmentOrderStatusChange(paymentGatewayContext);
    }

    /**
     *  Listens to the incoming async notification callback from Adyen and handover to AdyenPaymentHelper for processing
     *
     * @param gatewayNotificationContext from SF
     * @return CommercePayments.GatewayNotificationResponse
     */
    public CommercePayments.GatewayNotificationResponse processNotification(CommercePayments.PaymentGatewayNotificationContext gatewayNotificationContext) {
        return AdyenPaymentHelper.handleAsyncNotificationCallback(gatewayNotificationContext);
    }

    public class GatewayException extends Exception {}

}