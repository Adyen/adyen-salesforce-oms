/**
 *  AdyenService will contain all callouts to the Adyen API. as well as build of the body json to be submitted.
 *  Additionally it will parse and serialize any response from the Adyen Payment Gateway.
 */
public with sharing class AdyenService {

    @TestVisible private final static String  TEST_ENDPOINT          = 'https://bogus.unittest.com'; // Unit test EP
    @TestVisible private final static String  CONTENT_TYPE           = 'application/json';
    
    public  final static Integer HTTP_SUCCESS_CODE = 200;
    public  final static String HTTP_SERVER_ERROR_CODE = '500';
    public  final static String GATEWAY_ERROR_RESPONSE_CODE = '400';
    public  final static String APEX_RESERVED_CURRENCY_FIELD = 'currency_x'; // allows deserialization of reserved words.
    
    /**
     * Init Basically headers and endpoint for the HttpRequest.
     *
     * @param method   The method for the request. [ capture or  request ]
     * @param httpMethod The Http Method to use.
     *
     * @return        An HttpRequest object with ep / method and basic headers for Adyen.
     *
     * @implNotes
     * This is using basic auth as Adyen provides 2 options and this option worked the best with the
     * commercepayments.PaymentsHttp class that is required to be used.
     */
    public static HttpRequest initRequest( Adyen_Adapter__mdt adyenAdapterMdt, String endpoint ) {
        HttpRequest request = new HttpRequest();

        String httpMethod = adyenAdapterMdt.Endpoint_Method__c;
        String calloutPath = adyenAdapterMdt.Endpoint_Path__c;
        String calloutVersion = adyenAdapterMdt.Endpoint_Api_Version__c;
        String username;
        String password;
    
        //   CommercePayments.PaymentsHttp on the send prefixes the Named Cred URI.
        if (!Test.isRunningTest()) {
            request.setEndpoint(calloutPath + calloutVersion + endpoint);
        }
        else {
            request.setEndpoint(TEST_ENDPOINT + endpoint);
        }
        request.setMethod( httpMethod );
        request.setHeader('Content-Type', CONTENT_TYPE);

        // Allow override of Named Credential WS Username and Password
        if (username != null && username != '') {
            username = adyenAdapterMdt.Service_Username__c;
            password = adyenAdapterMdt.Service_Password__c;

            Blob headerValue = Blob.valueOf(username + ':' + password);
            String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
            request.setHeader('Authorization', authorizationHeader);
        }
        else {
            // Default to the Named Credential configuration   NOT WELL SUPPORTED - Named credential must be configured with "Generate Authorization Header" so the WS username must be enabled at Adyen for company-wide access
            //username = '{!$Credential.UserName}';
            //password = '{!$Credential.Password}';
        }

        return request;
    }
    
    
    /**
     *  Serialized version of the Http Response Body received from Adyen to make it easier to work with the JSON.
     */
    public class AdyenResponse {
    
        public Integer status                       {get;set;} //HTTP Status Code
        public String pspReference                  {get;set;} //Recieved from Adyen in case of successful response   
        public String response                      {get;set;} //Received from Adyen in case of un-successful request
        public String errorCode                     {get;set;} //Adyen error code
        public String message                       {get;set;} //Adyen error message
        public String errorType                     {get;set;} //Adyen error type
        public Boolean operationSuccessful          {get;set;} //Custom Flag denoting if operation was successful or not
        
        public String getStatusString() {
            String statusCode = '';
            if(status != null) {
                statusCode = String.valueOf(this.status);
            }
            return statusCode;
        }
    }
    
    /**
     *  Serialized version of the Http Response Body received from Adyen to make it easier to work with the JSON.
     */
    public class AdyenNotification {
        public String live                                      {get;set;}
        public List<NotificationItems> notificationItems        {get;set;}
    }
    
    public class NotificationItems {
        public NotificationRequestItem NotificationRequestItem  {get;set;}
    }
    
    public class NotificationRequestItem {
        public Amount amount                                    {get;set;}
        public String eventCode                                 {get;set;}
        public String eventDate                                 {get;set;}
        public String merchantAccountCode                       {get;set;}
        public String originalReference                         {get;set;}
        public String paymentMethod                             {get;set;}
        public String pspReference                              {get;set;}
        public String reason                                    {get;set;}
        public String success                                   {get;set;}
    }
    
    public class Amount {
        public Decimal value                                    {get;set;}
        public String currency_x                                {get;set;} //  Due to currency being reserved.
    }
    
    public static AdyenResponse executeAPI(String payload, Adyen_Adapter__mdt adyenAdapterMdt, String endpoint) {
        AdyenResponse adyenResponse = new AdyenResponse();

        HttpRequest request = initRequest( adyenAdapterMdt, endpoint );
        //System.debug('--->Entering AdyenService.executeAPI payload='+payload + ' endpoint=' + endpoint + ' endPointMethod=' + endPointMethod + ' request=' + request);
        request.setBody( payload );
        try {
            CommercePayments.PaymentsHttp http = new CommercePayments.PaymentsHttp();
            HttpResponse response = http.send( request ); 
    
            if (response.getStatusCode() == HTTP_SUCCESS_CODE) { // Adyen accepted the request
                System.debug('--->Adyen Accepted Request');
                String sJson = response.getBody();
                adyenResponse = (AdyenResponse) JSON.deserialize(sJson, adyenResponse.class);
                adyenResponse.status = response.getStatusCode();
                adyenResponse.operationSuccessful = true;
            } else { // Adyen did not accepted the request
                System.debug('--->Adyen Did Not Accept Request');
                String sJson = response.getBody();
                adyenResponse = (AdyenResponse) JSON.deserialize(sJson, adyenResponse.class);
                adyenResponse.operationSuccessful = false;
            }
        } catch (Exception e) { 
            System.debug('--->Connectivity Issue with Adyen');
            System.debug(LoggingLevel.ERROR, e);
            adyenResponse.status = integer.valueOf(HTTP_SERVER_ERROR_CODE);
            adyenResponse.operationSuccessful = false;
            adyenResponse.message = e.getMessage();
        }
        //System.debug('--->Exiting AdyenService.executeAPI ='+adyenResponse);
        return adyenResponse;
    }
    
}