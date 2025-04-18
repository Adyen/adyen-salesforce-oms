@IsTest
private class WebhookUtilsTest {

    @IsTest
    static void parseNotificationValidRequestTest() {
        // given a valid notification request
        String validRequestBody = TestDataFactory.mockWebhookRequest(AdyenConstants.NOTIFICATION_REQUEST_TYPE_CANCEL, '123456789012ABCD', '101010101010ABCD', '999999', true);
        
        // when
        NotificationRequestItem result = WebhookUtils.parseAdyenNotificationRequest(validRequestBody);
        
        // then
        Assert.isNotNull(result, 'Expected parsed NotificationRequestItem to be not null.');
        Assert.areEqual('123456789012ABCD', result.pspReference, 'Expected PSP Reference to match.');
        Assert.areEqual('CANCELLATION', result.eventCode, 'Expected event code to be CANCELLATION.');
    }

    @IsTest
    static void parseNotificationEmptyRequestTest() {
        // given an empty request body
        String emptyRequestBody = '';
        
         // When
         try {
            Test.startTest();
            WebhookUtils.parseAdyenNotificationRequest(emptyRequestBody);
            Test.stopTest();
        } catch (AdyenGatewayAdapter.GatewayException e) {
            // Then
            Assert.areEqual('Notification Request Body is invalid', e.getMessage(), 'Unexpected exception message');
        }
    }

    @IsTest
    static void parseNotificationNullRequestTest() {
        // given a null request body
        String nullRequestBody = null;

        // when
         try {
            Test.startTest();
            WebhookUtils.parseAdyenNotificationRequest(nullRequestBody);
            Test.stopTest();
        } catch (AdyenGatewayAdapter.GatewayException e) {
            // Then
            Assert.areEqual('Notification Request Body is invalid', e.getMessage(), 'Unexpected exception message');
        }
    }

    @IsTest
    static void getPaymentGatewayProviderIdTest() {
        String id = WebhookUtils.getPaymentGatewayProviderId();
        Assert.areNotEqual(null, id);
    }

    @IsTest(SeeAllData=true)
    static void isStandardOMSNotificationValidCaptureTest() {
        // given
        OrderPaymentSummary ops = TestDataFactory.insertAccountAndOrderPaymentSummary();
    
        CardPaymentMethod paymentMethod = TestDataFactory.createCardPaymentMethod();
        insert paymentMethod;
       	Payment payment = TestDataFactory.createPayment(null, paymentMethod.Id, null, null, ops.Id);
        payment.GatewayRefNumber = TestDataFactory.TEST_PSP_REFERENCE;
		insert payment;
        NotificationRequestItem item = new NotificationRequestItem();
        item.eventCode = 'CAPTURE';
        item.pspReference = TestDataFactory.TEST_PSP_REFERENCE;
        item.originalReference = TestDataFactory.TEST_PSP_REFERENCE;

        // when
        Test.startTest();
        Boolean isOMSCaptureNotification = WebhookUtils.isStandardOMSNotification(item);
        Test.stopTest();

        // then
        Assert.areEqual(true, isOMSCaptureNotification);
    }
    
    @IsTest(SeeAllData=true)
    static void isStandardOMSNotificationValidRefundTest() {
        // given
        OrderPaymentSummary ops = TestDataFactory.insertAccountAndOrderPaymentSummary();
        CardPaymentMethod paymentMethod = TestDataFactory.createCardPaymentMethod();
        insert paymentMethod;
        Refund refund = new Refund(
            PaymentMethodId = paymentMethod.Id,
            Amount = TestDataFactory.TEST_PRICE_AMOUNT,
            GatewayRefNumber = TestDataFactory.TEST_PSP_REFERENCE,
            Status = AdyenOMSConstants.PaymentAuthorizationStatus.PROCESSED.name(),
            ProcessingMode = AdyenOMSConstants.ProcessingMode.EXTERNAL.name(),
            Type = 'Referenced',
            OrderPaymentSummaryId = ops.Id
        );
        insert refund;
        NotificationRequestItem item = new NotificationRequestItem();
        item.eventCode = 'REFUND';
        item.pspReference = TestDataFactory.TEST_PSP_REFERENCE;
        item.originalReference = TestDataFactory.TEST_PSP_REFERENCE;

        // when
        Test.startTest();
        Boolean isOMSRefundNotification = WebhookUtils.isStandardOMSNotification(item);
        Test.stopTest();
        
        // then
        Assert.areEqual(true, isOMSRefundNotification);
    }
}