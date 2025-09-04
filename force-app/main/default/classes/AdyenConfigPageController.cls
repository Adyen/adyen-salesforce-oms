public with sharing class AdyenConfigPageController {

    @AuraEnabled
    public static List<Id> createPaymentGateways(List<PaymentGatewayInput> paymentGatewayInputs) {
    
        if (paymentGatewayInputs == null || paymentGatewayInputs.isEmpty()) {
            throw new AuraHandledException('At least one Payment Gateway input is required.');
        }

        for(PaymentGatewayInput input : paymentGatewayInputs) {
            if(String.isBlank(input.gatewayName) || String.isBlank(input.externalReference)) {
                throw new AuraHandledException('Each Payment Gateway must have a name and an external reference.');
            }
        }

        PaymentGatewayProvider gatewayProvider = getPaymentGatewayProvider();
        NamedCredential merchantCredential = getNamedCredential(AdyenOMSConstants.CHECKOUT_NAMED_CREDENTIAL);

        if (gatewayProvider == null) {
            throw new AuraHandledException('Payment Gateway Provider not found.');
        }

        if (merchantCredential == null) {
            throw new AuraHandledException('Named Credential not found.');
        }

        List<PaymentGateway> paymentGatewaysToInsert = new List<PaymentGateway>();
        List<Id> paymentGatewayIds = new List<Id>();

        for (PaymentGatewayInput input : paymentGatewayInputs) {
            PaymentGateway newGateway = new PaymentGateway(
                PaymentGatewayName = input.gatewayName,
                PaymentGatewayProviderId = gatewayProvider.Id,
                MerchantCredentialId = merchantCredential.Id,
                Status = 'Active',
                ExternalReference = input.externalReference
            );
            paymentGatewaysToInsert.add(newGateway);
        }

        try {
            insert paymentGatewaysToInsert;
        } catch (DmlException e) {
            throw new AuraHandledException('Error occurred during Payment Gateway creation: ' + e.getMessage());
        }

        for (PaymentGateway gateway : paymentGatewaysToInsert) {
            paymentGatewayIds.add(gateway.Id);
        }

        return paymentGatewayIds;
    }

    @AuraEnabled
    public static List<PaymentGateway> getExistingPaymentGateways() {
        Set<String> externalReferences = new Set<String>{AdyenOMSConstants.PAYMENT_INSTRUMENT_ADYEN_COMPONENT, AdyenOMSConstants.PAYMENT_INSTRUMENT_ADYEN_POS};
        return [
            SELECT Id, PaymentGatewayName, ExternalReference, Status, CreatedDate
            FROM PaymentGateway
            WHERE PaymentGatewayProvider.DeveloperName = :AdyenOMSConstants.PAYMENT_GATEWAY_PROVIDER 
            AND ExternalReference IN :externalReferences
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled
    public static Map<String, String> getSetupPageUrls() {
        Map<String, String> setupUrls = new Map<String, String>();
        
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String checkoutNamedCredentialId = getNamedCredential(AdyenOMSConstants.CHECKOUT_NAMED_CREDENTIAL)?.Id;
        String managementApiNamedCredentialId = getNamedCredential(AdyenOMSConstants.MANAGEMENT_API_NAMED_CREDENTIAL)?.Id;
        String webhookNamedCredentialId =  getNamedCredential(AdyenOMSConstants.WEBHOOK_NAMED_CREDENTIAL_NAME)?.Id;

        if (checkoutNamedCredentialId == null || managementApiNamedCredentialId == null || webhookNamedCredentialId == null) {
            throw new AuraHandledException('One or more required Named Credentials are missing.');
        }
    
        setupUrls.put('checkoutNamedCredential', baseUrl + '/lightning/setup/NamedCredential/' + checkoutNamedCredentialId + '/view');
        setupUrls.put('managementApiNamedCredential', baseUrl + '/lightning/setup/NamedCredential/' + managementApiNamedCredentialId + '/view');
        setupUrls.put('permissionSet', baseUrl + '/lightning/setup/PermSets/home');
        setupUrls.put('siteSetup', baseUrl + '/lightning/setup/CustomDomain/home');
        setupUrls.put('webhookNamedCredential', baseUrl + '/lightning/setup/NamedCredential/' + getNamedCredential(AdyenOMSConstants.WEBHOOK_NAMED_CREDENTIAL_NAME)?.Id + '/view');
        setupUrls.put('salesChannelLayouts', baseUrl + '/lightning/setup/ObjectManager/SalesChannel/PageLayouts/view');
        setupUrls.put('paymentLayouts', baseUrl + '/lightning/setup/ObjectManager/Payment/PageLayouts/view');
        setupUrls.put('paymentAuthorizationLayouts', baseUrl + '/lightning/setup/ObjectManager/PaymentAuthorization/PageLayouts/view');
    
        return setupUrls;
    }

    @AuraEnabled
    public static Boolean isProductionOrg() {
        Organization org = [SELECT IsSandbox, OrganizationType FROM Organization LIMIT 1];
        return !org.IsSandbox && org.OrganizationType != 'Developer Edition';
    }

    private static PermissionSet getOrderManagementPermissionSet() {
        List<PermissionSet> permissionSets = [
            SELECT Id
            FROM PermissionSet 
            WHERE Name = :AdyenOMSConstants.ORDER_MANAGEMENT_B2C_SERVICE_PERMISSION_SET
            LIMIT 1
        ];
        
        if (permissionSets.isEmpty()) {
            throw new HandledException('Order Management permission set (sfdc_ccordermanagement) not found.');
        }
        
        return permissionSets[0];
    }

    @AuraEnabled
    public static Map<String, String> getPermissionSetUrls() {
        Map<String, String> permissionUrls = new Map<String, String>();
        
        try {
            String baseUrl = URL.getOrgDomainUrl().toExternalForm();
            PermissionSet permissionSet = getOrderManagementPermissionSet();
    
            permissionUrls.put('omsB2cPermissionSetUrl', baseUrl + '/lightning/r/PermissionSet/' + permissionSet.Id + '/view');
            
        } catch (Exception e) {
            throw new AuraHandledException('Error generating permission set URL: ' + e.getMessage());
        }
        
        return permissionUrls;
    }

    private static PaymentGatewayProvider getPaymentGatewayProvider() {
        List<PaymentGatewayProvider> gatewayProviders = [
            SELECT Id 
            FROM PaymentGatewayProvider 
            WHERE DeveloperName = :AdyenOMSConstants.PAYMENT_GATEWAY_PROVIDER
            LIMIT 1
        ];

        return gatewayProviders.isEmpty() ? null : gatewayProviders[0];
    }
    
    public static NamedCredential getNamedCredential(String developerName) {
        List<NamedCredential> namedCredentials = [
            SELECT Id 
            FROM NamedCredential 
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];
    
        return namedCredentials.isEmpty() ? null : namedCredentials[0];
    }
    
    public class PaymentGatewayInput {
        @AuraEnabled public String externalReference { get; set; }
        @AuraEnabled public String gatewayName { get; set; }
    }
}