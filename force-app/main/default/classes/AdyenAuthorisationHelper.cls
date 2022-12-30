public with sharing class AdyenAuthorisationHelper {

    /**
    * Calls Adyen service to post an AUTH request to Adyen.
    * @param authRequest
    * @return authResponse
    */
    public static CommercePayments.GatewayResponse authoriseFunds(CommercePayments.AuthorizationRequest authRequest) {

        Adyen_Adapter__mdt adyenAdapterMdt = AdyenPaymentUtility.retrieveGatewayMetadata(AdyenConstants.DEFAULT_ADAPTER_NAME);

        AuthorisationRequest adyenAuthorisationRequest = AdyenPaymentUtility.createAuthorisationRequest(authRequest, adyenAdapterMdt);
        HttpResponse adyenHttpResponse = AdyenPaymentUtility.sendAuthorisationRequest(adyenAuthorisationRequest, adyenAdapterMdt);

        return (CommercePayments.GatewayResponse)adyenHttpResponse;
    }

}