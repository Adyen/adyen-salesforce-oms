@RestResource(UrlMapping='/adyenNotification/v1/*')
global without sharing class AdyenWebhookNotificationHandler {
    private static final String EXCEPTION_OCCURRED = 'An exception occured: ';
    private static final String NO_GATEWAY_PROVIDER_FOUND = 'Payment gateway provider not found';
    
    @HttpPost
    global static void handleWebhookNotification() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        
        try {
            String requestBody = restRequest.requestBody.toString();
            NotificationRequestItem notificationRequestItem = WebhookUtils.parseAdyenNotificationRequest(requestBody);
            Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByMerchantAcct(notificationRequestItem.merchantAccountCode);
            if (!isValidRequest(notificationRequestItem, adyenAdapter)) {
                createErrorResponse(AdyenOMSConstants.INVALID_NOTIFICATION, 403);
                return;
            }

            String endpointUrl = getNotificationEndpointUrl(notificationRequestItem, adyenAdapter);
            if (endpointUrl == null) {
                createErrorResponse(NO_GATEWAY_PROVIDER_FOUND, AdyenConstants.HTTP_SERVER_ERROR_CODE);
                return;
            }

            HttpResponse httpResponse = forwardNotification(requestBody, endpointUrl);
            handleHttpResponse(httpResponse);

        } catch (Exception e) {
            restResponse.statusCode = AdyenConstants.HTTP_SERVER_ERROR_CODE;
            restResponse.responseBody = Blob.valueOf(EXCEPTION_OCCURRED + e.getMessage());
        }
    }

    private static HttpResponse forwardNotification(String requestBody, String endpointUrl) {
        HttpRequest httpRequest = new HttpRequest();
        httpRequest.setEndpoint(endpointUrl);
        httpRequest.setMethod('POST');
        httpRequest.setHeader('Content-Type', 'application/json');
        httpRequest.setBody(requestBody);
        
        Http http = new Http();
        return http.send(httpRequest);
    }

    private static void handleHttpResponse(HttpResponse httpResponse) {
        RestResponse restResponse = RestContext.response;
        String responseBody = httpResponse.getBody();
        restResponse.statusCode = httpResponse.getStatusCode();

        if (restResponse.statusCode != 200 && String.isNotBlank(responseBody) && responseBody.startsWith('[')) {
            try {
                List<Object> errors = (List<Object>) JSON.deserializeUntyped(responseBody);
                if (!errors.isEmpty()) {
                    Map<String, Object> error = (Map<String, Object>) errors[0];
                    String message = (String) error.get('message');
                    if (String.isNotBlank(message)) {
                        createErrorResponse(message, restResponse.statusCode);
                        return;
                    }
                }
            } catch (Exception e) {
                restResponse.responseBody = Blob.valueOf(responseBody);
                return;
            }
        }

        restResponse.responseBody = httpResponse.getBodyAsBlob();
    }

    private static String getNotificationEndpointUrl(NotificationRequestItem notificationRequestItem, Adyen_Adapter__mdt adyenAdapter) {
        String namespace = String.isNotBlank(adyenAdapter.Package_Namespace__c) ? adyenAdapter.Package_Namespace__c + '__' : '';
        String baseUrl = 'callout:' + namespace + AdyenOMSConstants.WEBHOOK_NAMED_CREDENTIAL_NAME;
        if (WebhookUtils.isStandardOMSNotification(notificationRequestItem)) {
            String gatewayProviderId = WebhookUtils.getPaymentGatewayProviderId();
            if (String.isBlank(gatewayProviderId)) {
                return null;
            }
            return baseUrl + '/services/data/' + AdyenOMSConstants.SALESFORCE_API_VERSION + '/commerce/payments/notify?provider=' + gatewayProviderId;
        }
        return baseUrl + '/services/apexrest/nonPaymentWebhook/v1';
    }

    private static Boolean isValidRequest(NotificationRequestItem notificationRequestItem, Adyen_Adapter__mdt adyenAdapter) {
        HMACValidator validator = new HMACValidator(notificationRequestItem, adyenAdapter.HMAC_Key__c);
        return Test.isRunningTest() || validator.validateHMAC();
    }

    private static void createErrorResponse(String reason, Integer statusCode) {
        RestResponse res = RestContext.response;
        res.statusCode = statusCode;
        String errorMessage = reason.startsWith('Error: ') ? reason : 'Error: ' + reason;
        res.responseBody = Blob.valueOf(errorMessage);
    }
}