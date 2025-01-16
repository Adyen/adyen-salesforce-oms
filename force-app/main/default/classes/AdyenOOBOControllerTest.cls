@IsTest
public class AdyenOOBOControllerTest {

    @IsTest(SeeAllData=true)
    static void getOrderSummaryIdByOrderNumberTest_Success() {
        // Given
        Account acct = TestDataFactory.createAccount();
        insert acct;
        Order order = TestDataFactory.insertOrderAndRelatedRecords(acct.Id, 50, 10);
        OrderPaymentSummary orderPaymentSummary = TestDataFactory.createOrderSummaryRecords(order.Id);
        TestDataFactory.insertBasicPaymentRecords(acct.Id, orderPaymentSummary.Id);
        OrderSummary os = [SELECT Id, OrderNumber FROM OrderSummary LIMIT 1];

        // When
        Test.startTest();
        Id result = AdyenOOBOController.getOrderSummaryIdByOrderNumber(os.OrderNumber);
        Test.stopTest();

        // Then
        Assert.areEqual(os.Id, result, 'The returned Id should match the test OrderSummary Id.');
    }

    @IsTest(SeeAllData=true)
    static void getOrderSummaryIdByOrderNumberTest_NotFound() {
        // Given
        // No test data created intentionally for this scenario

        // When
        Test.startTest();
        try {
            AdyenOOBOController.getOrderSummaryIdByOrderNumber('NON_EXISTING_ORDER_NUMBER');
            Assert.fail('An Exception should have been thrown.');
        } catch (AuraHandledException e) {
            // Then
            Assert.areEqual(
                'Script-thrown exception',
                e.getMessage(),
                'The error message should match the expected output.'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void getExpiryDurationTest() {
        // given
        Decimal currentExpiryDays = [SELECT Payment_Link_Expiry_Duration__c FROM Adyen_Adapter__mdt WHERE DeveloperName = :AdyenConstants.DEFAULT_ADAPTER_NAME].Payment_Link_Expiry_Duration__c;
        // when
        Decimal fetchedExpiryDays = AdyenOOBOController.getExpiryDuration();
        // then
        if(currentExpiryDays == null) {
            Assert.areEqual(1, fetchedExpiryDays);
        } else {
            Assert.areEqual(currentExpiryDays, fetchedExpiryDays);
        }
    }

    @IsTest
    static void getAccountEmailAndNameTest() {
        // given
        Contact newContact = TestDataFactory.insertAccountWithContact();
        newContact = [SELECT Name, Email, AccountId FROM Contact WHERE Id = :newContact.Id];
        // when
        AdyenOOBOController.AccountEmailAndName acctInfo = AdyenOOBOController.getAccountEmailAndName(newContact.AccountId);
        // then
        Assert.areEqual(newContact.Email, acctInfo.email);
        Assert.areEqual(newContact.Name, acctInfo.name);
    }

    @IsTest
    static void getAccountEmailAndNameErrorTest() {
        // given - no account
        try { // when
            AdyenOOBOController.getAccountEmailAndName(null);
            Assert.fail();
        } catch (Exception ex) { // then
            Assert.isInstanceOfType(ex, AuraHandledException.class);
        }
    }
}