public with sharing class AdyenCaptureHelper {

    /**
     * invoked by handleFulfillmentOrderStatusChange to capture funds with Adyen
     * @param captureRequest
     * @return `CommercePayments.GatewayResponse`
     */
    public static CommercePayments.GatewayResponse capture(CommercePayments.CaptureRequest captureRequest) {

        // Retrieve the PaymentAuthorization
        PaymentAuthorization pa = AdyenPaymentUtility.retrievePaymentAuthorization(captureRequest.paymentAuthorizationId);

        String errorMessage = null;
        if(pa == null) {
            errorMessage = 'Payment Authorization Missing';
        }
        if(captureRequest.amount == null) {
            errorMessage = 'Payment Amount Missing';
        }
        String pspReference = AdyenPaymentUtility.getCaptureGatewayRefNumber(pa);
        if(String.isBlank(pspReference)) {
            errorMessage = 'PspReference Missing';
        }
        if(errorMessage != null) {
            throw new AdyenAsyncAdapter.GatewayException(errorMessage);
        }

        // By Default, retrieve the metadata key from the order's sales channel
        String adapterName = pa?.OrderPaymentSummary.OrderSummary.SalesChannel.ADYENMERCHANTID__C;

        // Override config for this specific PaymentAuthorization
        if (String.isNotBlank(pa?.adyenOverrideMerchantConfig__c)) {
            adapterName = pa.adyenOverrideMerchantConfig__c;
        }
        if (String.isBlank(adapterName)) {
            adapterName = AdyenConstants.DEFAULT_ADAPTER_NAME;
        }

        Adyen_Adapter__mdt adyenAdapterMdt = AdyenPaymentUtility.retrieveGatewayMetadata(adapterName);
        CheckoutModificationRequest modRequest = createCaptureRequest(adyenAdapterMdt, captureRequest, pspReference, pa);
        String captureEndPointURL = adyenAdapterMdt.Capture_Endpoint__c;
        captureEndPointURL = captureEndPointURL.replace('{paymentPspReference}', pspReference);
        HttpResponse adyenHttpResponse = AdyenPaymentUtility.sendModificationRequest(modRequest, adyenAdapterMdt, captureEndPointURL);
        return processCaptureResponse(adyenHttpResponse, captureRequest.amount);
    }

    /**
    * Create a modification request by populating required properties (payment/refund)
    *
    * @return CheckoutModificationRequest to send to Adyen.
    */
    public static CheckoutModificationRequest createCaptureRequest(Adyen_Adapter__mdt adyenAdapterMdt, CommercePayments.CaptureRequest captureRequest, String pspReference, PaymentAuthorization pa) {
       CheckoutCaptureRequest modRequest = new CheckoutCaptureRequest();
       // For payment methods requiring Open Invoice data (e.g., Klarna), append it
        if (AdyenPaymentUtility.checkIfKlarnaOrderFromAuthorization(pa)) {
            // Get invoice id
            String invoiceId = 'INVALID';
            if (captureRequest.additionalData.containsKey('invoiceId')) {
                invoiceId = captureRequest.additionalData.get('invoiceId');
            }
            System.debug('--------> paymentRequest InvoiceId: ' + invoiceId);
            modRequest.setAdditionalData(AdyenPaymentUtility.addInvoiceData(invoiceId, pa));
        }
       String defaultCurrencyCode = adyenAdapterMdt.Single_Currency_Code__c;
       String currencyCode = pa != null && defaultCurrencyCode == null ? (String)pa.get('CurrencyIsoCode') : defaultCurrencyCode;
       modRequest.setReference(pspReference);
       modRequest.setMerchantAccount(adyenAdapterMdt.Merchant_Account__c);
       Amount requestAmount = new Amount();
       requestAmount.value = (captureRequest.amount * AdyenPaymentUtility.getAmountMultiplier(currencyCode)).longValue();
       requestAmount.currency_x = currencyCode;
       modRequest.setAmount(requestAmount);
       return modRequest;
    }

     /**
     * @param adyenResponse: Response from Adyen's api after requesting a capture/refund
     * @return CommercePayments.GatewayResponse with populated properties.
     */
    public static CommercePayments.GatewayResponse processCaptureResponse(HttpResponse adyenHttpResponse, Double amount) {
        CheckoutCaptureResponse adyenResponse = (CheckoutCaptureResponse)JSON.deserializeStrict(AdyenPaymentUtility.makeSalesforceCompatible(adyenHttpResponse.getBody()), CheckoutCaptureResponse.class);
        CommercePayments.CaptureResponse salesforceResponse = new CommercePayments.CaptureResponse();
        salesforceResponse.setAsync(true);
        salesforceResponse.setAmount(amount);
        salesforceResponse.setGatewayDate(System.now());
        salesforceResponse.setGatewayReferenceDetails(adyenResponse.getReference());
        salesforceResponse.setGatewayResultCode(adyenResponse.getStatus());

        if (adyenResponse != null && adyenHttpResponse.getStatusCode() != AdyenConstants.HTTP_ERROR_CODE) { // HTTP connection with Adyen was successful
           salesforceResponse.setGatewayReferenceNumber(adyenResponse.getPSPReference());
           salesforceResponse.setSalesforceResultCodeInfo(AdyenConstants.SUCCESS_SALESFORCE_RESULT_CODE_INFO);
           if (adyenResponse.getStatus() == AdyenConstants.NOTIFICATION_RECEIVED_CHECKOUT) {
            salesforceResponse.setGatewayMessage('[capture-received]');
           }
        } else {
           salesforceResponse.setGatewayReferenceNumber(null);
           salesforceResponse.setSalesforceResultCodeInfo(AdyenConstants.SYSTEM_ERROR_SALESFORCE_RESULT_CODE_INFO);
        }
        return salesforceResponse;
    }
}