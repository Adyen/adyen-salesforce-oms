public with sharing class AdyenCaptureHelper {

    /**
     * invoked by handleFulfillmentOrderStatusChange to capture funds with Adyen
     * @param captureRequest with required information
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
        String adapterName = pa.OrderPaymentSummary.OrderSummary.SalesChannel.AdyenMerchantID__c;

        // Override config for this specific PaymentAuthorization
        if (String.isNotBlank(pa.adyenOverrideMerchantConfig__c)) {
            adapterName = pa.adyenOverrideMerchantConfig__c;
        }
        if (String.isBlank(adapterName)) {
            adapterName = AdyenConstants.DEFAULT_ADAPTER_NAME;
        }

        Adyen_Adapter__mdt adyenAdapterMdt = AdyenPaymentUtility.retrieveGatewayMetadata(adapterName);
        CheckoutModificationRequest modRequest = AdyenPaymentUtility.createModificationRequest(captureRequest, pa.CurrencyIsoCode, adyenAdapterMdt);

        // Line items required for partial captures for Open Invoice methods
        if (AdyenPaymentUtility.checkIfOpenInvoiceFromAuthorization(pa)) {
            String invoiceId = captureRequest.additionalData?.get('invoiceId');
            if (String.isNotBlank(invoiceId)) {
                modRequest.setLineItems(AdyenPaymentUtility.addInvoiceData(invoiceId));
            }
        }

        CheckoutCaptureResponse captureResponse = (CheckoutCaptureResponse)AdyenPaymentUtility.sendModificationRequest(modRequest, adyenAdapterMdt, pspReference);
        return processCaptureResponse(captureResponse, captureRequest.amount);
    }

    public static CommercePayments.GatewayResponse processCaptureResponse(CheckoutCaptureResponse captureResponse, Decimal amount) {
        CommercePayments.CaptureResponse salesforceResponse = new CommercePayments.CaptureResponse();
        salesforceResponse.setAsync(true);
        salesforceResponse.setAmount(Double.valueOf(amount));
        salesforceResponse.setGatewayDate(System.now());
        salesforceResponse.setGatewayReferenceDetails(captureResponse.getReference());
        salesforceResponse.setGatewayResultCode(captureResponse.getStatus());
        salesforceResponse.setGatewayReferenceNumber(captureResponse.getPSPReference());
        salesforceResponse.setSalesforceResultCodeInfo(AdyenConstants.SUCCESS_SALESFORCE_RESULT_CODE_INFO);
        salesforceResponse.setGatewayMessage('[capture-received]');
        return salesforceResponse;
    }
}