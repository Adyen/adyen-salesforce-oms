@IsTest
private class AdyenPaymentLinkBatchTest {
    
    @IsTest
    static void expiredLinkTest() {
        // Given
        List<Payment_Link__c> paymentLinks = new List<Payment_Link__c>();
        
        paymentLinks.add(new Payment_Link__c(
            Expire_Date__c = System.now().addDays(-1),
            Status__c = 'Active'
        ));
        paymentLinks.add(new Payment_Link__c(
            Expire_Date__c = System.now().addDays(1),
            Status__c = 'Active'
        ));
        
        insert paymentLinks;
        
        // When
        AdyenPaymentLinkBatch batch = new AdyenPaymentLinkBatch();
        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();
        
        // Then
        List<Payment_Link__c> updatedLinks = [SELECT Id, Status__c FROM Payment_Link__c];
        Assert.areEqual(updatedLinks[0].Status__c, 'Expired');
        Assert.areEqual(updatedLinks[1].Status__c, 'Active');
    }

    @IsTest
    static void noExpiredLinksTest() {
        // Given
        List<Payment_Link__c> paymentLinks = new List<Payment_Link__c>();
        
        paymentLinks.add(new Payment_Link__c(
            Expire_Date__c = System.now().addDays(1),
            Status__c = 'Active'
        ));
        paymentLinks.add(new Payment_Link__c(
            Expire_Date__c = System.now().addDays(2),
            Status__c = 'Active'
        ));

        insert paymentLinks;
        
        // When
        AdyenPaymentLinkBatch batch = new AdyenPaymentLinkBatch();
        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();
        
        // Then
        List<Payment_Link__c> updatedLinks = [SELECT Id, Status__c FROM Payment_Link__c];
        Assert.areEqual(updatedLinks[0].Status__c, 'Active');
        Assert.areEqual(updatedLinks[1].Status__c, 'Active');
    }

    @IsTest
    static void nullExpireDateTest() {
        // Given
        insert new Payment_Link__c(Status__c = 'Active');
        
        // When
        AdyenPaymentLinkBatch batch = new AdyenPaymentLinkBatch();
        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();

        // Then
        Payment_Link__c link = [SELECT Status__c FROM Payment_Link__c LIMIT 1];
        Assert.areEqual('Active', link.Status__c);
    }
    
}
