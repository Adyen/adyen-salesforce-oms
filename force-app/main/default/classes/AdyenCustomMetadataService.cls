public with sharing class AdyenCustomMetadataService {
   
    public static Adyen_Adapter__mdt getDefaultAdapter() {
        Map<String, Object> adapterData = new Map<String, Object>();

        try {
            Adyen_Adapter__mdt defaultAdapter = [
                SELECT Id, DeveloperName, MasterLabel, Package_Namespace__c,
                Merchant_Account__c, HMAC_Key__c, Auto_Capture_Enabled__c,
                Manual_Capture_Payment_Methods__c, System_Integrator_Name__c,
                Payment_Link_Return_Url__c, Payment_Link_Theme_Id__c,
                Payment_Link_Expiry_Duration__c
                FROM Adyen_Adapter__mdt
                WHERE DeveloperName = :AdyenConstants.DEFAULT_ADAPTER_NAME
                LIMIT 1
            ];

            return defaultAdapter;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Adyen adapter: ' + e.getMessage());
        }
    }

    public static String updateDefaultAdapter(Adyen_Adapter__mdt adapterData) {
        try {
            if (adapterData == null) {
                throw new HandledException('Please provide a valid adapter data.');
            }
            Adyen_Adapter__mdt defaultAdapter = [
                SELECT DeveloperName, MasterLabel, Package_Namespace__c
                FROM Adyen_Adapter__mdt
                WHERE DeveloperName = :AdyenConstants.DEFAULT_ADAPTER_NAME
                LIMIT 1
            ];

            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            String namespacePrefix = String.isNotBlank(defaultAdapter.Package_Namespace__c) ? defaultAdapter.Package_Namespace__c + '__' : '';
            
            Metadata.CustomMetadata adapterMetadata = new Metadata.CustomMetadata();
            adapterMetadata.fullName = namespacePrefix + 'Adyen_Adapter__mdt.' + namespacePrefix + AdyenConstants.DEFAULT_ADAPTER_NAME;
            adapterMetadata.label = defaultAdapter.MasterLabel;

            adapterMetadata.values = new List<Metadata.CustomMetadataValue>();

            addFieldIfNotNull(adapterMetadata, namespacePrefix + 'Merchant_Account__c', adapterData.Merchant_Account__c);
            addFieldIfNotNull(adapterMetadata, namespacePrefix + 'HMAC_Key__c', adapterData.HMAC_Key__c);
            addFieldIfNotNull(adapterMetadata, namespacePrefix + 'Auto_Capture_Enabled__c', adapterData.Auto_Capture_Enabled__c);
            addFieldIfNotNull(adapterMetadata, namespacePrefix + 'Manual_Capture_Payment_Methods__c', adapterData.Manual_Capture_Payment_Methods__c);
            addFieldIfNotNull(adapterMetadata, namespacePrefix + 'System_Integrator_Name__c', adapterData.System_Integrator_Name__c);
            addFieldIfNotNull(adapterMetadata, namespacePrefix + 'Payment_Link_Return_Url__c', adapterData.Payment_Link_Return_Url__c);
            addFieldIfNotNull(adapterMetadata, namespacePrefix + 'Payment_Link_Theme_Id__c', adapterData.Payment_Link_Theme_Id__c);
            addFieldIfNotNull(adapterMetadata, namespacePrefix + 'Payment_Link_Expiry_Duration__c', adapterData.Payment_Link_Expiry_Duration__c);

            mdContainer.addMetadata(adapterMetadata);

            Id deploymentId = deployMetadataWithCallback(mdContainer);
            return String.valueOf(deploymentId);

        } catch (Exception e) {
            throw new AuraHandledException('Error updating Adyen adapter: ' + e.getMessage());
        }
    }

    private static void addFieldIfNotNull(Metadata.CustomMetadata metadata, String fieldName, Object fieldValue) {
        if (fieldValue != null) {
            Metadata.CustomMetadataValue mdField = new Metadata.CustomMetadataValue();
            mdField.field = fieldName;
            mdField.value = fieldValue;
            metadata.values.add(mdField);
        }
    }

    private static Id deployMetadataWithCallback(metadata.DeployContainer mdContainer) {
        if (Test.isRunningTest() && TestDataFactory.isMetadataAPISuccessful) {
            return TestDataFactory.mockDeploymentId;
        }

        AdyenMetadataDeployCallback callback = new AdyenMetadataDeployCallback();
        return Metadata.Operations.enqueueDeployment(mdContainer, callback);
    }
}