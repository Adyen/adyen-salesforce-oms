public without sharing class BatchAdyenOMSMigration implements Database.Batchable<sObject> {
    public final String namespaceFor2GP;
    public static final String ADYEN_2GP_NAMESPACE = 'adyen_payment';


    public BatchAdyenOMSMigration() {
        namespaceFor2GP = ADYEN_2GP_NAMESPACE + '__';
    }

    public BatchAdyenOMSMigration(String namespace2GP) {
        namespaceFor2GP = namespace2GP;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String orderSummaryQuery = 
            'SELECT OrderSummary.adyensompackage__Adyen_paymentMethod__c, ' +
                '(SELECT ' + namespaceFor2GP + 'Adyen_Payment_Method__c, ' + namespaceFor2GP + 'Adyen_Payment_Method_Variant__c FROM PaymentAuthorizations), ' +
                '(SELECT ' + namespaceFor2GP + 'Adyen_Payment_Method__c, ' + namespaceFor2GP + 'Adyen_Payment_Method_Variant__c FROM Payments) ' +
            'FROM OrderPaymentSummary ' +
            'WHERE OrderSummary.adyensompackage__Adyen_paymentMethod__c != null ' +
            'ORDER BY CreatedDate';
        return Database.getQueryLocator(orderSummaryQuery);
    }
    
    public void execute(Database.BatchableContext bc, List<OrderPaymentSummary> orderPaySummaries) {
        List<String> destinationFields = new List<String>{namespaceFor2GP + 'Adyen_Payment_Method__c', namespaceFor2GP + 'Adyen_Payment_Method_Variant__c'};
        List<SObject> recordsToUpdate = new List<SObject>();

        for (OrderPaymentSummary orderPaySummary : orderPaySummaries) {
            List<SObject> relatedPayments = new List<SObject>();
            relatedPayments.addAll(orderPaySummary.PaymentAuthorizations);
            relatedPayments.addAll(orderPaySummary.Payments);
            for (SObject relatedPay : relatedPayments) {
                relatedPay.put(destinationFields[0], orderPaySummary.OrderSummary.adyensompackage__Adyen_paymentMethod__c);
                relatedPay.put(destinationFields[1], orderPaySummary.OrderSummary.adyensompackage__Adyen_paymentMethod__c);
                recordsToUpdate.add(relatedPay);
            }
        }

        update recordsToUpdate;
    }
    
    public void finish(Database.BatchableContext bc) {
        AsyncApexJob asyncJob = [
            SELECT Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedBy.Email
            FROM AsyncApexJob WHERE Id = :bc.getJobId()
        ];

        String emailPlainText = 'The batch Apex job processed {0} batches with {1} failures.';
        List<Integer> parameters = new List<Integer>{asyncJob.TotalJobItems, asyncJob.NumberOfErrors};
        String formattedEmailText = String.format(emailPlainText, parameters);
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[] {asyncJob.CreatedBy.Email};
        mail.setToAddresses(toAddresses);
        mail.setSubject('Adyen OMS 2GP package Migration Batch ' + asyncJob.Status);
        mail.setPlainTextBody(formattedEmailText);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
}