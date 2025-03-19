public with sharing class AdyenOOBOController {

    @AuraEnabled(Cacheable=true)
    public static Id getOrderSummaryIdByOrderNumber(String orderNumber) {
        try {
            List<OrderSummary> orderSummaries = [
                SELECT Id 
                FROM OrderSummary 
                WHERE OrderNumber = :orderNumber 
                LIMIT 1
            ];

            if (!orderSummaries.isEmpty()) {
                return orderSummaries[0].Id;
            } else {
                throw new AuraHandledException('Order Summary not found for the provided order number: ' + orderNumber);
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(Cacheable=true)
    public static Decimal getExpiryDuration() {
        try {
            Decimal expiryDurationDays = [SELECT Payment_Link_Expiry_Duration__c FROM Adyen_Adapter__mdt WHERE DeveloperName = :AdyenConstants.DEFAULT_ADAPTER_NAME].Payment_Link_Expiry_Duration__c;
            if (expiryDurationDays == null) {
                expiryDurationDays = 1;
            }
            return expiryDurationDays;
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to fetch ' + AdyenConstants.DEFAULT_ADAPTER_NAME + ' custom metadata Adyen Adapter record. Error: ' + ex.getMessage());
        }
    }

    @AuraEnabled(Cacheable=true)
    public static AccountEmailAndName getAccountEmailAndName(Id accountId) {
        try {
            if (AdyenPaymentUtility.personAccountsEnabled()) {
                Account accountRecord = Database.query('SELECT Name, PersonEmail FROM Account WHERE Id = :accountId');
                return new AccountEmailAndName(accountRecord.Name, (String)accountRecord.get('PersonEmail'));
            } else {
                List<Contact> contactRecords = [SELECT Name, Email FROM Contact WHERE AccountId = :accountId AND Email <> NULL ORDER BY CreatedDate DESC];
                if (contactRecords.size() >= 1) {
                    return new AccountEmailAndName(contactRecords[0].Name, contactRecords[0].Email);
                } else {
                    throw new HandledException('No contact found for this account id ' + accountId);
                }
            }
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to fetch account email. Error: ' + ex.getMessage());
        }
    }

    public class AccountEmailAndName {
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String email;

        public AccountEmailAndName(String name, String email) {
            this.name = name;
            this.email = email;
        }
    }
}