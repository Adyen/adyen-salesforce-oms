public with sharing class AdyenRefundHelper {

    /**
     * Calls the Service to post a REFUND to Adyen. Evaluates the response wrapped in custom class Adyen and sets appropriate
     * properties on CommercePayments.ReferenceRefundResponse.
     *
     *
     * @param refundRequest   The CommercePayments.ReferencedRefundRequest Object.
     * @return refundResponse  The CommercePayments.ReferencedRefundResponse Object.
     *
     * @see AdyenClient
    */
    public static CommercePayments.GatewayResponse refund(CommercePayments.ReferencedRefundRequest refundRequest) {
        Payment payment = AdyenPaymentUtility.retrievePayment(refundRequest.paymentId);

        String errorMessage = null;
        if (payment == null) {
            errorMessage = 'Payment Info Missing';
        } else if (String.isBlank(payment.GatewayRefNumber)) {
            errorMessage = 'PspReference Missing';
        } else if (refundRequest.amount == null) {
            errorMessage = 'Payment Amount Missing';
        }
        if (errorMessage != null) {
            throw new AdyenAsyncAdapter.GatewayException(errorMessage);
        }

        String pspReference = payment.PaymentAuthorization?.GatewayRefNumber != null ? payment.PaymentAuthorization.GatewayRefNumber : payment.GatewayRefNumber;
        String merchantAccount = payment.OrderPaymentSummary.OrderSummary.SalesChannel.AdyenMerchantID__c;
        Adyen_Adapter__mdt adyenAdapterMdt = AdyenPaymentUtility.chooseAdapterWithFallBack(merchantAccount);

        CheckoutRefundRequest modRequest = createRefundRequest(refundRequest, payment, adyenAdapterMdt);
        CheckoutRefundResponse refundResponse = (CheckoutRefundResponse)AdyenPaymentUtility.sendModificationRequest(modRequest, adyenAdapterMdt, pspReference);
        return processRefundResponse(refundResponse, refundRequest.amount);
    }

    private static CheckoutRefundRequest createRefundRequest(CommercePayments.ReferencedRefundRequest refundRequest, Payment payment, Adyen_Adapter__mdt adyenAdapter) {
        CheckoutRefundRequest modRequest = (CheckoutRefundRequest)AdyenPaymentUtility.createModificationRequest(refundRequest, payment.CurrencyIsoCode, adyenAdapter);
        //Only for Paypal Refunds - Capture reference must be a substring of refund reference
        if (String.isNotBlank(payment.PaymentAuthorization.Adyen_Payment_Method_Variant__c)) {
            if (payment.PaymentAuthorization.Adyen_Payment_Method_Variant__c.equalsIgnoreCase('Paypal') && String.isNotBlank(payment.GatewayRefDetails)) {
                String refundReference = modRequest.getReference() + payment.GatewayRefDetails;
                modRequest.setReference(refundReference);
            }
        }
        // Line items required for partial refunds for Open Invoice methods
        if (AdyenPaymentUtility.checkIfOpenInvoiceFromAuthorization(payment.PaymentAuthorization)) {
            modRequest.setLineItems(AdyenPaymentUtility.addCreditMemoData(payment.OrderPaymentSummary.OrderSummaryId));
        }

        return modRequest;
    }

    private static CommercePayments.GatewayResponse processRefundResponse(CheckoutRefundResponse refundResponse, Decimal amount) {
        CommercePayments.ReferencedRefundResponse salesforceResponse = new CommercePayments.ReferencedRefundResponse();
        salesforceResponse.setAsync(true);
        salesforceResponse.setAmount(Double.valueOf(amount));
        salesforceResponse.setGatewayDate(System.now());
        salesforceResponse.setGatewayReferenceDetails(refundResponse.getReference());
        salesforceResponse.setGatewayResultCode(refundResponse.getStatus());
        salesforceResponse.setGatewayReferenceNumber(refundResponse.getPSPReference());
        salesforceResponse.setSalesforceResultCodeInfo(AdyenConstants.SUCCESS_SALESFORCE_RESULT_CODE_INFO);
        salesforceResponse.setGatewayMessage('[refund-received]');
        return salesforceResponse;
    }
}
