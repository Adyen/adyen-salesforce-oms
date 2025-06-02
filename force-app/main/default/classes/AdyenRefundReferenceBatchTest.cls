@IsTest
private class AdyenRefundReferenceBatchTest {
    
    @TestSetup
    static void setupTestData() {
        Refund refund = new Refund(
            Status = 'Processed',
            Type = 'Referenced',
            ProcessingMode = 'External',
            Amount = 100.00
        );
        insert refund;
        
        Refund refundWithReference = new Refund(
            Status = 'Processed',
            Type = 'Referenced',
            ProcessingMode = 'External',
            Amount = 100.00,
            Refund_Reference__c = '12345'
        );
        insert refundWithReference;
    }
    
    @IsTest
    static void validReferenceTest() {
        // Given
        Refund refund = [SELECT Id FROM Refund WHERE Refund_Reference__c = NULL LIMIT 1];
        
        PaymentGatewayLog gatewayLog = new PaymentGatewayLog(
            InteractionType = 'ReferencedRefund',
            GatewayMessage = '[refund-received]',
            ReferencedEntityId = refund.Id,
            Request = '{"reference":"0000000292873000"}'
        );
        insert gatewayLog;
        
        // When
        AdyenRefundReferenceBatch batch = new AdyenRefundReferenceBatch();
        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();
        
        // Then
        Refund updatedRefund = [SELECT Id, Refund_Reference__c FROM Refund WHERE Id = :refund.Id];
        Assert.areEqual('0000000292873000', updatedRefund.Refund_Reference__c, 
                        'Expected Refund_Reference__c to be updated with the reference 0000000292873000');
    }
    
    @IsTest
    static void missingReferenceTest() {
        // Given
        Refund refund = [SELECT Id FROM Refund WHERE Refund_Reference__c = NULL LIMIT 1];
        
        List<PaymentGatewayLog> gatewayLogs = new List<PaymentGatewayLog>();
        gatewayLogs.add(new PaymentGatewayLog(
            InteractionType = 'ReferencedRefund',
            GatewayMessage = '[refund-received]',
            ReferencedEntityId = refund.Id,
            Request = '{"merchantAccount":"Test_Merchant_Account"}'
        ));
        insert gatewayLogs;
        
        // When
        AdyenRefundReferenceBatch batch = new AdyenRefundReferenceBatch();
        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();
        
        // Then
        Refund updatedRefund = [SELECT Id, Refund_Reference__c FROM Refund WHERE Id = :refund.Id];
        Assert.isNull(updatedRefund.Refund_Reference__c, 'Expected Refund_Reference__c to remain null');
    }
    
    @IsTest
    static void nullRequestTest() {
        // Given
        Refund refund = [SELECT Id FROM Refund WHERE Refund_Reference__c = NULL LIMIT 1];
        
        PaymentGatewayLog gatewayLog = new PaymentGatewayLog(
            InteractionType = 'ReferencedRefund',
            GatewayMessage = '[refund-received]',
            ReferencedEntityId = refund.Id,
            Request = null
        );
        insert gatewayLog;
        
        // When
        AdyenRefundReferenceBatch batch = new AdyenRefundReferenceBatch();
        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();
        
        // Then
        Refund updatedRefund = [SELECT Id, Refund_Reference__c FROM Refund WHERE Id = :refund.Id];
        Assert.isNull(updatedRefund.Refund_Reference__c, 'Expected Refund_Reference__c to remain null');
    }
    
    @IsTest
    static void noEligibleRecordsTest() {
        // Given
        Refund refund = [SELECT Id FROM Refund WHERE Refund_Reference__c = '12345' LIMIT 1];
        
        PaymentGatewayLog gatewayLog = new PaymentGatewayLog(
            InteractionType = 'ReferencedRefund',
            GatewayMessage = '[refund-received]',
            ReferencedEntityId = refund.Id,
            Request = '{"reference":"0000000292873000"}'
        );
        insert gatewayLog;
        
        // When
        AdyenRefundReferenceBatch batch = new AdyenRefundReferenceBatch();
        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();
        
        // Then
        Refund updatedRefund = [SELECT Id, Refund_Reference__c FROM Refund WHERE Id = :refund.Id];
        Assert.areEqual('12345', updatedRefund.Refund_Reference__c, 'Expected Refund_Reference__c to remain unchanged');
    }
}