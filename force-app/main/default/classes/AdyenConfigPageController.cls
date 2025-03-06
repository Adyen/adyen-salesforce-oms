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
        NamedCredential merchantCredential = getNamedCredential();

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

    private static PaymentGatewayProvider getPaymentGatewayProvider() {
        List<PaymentGatewayProvider> gatewayProviders = [
            SELECT Id 
            FROM PaymentGatewayProvider 
            WHERE DeveloperName = :AdyenOMSConstants.PAYMENT_GATEWAY_PROVIDER
            LIMIT 1
        ];

        return gatewayProviders.isEmpty() ? null : gatewayProviders[0];
    }
    
    private static NamedCredential getNamedCredential() {
        List<NamedCredential> namedCredentials = [
            SELECT Id 
            FROM NamedCredential 
            WHERE DeveloperName = :AdyenOMSConstants.NAMED_CREDENTIAL
            LIMIT 1
        ];
    
        return namedCredentials.isEmpty() ? null : namedCredentials[0];
    }
    

    public class PaymentGatewayInput {
        @AuraEnabled public String externalReference;
        @AuraEnabled public String gatewayName;
    }
}
