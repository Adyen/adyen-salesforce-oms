public with sharing class AdyenAuthorisationHelper {

    /**
    * Calls Adyen service to post an AUTH request to Adyen.
    * @param authRequest from CommercePayments
    * @return authResponse
    */
    public static CommercePayments.GatewayResponse authorise(CommercePayments.AuthorizationRequest authRequest) {
        Adyen_Adapter__mdt adyenAdapterMdt = AdyenPaymentUtility.retrieveGatewayMetadata(AdyenConstants.DEFAULT_ADAPTER_NAME);

        AuthorisationRequest adyenAuthorisationRequest = createAuthorisationRequest(authRequest, adyenAdapterMdt);
        HttpResponse adyenHttpResponse = sendAuthorisationRequest(adyenAuthorisationRequest, adyenAdapterMdt);

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

    /**
   * Create an AUTH request by populating required properties
   *
   * @param authRequest authorization request from SF Commerce Payments
   * @param adyenAdapterMdt custom metadata used
   * @return AuthorisationRequest to be sent to Adyen.
   */
    public static AuthorisationRequest createAuthorisationRequest(CommercePayments.AuthorizationRequest authRequest, Adyen_Adapter__mdt adyenAdapterMdt) {
        AuthorisationRequest adyenAuthorisationRequest = new AuthorisationRequest();
        CommercePayments.AuthApiPaymentMethodRequest paymentMethod = authRequest.paymentMethod;
        String currencyCode = authRequest.currencyIsoCode.toUpperCase();

        Decimal authAmount = authRequest.amount;
        adyenAuthorisationRequest.amount = new Amount();
        adyenAuthorisationRequest.amount.currency_x = currencyCode;
        adyenAuthorisationRequest.amount.value = (authAmount * AdyenPaymentUtility.getAmountMultiplier(currencyCode)).round(System.RoundingMode.HALF_UP);

        //Use existing token to create auth request
        if (paymentMethod.id != null) {
            //paymentMethod.id would be a string that represents the Salesforce record id of CardPaymentMethod or AlternativePaymentMethod object
            String adyenToken;
            Id recordId = paymentMethod.id;
            String sObjName = recordId.getSobjectType().getDescribe().getName(); //determine object name

            if (sObjName == AdyenOMSConstants.CARD_PAYMENT_METHOD_OBJECT) {
                //for CardPaymentMethod : Use GatewayTokenEncrypted field to retrieve token
                CardPaymentMethod cpmRecord = [SELECT Id, GatewayTokenEncrypted FROM CardPaymentMethod WHERE Id = :recordId LIMIT 1];
                adyenToken = cpmRecord.GatewayTokenEncrypted;
            } else if (sObjName == AdyenOMSConstants.ALTERNATIVE_PAYMENT_METHOD_OBJECT) {
                //for AlternativePaymentMethod : Use GatewayToken field to retrieve token
                AlternativePaymentMethod apmRecord = [SELECT Id, GatewayToken FROM AlternativePaymentMethod WHERE Id = :recordId LIMIT 1];
                adyenToken = apmRecord.GatewayToken;
            }

            CardDetails cardDetails = new CardDetails();
            cardDetails.storedPaymentMethodId = adyenToken;
            adyenAuthorisationRequest.paymentMethod = cardDetails;
            adyenAuthorisationRequest.shopperInteraction = AuthorisationRequest.ShopperInteractionEnum.ContAuth;
            adyenAuthorisationRequest.recurringProcessingModel = AuthorisationRequest.RecurringProcessingModelEnum.CardOnFile;

        } else if (paymentMethod.cardPaymentMethod != null) {
            //use new card details to create auth request
            CommercePayments.CardPaymentMethodRequest cpmRequest = paymentMethod.cardPaymentMethod;
            CardDetails cardDetails = new CardDetails();
            cardDetails.number_x = cpmRequest.cardNumber;
            cardDetails.expiryMonth = String.valueOf(cpmRequest.expiryMonth);
            cardDetails.expiryYear = String.valueOf(cpmRequest.expiryYear);
            cardDetails.holderName = cpmRequest.cardHolderName;
            cardDetails.cvc = cpmRequest.cvv;
            adyenAuthorisationRequest.paymentMethod = cardDetails;
            adyenAuthorisationRequest.shopperInteraction = AuthorisationRequest.ShopperInteractionEnum.Ecommerce;
        }

        adyenAuthorisationRequest.reference = AdyenPaymentUtility.getRandomNumber(16);
        adyenAuthorisationRequest.merchantAccount = adyenAdapterMdt.Merchant_Account__c;
        adyenAuthorisationRequest.shopperReference = UserInfo.getUserId();
        adyenAuthorisationRequest.applicationInfo = AdyenPaymentUtility.getApplicationInfo(adyenAdapterMdt.System_Integrator_Name__c);
        return adyenAuthorisationRequest;
    }

    /**
    * Send authorisation request to Adyen platform
    *
    * @param authRequest to be sent to Adyen
    * @param adyenAdapterMdt custom metadata used
    * @return response from adyen platform.
    */
    public static HttpResponse sendAuthorisationRequest(AuthorisationRequest authRequest, Adyen_Adapter__mdt adyenAdapterMdt) {
        String body = AdyenPaymentUtility.makeAdyenCompatible(JSON.serialize(authRequest, true));
        String endpoint = adyenAdapterMdt.Endpoint_Api_Version__c + adyenAdapterMdt.Authorize_Endpoint__c;
        return AdyenPaymentUtility.makePostRequest(endpoint, body);
    }
}