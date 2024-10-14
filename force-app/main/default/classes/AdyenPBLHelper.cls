public with sharing class AdyenPBLHelper {
    public static final List<String> ALLOWED_PAYMENT_METHODS = new List<String>{'ideal', 'scheme', 'paypal', 'applepay'};

    public static PaymentLinkRequest buildPaymentLinkRequest(Adyen_Adapter__mdt adyenAdapter, Amount amount, String reference) {
        PaymentLinkRequest paymentLinkRequest = new PaymentLinkRequest();
        paymentLinkRequest.amount = amount;
        paymentLinkRequest.reference = reference;
        paymentLinkRequest.merchantAccount = adyenAdapter.Merchant_Account__c;
        paymentLinkRequest.applicationInfo = AdyenPaymentUtility.getApplicationInfo(adyenAdapter.System_Integrator_Name__c);
        paymentLinkRequest.returnUrl = adyenAdapter.Payment_Link_Return_Url__c;
        paymentLinkRequest.themeId = adyenAdapter.Payment_Link_Theme_Id__c;
        paymentLinkRequest.allowedPaymentMethods = ALLOWED_PAYMENT_METHODS;
        paymentLinkRequest.expiresAt = adyenAdapter.Payment_Link_Expiry_Duration__c != null 
            ? getLinkExpiryDate(adyenAdapter.Payment_Link_Expiry_Duration__c.intValue()) 
            : null;

        return paymentLinkRequest;
    } 

    public static PaymentLinkResponse generatePaymentLink(Adyen_Adapter__mdt adyenAdapter, PaymentLinkRequest paymentLinkRequest) {
        if (adyenAdapter == null || paymentLinkRequest == null) {
            throw new IllegalArgumentException('One or more input parameters are null');
        }

        try {
            String endpoint = buildEndpoint(adyenAdapter, 'Payment_Link_Endpoint__c');
            String body = AdyenPaymentUtility.makeAdyenCompatible(JSON.serialize(paymentLinkRequest, true));

            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setBody(body);

            HttpResponse response = new Http().send(request);

            if (response.getStatusCode() != 201) {
                throw new AdyenGatewayAdapter.GatewayException('Adyen Checkout API returned: ' + response.getStatusCode() + ', body: ' + response.getBody());
            } else {
                String salesforceCompatibleBody = AdyenPaymentUtility.makeSalesforceCompatible(response.getBody());
                PaymentLinkResponse paymentLinkResponse = (PaymentLinkResponse)JSON.deserialize(salesforceCompatibleBody, PaymentLinkResponse.class);
                return paymentLinkResponse;
            }
        } catch (Exception e) {
            throw new AdyenGatewayAdapter.GatewayException('Error generating payment link: ' + e.getMessage());
        }
    }

    private static String buildEndpoint(Adyen_Adapter__mdt adyenAdapter, String endpointFieldName) {
        String namedCredential = adyenAdapter.Named_Credential__c;
        String namespace = String.isNotBlank(adyenAdapter.Package_Namespace__c) ? adyenAdapter.Package_Namespace__c + '__' : '';
        String endpointUrl = 'callout:' + namespace + namedCredential;
        String apiVersion = adyenAdapter.Endpoint_Api_Version__c;
        String endpointPath = (String) adyenAdapter.get(endpointFieldName);

        return endpointUrl + apiVersion + endpointPath;
    }
    
    @TestVisible
    private static String getLinkExpiryDate(Integer days) {
        Datetime currentDateTime = Datetime.now();
        Datetime expiryDateTime = currentDateTime.addDays(days);

        return formatDateTimeToISO8601(expiryDateTime);
    }

    private static String formatDateTimeToISO8601(Datetime dt) {
        String iso8601Date = dt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss');
        String timeZoneOffset = Datetime.now().format('Z');
        String formattedOffset = timeZoneOffset.substring(0, 3) + ':' + timeZoneOffset.substring(3);

        return iso8601Date + formattedOffset;
    }
}