@IsTest
public class AdyenPBLControllerTest {

    @IsTest
    static void updatePaymentLinkStatusSuccessTest() {
        // Given
        Payment_Link__c paymentLink = new Payment_Link__c(
            Name = 'PLE5B4575C5A026A2B2',
            Status__c = 'Active'
        );
        insert paymentLink;

        Test.setMock(HttpCalloutMock.class, new TestDataFactory.PBLExpiredMockResponse());

        // When
        Test.startTest();
        AdyenPBLController.updatePaymentLinkStatus(paymentLink.Id);
        Test.stopTest();

        // Then
        Payment_Link__c updatedPaymentLink = [SELECT Status__c FROM Payment_Link__c WHERE Id = :paymentLink.Id];
        Assert.areEqual('Expired', updatedPaymentLink.Status__c, 'The payment link status should be updated to Expired.');
    }

    @IsTest
    static void updatePaymentLinkStatusInvalidLinkTest() {
        // Given
        // No Payment Link ID provided (null case)

        // When & Then
        try {
            AdyenPBLController.updatePaymentLinkStatus(null);
            Assert.fail('Exception was not thrown');
        } catch (AuraHandledException e) {
            Assert.isTrue(
                e.getMessage().contains('Script-thrown exception'),
                'Expected a script-thrown exception message.'
            );
        }
    }

}