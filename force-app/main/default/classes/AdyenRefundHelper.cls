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
        // Retrieve the Payment
        Payment payment = AdyenPaymentUtility.retrievePayment(refundRequest.paymentId);

        String errorMessage = null;
        if(payment == null) {
            errorMessage = 'Payment Info Missing';
        }
        if(refundRequest.amount == null) {
            errorMessage = 'Payment Amount Missing';
        }
        if(errorMessage != null) {
            throw new AdyenAsyncAdapter.GatewayException(errorMessage);
        }
        // By Default, retrieve the metadata key from the order's sales channel
        String adapterName = payment?.OrderPaymentSummary.OrderSummary.SalesChannel.AdyenMerchantID__c;
        // Override config for this specific Payment (i.e., a pre-capture) or inherit override from the original PaymentAuthorization
        if (String.isNotBlank(payment?.adyenOverrideMerchantConfig__c)) {
            adapterName = payment.adyenOverrideMerchantConfig__c;
        }
        if (String.isNotBlank(payment?.PaymentAuthorization?.adyenOverrideMerchantConfig__c)) {
            adapterName = payment.PaymentAuthorization.adyenOverrideMerchantConfig__c;
        }
        if (String.isBlank(adapterName)) {
            adapterName = AdyenConstants.DEFAULT_ADAPTER_NAME;
        }
        Adyen_Adapter__mdt adyenAdapterMdt = AdyenPaymentUtility.retrieveGatewayMetadata(adapterName);
        String pspReference = AdyenPaymentUtility.getRefundGatewayRefNumber(payment);
        CheckoutModificationRequest modRequest = AdyenPaymentUtility.createModificationRequest(refundRequest, payment.CurrencyIsoCode, adyenAdapterMdt);
        //Only for Paypal Refunds - Capture reference must be a substring of refund reference
        if (String.isNotBlank(payment.PaymentAuthorization.Adyen_Payment_Method_Variant__c)) {
            if (payment.PaymentAuthorization.Adyen_Payment_Method_Variant__c.equalsIgnoreCase('Paypal') && String.isNotBlank(payment.GatewayRefDetails)) {
                String refundReference = modRequest.getReference() + payment.GatewayRefDetails;     //payment.GatewayRefDetails has the capture reference
                modRequest.setReference(refundReference);
            }
        }
        // Line items required for partial refunds for Open Invoice methods
        if (AdyenPaymentUtility.checkIfOpenInvoiceFromAuthorization(payment.PaymentAuthorization)) {
            modRequest.setLineItems(AdyenPaymentUtility.addCreditMemoData(payment.OrderPaymentSummary.OrderSummaryId));
        }

        HttpResponse adyenHttpResponse = AdyenPaymentUtility.sendModificationRequest(modRequest, adyenAdapterMdt, pspReference);
        return processRefundResponse(adyenHttpResponse, refundRequest.amount);
    }

    /**
     * @param adyenHttpResponse: Response from Adyen's api after requesting a refund
     * @param amount to be refunded
     * @return CommercePayments.GatewayResponse with populated properties.
    */
    public static CommercePayments.GatewayResponse processRefundResponse(HttpResponse adyenHttpResponse, Decimal amount) {
        CommercePayments.ReferencedRefundResponse salesforceResponse = new CommercePayments.ReferencedRefundResponse();
        CheckoutRefundResponse adyenResponse = (CheckoutRefundResponse)JSON.deserialize(AdyenPaymentUtility.makeSalesforceCompatible(adyenHttpResponse.getBody()), CheckoutRefundResponse.class);
        salesforceResponse.setAsync(true);
        salesforceResponse.setAmount(Double.valueOf(amount));
        salesforceResponse.setGatewayDate(System.now());
        salesforceResponse.setGatewayReferenceDetails(adyenResponse.getReference());
        salesforceResponse.setGatewayResultCode(adyenResponse.getStatus());

        if (adyenResponse != null && adyenHttpResponse.getStatusCode() != AdyenConstants.HTTP_ERROR_CODE) { // HTTP connection with Adyen was successful
           salesforceResponse.setGatewayReferenceNumber(adyenResponse.getPSPReference());
           salesforceResponse.setSalesforceResultCodeInfo(AdyenConstants.SUCCESS_SALESFORCE_RESULT_CODE_INFO);
           if (adyenResponse.getStatus() == AdyenConstants.NOTIFICATION_RECEIVED_CHECKOUT) {
            salesforceResponse.setGatewayMessage('[refund-received]');
           }
        } else {
           salesforceResponse.setGatewayReferenceNumber(null);
           salesforceResponse.setSalesforceResultCodeInfo(AdyenConstants.SYSTEM_ERROR_SALESFORCE_RESULT_CODE_INFO);
        }
        return salesforceResponse;
    }
}