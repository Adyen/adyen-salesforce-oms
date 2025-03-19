public with sharing class AdyenPBLHelper {
    public static final List<String> ALLOWED_PAYMENT_METHODS = new List<String>{'ideal', 'scheme', 'paypal', 'applepay'};

    public static PaymentLinkRequest buildPaymentLinkRequest(Adyen_Adapter__mdt adyenAdapter, Amount amount, String reference, Address adyenBillingAddress) {
        PaymentLinkRequest paymentLinkRequest = new PaymentLinkRequest();
        paymentLinkRequest.amount = amount;
        paymentLinkRequest.reference = reference;
        paymentLinkRequest.merchantAccount = adyenAdapter.Merchant_Account__c;
        paymentLinkRequest.applicationInfo = AdyenPaymentUtility.getApplicationInfo(adyenAdapter.System_Integrator_Name__c);
        paymentLinkRequest.returnUrl = adyenAdapter.Payment_Link_Return_Url__c;
        paymentLinkRequest.themeId = adyenAdapter.Payment_Link_Theme_Id__c;
        paymentLinkRequest.allowedPaymentMethods = ALLOWED_PAYMENT_METHODS;
        paymentLinkRequest.billingAddress = adyenBillingAddress;
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
            String body = JSON.serialize(paymentLinkRequest, true);
            String salesforceCompatibleBody = sendPostLinkRequest(adyenAdapter, body);
            PaymentLinkResponse paymentLinkResponse = (PaymentLinkResponse)JSON.deserialize(salesforceCompatibleBody, PaymentLinkResponse.class);
            return paymentLinkResponse;
        } catch (Exception e) {
            throw new AdyenGatewayAdapter.GatewayException('Error generating payment link: ' + e.getMessage());
        }
    }

    public static PaymentLinkResponse getPaymentLinkById(Adyen_Adapter__mdt adyenAdapter, String linkId) {
        if (String.isBlank(linkId)) {
            throw new IllegalArgumentException('The Adyen Payment Link ID is null or empty');
        }
        String salesforceCompatibleBody = sendGetLinkRequest(adyenAdapter, linkId);
        PaymentLinkResponse paymentLinkResponse = (PaymentLinkResponse)JSON.deserialize(salesforceCompatibleBody, PaymentLinkResponse.class);
        return paymentLinkResponse;
    }
    
    @TestVisible
    private static String getLinkExpiryDate(Integer days) {
        Datetime currentDateTime = Datetime.now();
        Datetime expiryDateTime = currentDateTime.addDays(days);
        return expiryDateTime.format('yyyy-MM-dd\'T\'HH:mm:ssXXX');
    }

    public static Datetime parseDateTime(String dateTimeStr) {
        String[] parts = dateTimeStr.split('\\+');
        String dateTimePart = parts[0]; // example: '2024-10-25T09:38:49'
        String timeZoneOffset = parts[1]; // example: '02:00'

        dateTimePart = dateTimePart.replace('T', ' ');
        Datetime dt = Datetime.valueOf(dateTimePart);

        return dt;
    }

    public static String sendLinkPatchRequest(Adyen_Adapter__mdt adyenAdapter, String linkId, String body) {
        String endpoint = buildEndpoint(adyenAdapter, 'Payment_Link_Endpoint__c') + '/' + linkId;
        return sendHttpRequest('PATCH', endpoint, body);
    }

    public static String sendPostLinkRequest(Adyen_Adapter__mdt adyenAdapter, String body) {
        String endpoint = buildEndpoint(adyenAdapter, 'Payment_Link_Endpoint__c');
        return sendHttpRequest('POST', endpoint, body);
    }

    public static String sendGetLinkRequest(Adyen_Adapter__mdt adyenAdapter, String linkId) {
        String endpoint = buildEndpoint(adyenAdapter, 'Payment_Link_Endpoint__c') + '/' + linkId;
        return sendHttpRequest('GET', endpoint, null);
    }

    private static String buildEndpoint(Adyen_Adapter__mdt adyenAdapter, String endpointFieldName) {
        String namedCredential = adyenAdapter.Named_Credential__c;
        String namespace = String.isNotBlank(adyenAdapter.Package_Namespace__c) ? adyenAdapter.Package_Namespace__c + '__' : '';
        String endpointUrl = 'callout:' + namespace + namedCredential;
        String apiVersion = adyenAdapter.Endpoint_Api_Version__c;
        String endpointPath = (String) adyenAdapter.get(endpointFieldName);

        return endpointUrl + apiVersion + endpointPath;
    }

    private static String sendHttpRequest(String requestMethod, String endpoint, String body) {
        String compatibleBody = null;
        

        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod(requestMethod);
        request.setHeader('Content-Type', 'application/json');
        if(body != null) {
            compatibleBody = AdyenPaymentUtility.makeAdyenCompatible(body);
            request.setBody(compatibleBody);
        }

        HttpResponse response = new Http().send(request);

        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            String responseBody = response.getBody();
            String errorMessage = 'An unexpected error occurred.';
            if (responseBody != null) {
                Map<String, Object> errorResponseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                if (errorResponseMap.containsKey('message')) {
                    errorMessage = (String) errorResponseMap.get('message');
                }
            }
            throw new AdyenGatewayAdapter.GatewayException(errorMessage);
        } else {
            String salesforceCompatibleBody = AdyenPaymentUtility.makeSalesforceCompatible(response.getBody());
            return salesforceCompatibleBody;
        }
    }

    public static Address makeAdyenAddressCompatible(System.Address sfAddress) {
        Address adyenAddress = new Address();
        adyenAddress.city = sfAddress.city;
        adyenAddress.country = sfAddress.country;
        adyenAddress.postalCode = sfAddress.postalCode;
        adyenAddress.stateOrProvince = sfAddress.state;
        parseHouseNumberFromStreetAddress(sfAddress.street, adyenAddress);
        return adyenAddress;
    }

    public static void parseHouseNumberFromStreetAddress(String streetAddressWithHouseNumber, Address adyenAddress) {
        if (String.isBlank(streetAddressWithHouseNumber)) {
            return;
        }

        // Regular expression to match numbers (house number) at the beginning or end of the address
        Pattern numberPattern = Pattern.compile('^(\\d+)?\\s*(.*?)(\\d+)?$');
        Matcher matcher = numberPattern.matcher(streetAddressWithHouseNumber.trim());

        if (matcher.find()) {
            // Check for house number at the start
            if (matcher.group(1) != null) {
                adyenAddress.houseNumberOrName = matcher.group(1).trim();
                adyenAddress.street = matcher.group(2).trim();
            }
            // Check for house number at the end
            else if (matcher.group(3) != null) {
                adyenAddress.houseNumberOrName = matcher.group(3).trim();
                adyenAddress.street = matcher.group(2).trim();
            } else {
                // If no number is found, treat the whole address as the street name
                adyenAddress.street = streetAddressWithHouseNumber;
            }
        }
    }
}
