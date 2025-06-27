public with sharing class AdyenManagementAPIService {
    
    public class MerchantAccountResponse {
        public List<MerchantAccount> data { get; set; }
        public Integer itemsTotal { get; set; }
        public Integer pagesTotal { get; set; }
    }
    
    public class MerchantAccount {
        @AuraEnabled
        public String id { get; set; }
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String status { get; set; }
        @AuraEnabled
        public String description { get; set; }
        @AuraEnabled
        public String companyId { get; set; }
        @AuraEnabled
        public String captureDelay { get; set; }
    }
    
    public class MerchantAccountResult {
        @AuraEnabled
        public Boolean isSuccess { get; set; }
        @AuraEnabled
        public String errorMessage { get; set; }
        @AuraEnabled
        public List<MerchantAccount> merchantAccounts { get; set; }
        @AuraEnabled
        public Integer totalCount { get; set; }
        
        public MerchantAccountResult() {
            this.merchantAccounts = new List<MerchantAccount>();
        }
    }
    
    @AuraEnabled
    public static MerchantAccountResult fetchMerchantAccounts() {
        MerchantAccountResult result = new MerchantAccountResult();
        
        try {
            Adyen_Adapter__mdt adyenAdapter = AdyenPaymentUtility.retrieveAdapterByDeveloperName(AdyenConstants.DEFAULT_ADAPTER_NAME);
            String endpoint = buildManagementAPIEndpoint(adyenAdapter);
            
            HttpResponse response = makeHttpRequest('GET', endpoint, null);
            
            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                String responseBody = response.getBody();
                MerchantAccountResponse apiResponse = (MerchantAccountResponse) JSON.deserialize(responseBody, MerchantAccountResponse.class);
                
                result.isSuccess = true;
                result.merchantAccounts = apiResponse.data != null ? apiResponse.data : new List<MerchantAccount>();
                result.totalCount = apiResponse.itemsTotal != null ? apiResponse.itemsTotal : 0;
                
            } else {
                result.isSuccess = false;
                result.errorMessage = parseErrorMessage(response);
            }
            
        } catch (Exception e) {
            result.isSuccess = false;
            result.errorMessage = 'Error fetching merchant account: ' + e.getMessage();
        }
        
        return result;
    }
    
    private static String buildManagementAPIEndpoint(Adyen_Adapter__mdt adyenAdapter) {
        String namespace = String.isNotBlank(adyenAdapter.Package_Namespace__c) ? adyenAdapter.Package_Namespace__c + '__' : '';
        String baseUrl = 'callout:' + namespace + adyenAdapter.Management_API_Named_Credential__c;
        
        return String.format('{0}{1}{2}', new List<String>{
            baseUrl,
            adyenAdapter.Management_API_Version__c,
            adyenAdapter.Management_API_Endpoint_Path__c
        });
    }
    
    public static HttpResponse makeHttpRequest(String method, String endpoint, String requestBody) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod(method);
        request.setHeader('Content-Type', 'application/json');
        
        if (method != 'GET' && String.isNotBlank(requestBody)) {
            request.setBody(requestBody);
        }
        
        HttpResponse response = http.send(request);
        return response;
    }
    
    public static String parseErrorMessage(HttpResponse response) {
        String errorMessage = 'HTTP ' + response.getStatusCode() + ': ' + response.getStatus();
        try {
            String responseBody = response.getBody();
            if (String.isNotBlank(responseBody)) {
                Map<String, Object> errorResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                
                if (errorResponse.containsKey('title')) {
                    errorMessage = (String) errorResponse.get('title');
                } else if (errorResponse.containsKey('detail')) {
                    errorMessage = (String) errorResponse.get('detail');
                }
            }
        } catch (Exception e) {
            return errorMessage;
        }
        
        return errorMessage;
    }
}