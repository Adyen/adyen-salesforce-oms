public with sharing class AdyenCaptureHelper {

    /**
     * invoked by handleFulfillmentOrderStatusChange to capture funds with Adyen
     * @param captureRequest with required information
     * @return `CommercePayments.GatewayResponse`
     */
    public static CommercePayments.GatewayResponse capture(CommercePayments.CaptureRequest captureRequest) {
        PaymentAuthorization paymentAuth = AdyenPaymentUtility.retrievePaymentAuthorization(captureRequest.paymentAuthorizationId);

        String errorMessage;
        if (paymentAuth == null) {
            errorMessage = 'Payment Authorization Missing';
        } else if (String.isBlank(paymentAuth.GatewayRefNumber)) {
            errorMessage = 'PspReference Missing';
        } else if (captureRequest.amount == null) {
            errorMessage = 'Payment Amount Missing';
        }
        if (String.isNotBlank(errorMessage)) {
            throw new AdyenAsyncAdapter.GatewayException(errorMessage);
        }

        String pspReference = paymentAuth.GatewayRefNumber;
        String merchantAccount = paymentAuth.OrderPaymentSummary.OrderSummary.SalesChannel.AdyenMerchantID__c;
        Adyen_Adapter__mdt adyenAdapterMdt = AdyenPaymentUtility.chooseAdapterWithFallBack(merchantAccount);

        CheckoutModificationRequest modRequest = createCaptureRequest(captureRequest, paymentAuth, adyenAdapterMdt);
        CheckoutCaptureResponse captureResponse = (CheckoutCaptureResponse)AdyenPaymentUtility.sendModificationRequest(modRequest, adyenAdapterMdt, pspReference);
        return processCaptureResponse(captureResponse, captureRequest.amount);
    }

    private static CheckoutCaptureRequest createCaptureRequest(CommercePayments.CaptureRequest captureRequest, PaymentAuthorization paymentAuth, Adyen_Adapter__mdt adyenAdapter) {
        CheckoutCaptureRequest modRequest = (CheckoutCaptureRequest)AdyenPaymentUtility.createModificationRequest(captureRequest, paymentAuth.CurrencyIsoCode, adyenAdapter);
        // Line items required for partial captures for Open Invoice methods
        if (AdyenPaymentUtility.checkIfOpenInvoiceFromAuthorization(paymentAuth)) {
            String invoiceId = captureRequest.additionalData?.get('invoiceId');
            if (String.isNotBlank(invoiceId)) {
                modRequest.setLineItems(AdyenPaymentUtility.addInvoiceData(invoiceId));
            }
        }
        return modRequest;
    }

    private static CommercePayments.GatewayResponse processCaptureResponse(CheckoutCaptureResponse captureResponse, Decimal amount) {
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