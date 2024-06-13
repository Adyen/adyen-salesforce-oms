public with sharing class AdyenAuthorisationHelper {

    /**
    * Calls Adyen service to post an AUTH request to Adyen.
    * @param authRequest
    * @return authResponse
    */
    public static CommercePayments.GatewayResponse authorise(CommercePayments.AuthorizationRequest authRequest) {

        Adyen_Adapter__mdt adyenAdapterMdt = AdyenPaymentUtility.retrieveGatewayMetadata(AdyenConstants.DEFAULT_ADAPTER_NAME);

        AuthorisationRequest adyenAuthorisationRequest = AdyenPaymentUtility.createAuthorisationRequest(authRequest, adyenAdapterMdt);
        HttpResponse adyenHttpResponse = AdyenPaymentUtility.sendAuthorisationRequest(adyenAuthorisationRequest, adyenAdapterMdt);

        return processAuthResponse(adyenHttpResponse, AdyenPaymentUtility.normalizeAmount(authRequest.amount), adyenAdapterMdt.Merchant_Account__c);
    }

    private static CommercePayments.GatewayResponse processAuthResponse(HttpResponse response, Decimal amount, String merchantAccountName) {
        Map<String,Object> body = (Map<String,Object>)JSON.deserializeUntyped(response.getBody());
        String resultCode = (String)body.get('resultCode');
        if(resultCode != null) {
            CommercePayments.AuthorizationResponse salesforceAuthResponse = new CommercePayments.AuthorizationResponse();
            if(resultCode == 'Authorised') {
                Map<String,Object> additionalData = (Map<String,Object>)body.get('additionalData');
                salesforceAuthResponse.setGatewayAuthCode((String)additionalData.get('authCode'));
                salesforceAuthResponse.setSalesforceResultCodeInfo(AdyenConstants.SUCCESS_SALESFORCE_RESULT_CODE_INFO);
            } else {
                salesforceAuthResponse.setGatewayResultCodeDescription((String)body.get('refusalReason'));
                salesforceAuthResponse.setSalesforceResultCodeInfo(AdyenConstants.DECLINE_SALESFORCE_RESULT_CODE_INFO);
            }
            salesforceAuthResponse.setGatewayReferenceNumber((String)body.get('pspReference'));
            salesforceAuthResponse.setAmount(Double.valueOf(amount));
            salesforceAuthResponse.setGatewayDate(System.now());
            salesforceAuthResponse.setGatewayReferenceDetails(merchantAccountName);
            return salesforceAuthResponse;
        } else {
            return new CommercePayments.GatewayErrorResponse(
                String.valueOf(response.getStatusCode()),
                String.valueOf(body.get('message'))
            );
        }
    }

}