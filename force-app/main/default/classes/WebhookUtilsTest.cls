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
}
