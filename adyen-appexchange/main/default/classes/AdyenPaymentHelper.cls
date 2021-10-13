public with sharing class AdyenPaymentHelper {

	@TestVisible
	private static final string DEFAULT_ADAPTER_NAME            = 'AdyenDefault';

	public static final Integer HTTP_SUCCESS_CODE               = 200;
	public static final String  GATEWAY_ERROR_RESPONSE_CODE     = '400';
	public static final String  APEX_RESERVED_CURRENCY_FIELD    = 'currency_x'; // allows deserialization of reserved words.
	
    private static final commercepayments.SalesforceResultCodeInfo SUCCESS_SALESFORCE_RESULT_CODE_INFO = 
        new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.Success);
    private static final commercepayments.SalesforceResultCodeInfo DECLINE_SALESFORCE_RESULT_CODE_INFO = 
        new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.Decline);
    private static final commercepayments.SalesforceResultCodeInfo SYSTEMERROR_SALESFORCE_RESULT_CODE_INFO = 
        new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.SystemError);
    private static final commercepayments.SalesforceResultCodeInfo VALIDATIONERROR_SALESFORCE_RESULT_CODE_INFO = 
        new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.ValidationError);
	
	@TestVisible private static final String NOTIFICATION_REQUEST_TYPE_CAPTURE  = 'capture';
	@TestVisible private static final String NOTIFICATION_REQUEST_TYPE_REFUND   = 'refund';
	@TestVisible private static final String NOTIFICATION_REQUEST_TYPE_CAPTURE_FAILED  = 'capture-failed';
    @TestVisible private static final String NOTIFICATION_REQUEST_TYPE_CANCEL = 'cancel';
	@TestVisible private static final String NOTIFICATION_ACCEPTED_RESPONSE     = '[accepted]';

    /**
     *  Receives Payement Gateway Context from AdyenAsyncAdapter, looks at the context type and then invokes the appropriate Capture or Refund operation
     * 
     * @param paymentGatewayContext
     * @returns `commercepayments.GatewayResponse` 
     */
    public static commercepayments.GatewayResponse handleFulfillmentOrderStatusChange(commercepayments.paymentGatewayContext paymentGatewayContext){
        commercepayments.RequestType paymentRequestType = paymentGatewayContext.getPaymentRequestType();
        
        if (paymentRequestType == commercepayments.RequestType.Capture) {
            return captureFunds( (commercepayments.CaptureRequest) paymentGatewayContext.getPaymentRequest() ) ;
        } else if (paymentRequestType == commercepayments.RequestType.ReferencedRefund) {
            return refundFunds( (commercepayments.ReferencedRefundRequest)paymentGatewayContext.getPaymentRequest() );
        } else if (paymentRequestType == commercepayments.RequestType.AuthorizationReversal) {
            return cancelAuthorization( (commercepayments.AuthorizationReversalRequest)paymentGatewayContext.getPaymentRequest() );
        } else{ // there maybe future work for Auth Reversal, but ignoring everything else for now
            commercepayments.GatewayResponse paymentGatewayResponse;
            return paymentGatewayResponse;
        }
    }


    /**
     * invoked by handleFulfillmentOrderStatusChange to capture funds with Adyen
     * @param captureRequest 
     * @returns `commercepayments.GatewayResponse`
     */
    private static commercepayments.GatewayResponse captureFunds(commercepayments.CaptureRequest captureRequest) {
        
        // Retrieve the PaymentAuthorization
        PaymentAuthorization pa = AdyenPaymentUtility.retrievePaymentAuthorization(captureRequest.paymentAuthorizationId);

        // By Default, retrieve the metadata key from the order's sales channel
        String adapterName = pa?.OrderPaymentSummary.OrderSummary.SalesChannel.ADYENSOMPACKAGE__ADYENMERCHANTID__C; 

        // Override config for this specific PaymentAuthorization
        if (String.isNotBlank(pa?.ADYENSOMPACKAGE__adyenOverrideMerchantConfig__c)) {
            adapterName = pa.ADYENSOMPACKAGE__adyenOverrideMerchantConfig__c;
        }
        if (String.isBlank(adapterName)) {
            adapterName = DEFAULT_ADAPTER_NAME;
        }
        Adyen_Adapter__mdt adyenAdapterMdt = AdyenPaymentUtility.retrieveGatewayMetadata(adapterName);

        String captureRequestPayload = createCaptureRequest( captureRequest, pa, adyenAdapterMdt );
        String endPointMethod, captureEndpoint, cardHolderName, orderPaymentSummaryId;

        if (pa != null && pa.OrderPaymentSummary != null)
        {
            cardHolderName = pa.OrderPaymentSummary.FullName;
            if(cardHolderName == 'NetworkErrorWhileCapturing') {
                captureEndpoint = 'wrongendpoint';
                orderPaymentSummaryId = pa.OrderPaymentSummary.Id;
                System.debug('---->Entering AdyenPaymentHelper.captureFunds orderPaymentSummaryId=' + orderPaymentSummaryId);
            }
        }

        AdyenService.AdyenResponse adyenResponse = AdyenService.executeAPI(captureRequestPayload, adyenAdapterMdt, adyenAdapterMdt.Capture_Endpoint__c);

        commercepayments.CaptureResponse captureResponse = new commercepayments.CaptureResponse();
        captureResponse.setAsync(true);
        captureResponse.setAmount(captureRequest.amount);
        commercepayments.GatewayResponse gatewayResponse = processCaptureResponse(adyenResponse, captureResponse, captureRequest.paymentAuthorizationId, captureRequestPayload);

        //System.debug('---->Exiting AdyenPaymentHelper.captureFunds ='+gatewayResponse);
        return gatewayResponse;
    }

    /**
     * Creates a JSON string necessary to put in the body to call the capture api.
     *
     * @param captureRequest    A commercepayments CaptureRequest object containing  the paymentAuthorizationId,
     *                          accountId, and amount.
     *
     * @return String           A valid JSON String with request info. ie.
     *
     *                          {"modificationAmount":{"currency":"USD","value":500.55},"merchantAccount":"Capgemini446ECOM",
     *                          "reference":"00000106","originalReference":"883583158575596D"}
     *
     * @see https://docs.adyen.com/api-explorer/#/Payment/v52/capture
     */
    private static String createCaptureRequest(commercepayments.CaptureRequest captureRequest, PaymentAuthorization pa, Adyen_Adapter__mdt adyenAdapterMdt ) {

        String defaultCurrencyCode = adyenAdapterMdt.Single_Currency_Code__c;
        String merchantAccount = adyenAdapterMdt.Merchant_Account__c;

        String currencyCode = pa != null && defaultCurrencyCode == null ? (String)pa.get('CurrencyIsoCode') : defaultCurrencyCode;
    
        Map<String, Object> modificationAmount = new Map<String, Object>();

        Decimal captureValue = captureRequest.amount != null ? Decimal.valueOf(captureRequest.amount) : null;

        if(captureValue != null) {
            captureValue = captureValue * AdyenPaymentUtility.getAmountMultiplier(currencyCode);
        }
        modificationAmount.put('value', String.valueOf(Integer.valueOf(captureValue)));
        modificationAmount.put('currency', currencyCode);

        Map<String, Object> requestObj = new Map<String, Object>();

        String pspReference = AdyenPaymentUtility.getCaptureGatewayRefNumber(pa);

        requestObj.put('originalReference', pspReference);
        requestObj.put('merchantAccount', merchantAccount);
        requestObj.put('modificationAmount', modificationAmount);

        // For payment methods requiring Open Invoice data (e.g., Klarna), append it
        if (AdyenPaymentUtility.checkIfKlarnaOrderFromAuthorization(pa)) {
            System.debug('---->Inside AdyenPaymentHelper.createCaptureRequest, starting to create additionalData=');
            System.debug('--------> captureRequest AdditionalData: ' + captureRequest.additionalData);

            // Get invoice id
            String invoiceId = 'INVALID';
            if (captureRequest.additionalData.containsKey('invoiceId')) {
                invoiceId = captureRequest.additionalData.get('invoiceId');
            }
            System.debug('--------> paymentRequest InvoiceId: ' + invoiceId);

            Map<String, Object> additionalData = new Map<String, Object>();

            // Pull all InvoiceLines.  Send adjustments + charge vs shipping
            List<InvoiceLine> invoiceLineList = [
                SELECT Id, Product2.Name, Quantity, CurrencyIsoCode, ChargeAmount, ChargeTaxAmount, ChargeAmountWithTax, Type 
                FROM InvoiceLine 
                WHERE Type = 'Charge' AND InvoiceId = :invoiceId
            ];
            if (invoiceLineList.size() > 0) {
                Integer invoiceLineCount = 0;

                for (InvoiceLine invoiceLine : invoiceLineList) {

                    Decimal itemAmount = Integer.valueOf(invoiceLine.ChargeAmount * AdyenPaymentUtility.getAmountMultiplier(pa.CurrencyIsoCode));
                    Decimal itemVatAmount = Integer.valueOf(invoiceLine.ChargeTaxAmount * AdyenPaymentUtility.getAmountMultiplier(pa.CurrencyIsoCode));
                    Decimal itemVatPercentage = invoiceLine.ChargeAmount / invoiceLine.ChargeTaxAmount;

                    System.debug('---->Inside AdyenPaymentHelper.createCaptureRequest, inside invoiceLine loop, invoiceLine: ' + invoiceLine);
                    invoiceLineCount++;
                    additionalData.put('openinvoicedata.line' + invoiceLineCount + '.currencyCode',          invoiceLine.CurrencyIsoCode);
                    additionalData.put('openinvoicedata.line' + invoiceLineCount + '.description',           invoiceLine.Product2.Name);
                    additionalData.put('openinvoicedata.line' + invoiceLineCount + '.itemAmount',            String.valueOf(itemAmount)); 
                    additionalData.put('openinvoicedata.line' + invoiceLineCount + '.itemVatAmount',         String.valueOf(itemVatAmount));
                    additionalData.put('openinvoicedata.line' + invoiceLineCount + '.itemVatPercentage',     String.valueOf(itemVatPercentage));
                    additionalData.put('openinvoicedata.line' + invoiceLineCount + '.numberOfItems',         String.valueOf(Integer.valueOf(invoiceLine.Quantity)));
                    additionalData.put('openinvoicedata.line' + invoiceLineCount + '.productUrl',            '');
                    additionalData.put('openinvoicedata.line' + invoiceLineCount + '.imageUrl',              '');
                }
                additionalData.put('openinvoicedata.numberOfLines', invoiceLineList.size());
                System.debug('---->Inside AdyenPaymentHelper.createCaptureRequest, Open Invoice additionalData: ' + additionalData);
                requestObj.put('additionalData', additionalData);
            }
            
        }
        requestObj.put('applicationInfo', AdyenPaymentUtility.getApplicationInfo(adyenAdapterMdt.System_Integrator_Name__c));

        return JSON.serialize(requestObj);
    }

    private static commercepayments.GatewayResponse processCaptureResponse(AdyenService.AdyenResponse adyenResponse, commercepayments.CaptureResponse captureResponse, String paymentAuthorizationId, String captureRequestPayload) {

        commercepayments.GatewayErrorResponse gatewayErrorResponse;
        if(adyenResponse!=null && adyenResponse.status != integer.valueOf(AdyenService.HTTP_SERVER_ERROR_CODE)){ // HTTP connection with Adyen was successful
            if(adyenResponse.operationSuccessful){ //Adyen accepted Capture request
                captureResponse.setGatewayReferenceNumber(adyenResponse.pspReference);
                captureResponse.setGatewayDate(System.now());
                captureResponse.setGatewayMessage(adyenResponse.response);
                captureResponse.setGatewayReferenceDetails(adyenResponse.response);
                captureResponse.setGatewayResultCode(adyenResponse.getStatusString());
                captureResponse.setGatewayResultCodeDescription(adyenResponse.response);
                captureResponse.setSalesforceResultCodeInfo(SUCCESS_SALESFORCE_RESULT_CODE_INFO);
                System.debug('---->Exiting AdyenPaymentHelper.processCaptureResponse after successful capture='+captureResponse);
                return captureResponse;
            } else{ //Adyen did not accepted capture request
                captureResponse.setGatewayReferenceNumber(null);
                captureResponse.setGatewayDate(System.now());
                captureResponse.setGatewayMessage(adyenResponse.message);
                captureResponse.setGatewayReferenceDetails(adyenResponse.message);
                captureResponse.setGatewayResultCode(adyenResponse.getStatusString());
                captureResponse.setGatewayResultCodeDescription(adyenResponse.message);
                captureResponse.setSalesforceResultCodeInfo(SYSTEMERROR_SALESFORCE_RESULT_CODE_INFO); 

                return captureResponse;
            }
        } else{ //HTTP connection issue
            captureResponse.setGatewayReferenceNumber(null);
            captureResponse.setGatewayDate(System.now());
            captureResponse.setGatewayMessage(adyenResponse.message);
            captureResponse.setGatewayReferenceDetails(adyenResponse.message);
            captureResponse.setGatewayResultCode(adyenResponse.getStatusString());
            captureResponse.setGatewayResultCodeDescription(adyenResponse.message);
            captureResponse.setSalesforceResultCodeInfo(SYSTEMERROR_SALESFORCE_RESULT_CODE_INFO);
            return captureResponse;
        }
    }


    /**
     * Calls the Service to post a REFUND to Adyen. Evaluates the response wrapped in custom class Adyen and sets appropirate
     * props on commercepayments.ReferenceRefundResponse.
     *
     * @param refundRequest   The commercepayments.ReferencedRefundRequest Object.
     * @return refundResponse  The commercepayments.ReferencedRefundResponse Object.
     *
     * * General flow is AdyenService to post request JSON --> populateReferencedRefundResponse
     *
     * @see AdyenService
     */
    private static commercepayments.GatewayResponse refundFunds(commercepayments.ReferencedRefundRequest refundRequest) {
        
        // Retrieve the Payment object
        Payment payment = AdyenPaymentUtility.retrievePayment( refundRequest.PaymentId);

        // By Default, retrieve the metadata key from the order's sales channel
        String adapterName = payment?.OrderPaymentSummary.OrderSummary.SalesChannel.ADYENSOMPACKAGE__ADYENMERCHANTID__C;

        // Override config for this specific Payment (i.e., a pre-capture) or inherit override from the original PaymentAuthorization
        if (String.isNotBlank(payment?.ADYENSOMPACKAGE__adyenOverrideMerchantConfig__c)) {
            adapterName = payment.ADYENSOMPACKAGE__adyenOverrideMerchantConfig__c;
        }
        if (String.isNotBlank(payment?.PaymentAuthorization?.adyenOverrideMerchantConfig__c)) {
            adapterName = payment.PaymentAuthorization.ADYENSOMPACKAGE__adyenOverrideMerchantConfig__c;
        }
        if (String.isBlank(adapterName)) {
            adapterName = DEFAULT_ADAPTER_NAME;
        }

        Adyen_Adapter__mdt adyenAdapterMdt = AdyenPaymentUtility.retrieveGatewayMetadata(adapterName); 
        String refundEndpoint = adyenAdapterMdt.Refund_Endpoint__c;
        String refundRequestPayload = createRefundRequest( refundRequest, payment, adyenAdapterMdt );

        String cardHolderName;
        if (payment != null && payment.OrderPaymentSummary != null){
            cardHolderName = payment.OrderPaymentSummary.FullName;
        }
        if (cardHolderName == 'NetworkErrorWhileRefund'){
            refundEndpoint = 'qwefqwef';
        }
        
        AdyenService.AdyenResponse adyenResponse = AdyenService.executeAPI(refundRequestPayload, adyenAdapterMdt, refundEndpoint);

        commercepayments.ReferencedRefundResponse refundResponse = new commercepayments.ReferencedRefundResponse();
        refundResponse.setAsync(true);
        refundResponse.setAmount(refundRequest.amount);
        
        commercepayments.GatewayResponse gatewayResponse = processRefundResponse(adyenResponse, refundResponse);

        System.debug('---->Exiting AdyenPaymentHelper.refundFunds =' + gatewayResponse);
        return gatewayResponse;
    }


    /**
     * 
     * @param refundRequest 
     * @returns `String`
     */
    private static String createRefundRequest( commercepayments.ReferencedRefundRequest refundRequest, Payment payment, Adyen_Adapter__mdt adyenAdapterMdt ) {

        Map<String, Object> modificationAmount = new Map<String, Object>();
        String merchantAccount = adyenAdapterMdt.Merchant_Account__c;
        String defaultCurrencyCode = adyenAdapterMdt.Single_Currency_Code__c;

        String cardHolderName ;
        if (payment != null && payment.OrderPaymentSummary != null){
            cardHolderName = payment.OrderPaymentSummary.FullName;
        }

        String currencyCode = payment != null && defaultCurrencyCode == null ? (String)payment.get('CurrencyIsoCode') : defaultCurrencyCode;

        Decimal refundValue = refundRequest.amount != null ? refundRequest.amount : null;
        if (refundValue != null) {
            refundValue = refundValue * AdyenPaymentUtility.getAmountMultiplier(currencyCode);
        }
        //modificationAmount.put('value', refundRequest.amount);
        modificationAmount.put('value',String.valueOf(Integer.valueOf(refundValue)));
        modificationAmount.put('currency', currencyCode);

        Map<String, Object> requestObj = new Map<String, Object>();

        String pspReference = AdyenPaymentUtility.getRefundGatewayRefNumber(payment);

        if(cardHolderName == 'DeclineRefund'){
            requestObj.put('originalReference', 'dummytransaction');
        }
        else{
            requestObj.put('originalReference', pspReference);
        }

        //@see https://docs.adyen.com/api-explorer/#/Payment/v52/post/refund
        requestObj.put('merchantAccount', merchantAccount);
        requestObj.put('modificationAmount', modificationAmount);

        String sJson = JSON.serialize(requestObj);
        return sJson;
    }

    /**
    * @return commercepayments.ReferencedRefundResponse with populated properties.
    */
    private static commercepayments.ReferencedRefundResponse processRefundResponse( AdyenService.AdyenResponse adyenResponse, commercepayments.ReferencedRefundResponse refundResponse) {
        commercepayments.GatewayErrorResponse gatewayErrorResponse;

        if(adyenResponse!=null && adyenResponse.status != integer.valueOf(AdyenService.HTTP_SERVER_ERROR_CODE)){ // HTTP connection with Adyen was successful
            if(adyenResponse.operationSuccessful){ //Adyen accepted refund request
                refundResponse.setGatewayReferenceNumber(adyenResponse.pspReference);
                refundResponse.setGatewayDate(System.now());
                refundResponse.setGatewayMessage(adyenResponse.response);
                refundResponse.setGatewayReferenceDetails(adyenResponse.response);
                refundResponse.setGatewayResultCode(adyenResponse.getStatusString());
                refundResponse.setGatewayResultCodeDescription(adyenResponse.response);
                refundResponse.setSalesforceResultCodeInfo(SUCCESS_SALESFORCE_RESULT_CODE_INFO);
                return refundResponse;
            } else{ //Adyen did not accept refund request
                refundResponse.setGatewayReferenceNumber(null);
                refundResponse.setGatewayDate(System.now());
                refundResponse.setGatewayMessage(adyenResponse.message);
                refundResponse.setGatewayReferenceDetails(adyenResponse.message);
                refundResponse.setGatewayResultCode(adyenResponse.getStatusString());
                refundResponse.setGatewayResultCodeDescription(adyenResponse.message);
                refundResponse.setSalesforceResultCodeInfo(VALIDATIONERROR_SALESFORCE_RESULT_CODE_INFO); 
                System.debug('---->Exiting AdyenPaymentHelper.processRefundResponse after failed refund='+refundResponse);
                return refundResponse;
            }
        } else{ //HTTP connection issue
            refundResponse.setGatewayReferenceNumber(null);
            refundResponse.setGatewayDate(System.now());
            refundResponse.setGatewayMessage(adyenResponse.message);
            refundResponse.setGatewayReferenceDetails(adyenResponse.message);
            refundResponse.setGatewayResultCode(adyenResponse.getStatusString());
            refundResponse.setGatewayResultCodeDescription(adyenResponse.message);
            refundResponse.setSalesforceResultCodeInfo(SYSTEMERROR_SALESFORCE_RESULT_CODE_INFO); 
            System.debug('---->Exiting AdyenPaymentHelper.processRefundResponse after connectivity issue='+refundResponse);
            return refundResponse;
        }
    }


    /**
     * Calls the Service to post AUTHORIZATION REVERSAL to Adyen. Evaluates the response wrapped in custom class Adyen and sets appropirate
     * props on commercepayments.ReferenceRefundResponse.
     *
     * @param refundRequest   The commercepayments.ReferencedRefundRequest Object.
     * @return refundResponse  The commercepayments.ReferencedRefundResponse Object.
     *
     * * General flow is AdyenService to post request JSON --> populateReferencedRefundResponse
     *
     * @see AdyenService
     */
    private static commercepayments.GatewayResponse cancelAuthorization(commercepayments.AuthorizationReversalRequest authReversalRequest) {
        
        // Retrieve the PaymentAuthorization object
        PaymentAuthorization pa = AdyenPaymentUtility.retrievePaymentAuthorization(authReversalRequest.PaymentAuthorizationId);

        // By Default, retrieve the metadata key from the order's sales channel
        String adapterName = pa?.OrderPaymentSummary.OrderSummary.SalesChannel.ADYENSOMPACKAGE__ADYENMERCHANTID__C;

        // Override config for this specific Payment (i.e., a pre-capture) or inherit override from the original PaymentAuthorization
        if (String.isNotBlank(pa?.ADYENSOMPACKAGE__adyenOverrideMerchantConfig__c)) {
            adapterName = pa.ADYENSOMPACKAGE__adyenOverrideMerchantConfig__c;
        }
        if (String.isBlank(adapterName)) {
            adapterName = DEFAULT_ADAPTER_NAME;
        }

        //Adyen_Adapter__mdt adyenAdapterMdt = AdyenPaymentUtility.retrieveGatewayMetadata(adapterName); 
        //String cancelRequestPayload = createCancelRequest(authReversalRequest, pa, adyenAdapterMdt);

        //String cancelEndpoint = '/cancel';    // @todo
        //if (pa?.OrderPaymentSummary?.FullName == 'NetworkErrorWhileRefund'){
        //    cancelEndpoint = 'qwefqwef';
        //}
        
        //AdyenService.AdyenResponse adyenResponse = AdyenService.executeAPI(cancelRequestPayload, adyenAdapterMdt, cancelEndpoint);

        //commercepayments.AuthorizationReversalResponse authReversalResponse = new commercepayments.AuthorizationReversalResponse();
        //authReversalResponse.setAsync(true);  @todo - not supported yet
        
        //commercepayments.GatewayResponse gatewayResponse = processCancelResponse(adyenResponse, authReversalResponse);

        //System.debug('---->Exiting AdyenPaymentHelper.refundFunds =' + gatewayResponse);
        //return gatewayResponse;
        return null;
    }

    public static commercepayments.GatewayNotificationResponse handleAsyncNotificationCallback(
        commercepayments.PaymentGatewayNotificationContext gatewayNotificationContext,
            String apexName
        ) {
        System.debug('---->Entering AdyenPaymentHelper.handleAsyncNotificationCallback PaymentGatewayNotificationContext='+gatewayNotificationContext);
        commercepayments.PaymentGatewayNotificationRequest paymentGatewayNotificationRequest = gatewayNotificationContext.getPaymentGatewayNotificationRequest();
        commercepayments.GatewayNotificationResponse gatewayNotificationResponse = new commercepayments.GatewayNotificationResponse();

        commercepayments.NotificationSaveResult notificationSaveResult;
        AdyenService.NotificationRequestItem notificationRequestItem;

        notificationRequestItem = parseAdyenNotificationRequest( paymentGatewayNotificationRequest );

        String apexAdapterId = AdyenPaymentUtility.retrieveApexAdapterId(notificationRequestItem.originalReference);
        System.debug('---->apexAdapterId ='+apexAdapterId);

        String nameSpacePrefix = '';
        List<ApexClass> adyenApexClass = [SELECT NamespacePrefix from ApexClass WHERE Name = :apexName];
        if (adyenApexClass.size() > 0) {
            nameSpacePrefix = adyenApexClass[0].NamespacePrefix;
        }
        String apexClassId = AdyenPaymentUtility.retrieveApexClassId(apexName, nameSpacePrefix);
        System.debug('---->apexClassId ='+apexClassId);
        
        if(apexAdapterId == apexClassId || Test.isRunningTest()){
        
        notificationSaveResult = createNotificationSaveResult( notificationRequestItem );
        
        if (notificationSaveResult != null){
            if(notificationSaveResult.isSuccess()){ // Notification is accepted by the platform
                gatewayNotificationResponse.setStatusCode(AdyenService.HTTP_SUCCESS_CODE);
                gatewayNotificationResponse.setResponseBody(Blob.valueOf( NOTIFICATION_ACCEPTED_RESPONSE ));
                    System.debug('---->Exiting AdyenPaymentHelper.handleAsyncNotificationCallback after the notification is accepted=' + gatewayNotificationResponse);
                return gatewayNotificationResponse;
                } else { // Notification is not accepted by the platform, generate system event
                gatewayNotificationResponse.setStatusCode(integer.valueOf(AdyenService.HTTP_SERVER_ERROR_CODE));
                String msg = '[accepted] ';
                if (notificationSaveResult != null && notificationSaveResult.getErrorMessage() != null) {
                    msg += notificationSaveResult.getErrorMessage();
                }
                gatewayNotificationResponse.setResponseBody(Blob.valueOf(msg));
                return gatewayNotificationResponse;
            }
                } else{
                String msg = '';
                msg += '[accepted] But unsupported notification type = '+notificationRequestItem.eventCode;
                    gatewayNotificationResponse.setResponseBody(Blob.valueOf( msg ));
                    gatewayNotificationResponse.setStatusCode(AdyenService.HTTP_SUCCESS_CODE);
                return gatewayNotificationResponse;
            }

        } else {
            String msg = '';
            msg += '[accepted] But not processed - wrong payment adapter or wrong instance';
                gatewayNotificationResponse.setResponseBody(Blob.valueOf( msg ));
                gatewayNotificationResponse.setStatusCode(AdyenService.HTTP_SUCCESS_CODE);
            System.debug('---->Exiting AdyenPaymentHelper.handleAsyncNotificationCallback after identifying that it was the wrong payment adapter='+gatewayNotificationResponse);
            return gatewayNotificationResponse;
        }
    }

    /**
     * Take the http request from the async notification callback and deserializes it into AdyenNotificationResponse.
     *
     * @param adyenNotificationRequestPayload   The body of the Adyen notification request.
    * @return AdyenService.AdyenNotificationRequest         The deserialized version of the Adyen nodification request.
    *
    * @see https://docs.adyen.com/development-resources/webhooks/understand-notifications
    */
    public static AdyenService.NotificationRequestItem parseAdyenNotificationRequest(commercepayments.PaymentGatewayNotificationRequest notificationRequest) {
        String adyenNotificationRequestPayload = notificationRequest.getRequestBody().toString();
        adyenNotificationRequestPayload = adyenNotificationRequestPayload.replace('currency', APEX_RESERVED_CURRENCY_FIELD); //  necessary because currency is an apex reserved word.
        
        AdyenService.AdyenNotification adyenNotification  = (AdyenService.AdyenNotification) JSON.deserialize(adyenNotificationRequestPayload, AdyenService.AdyenNotification.class);
        AdyenService.NotificationRequestItem notificationRequestItem = new AdyenService.NotificationRequestItem();
        if(adyenNotification != null) {
            for(AdyenService.NotificationItems notificationItem : adyenNotification.notificationItems) {
                if(notificationItem.NotificationRequestItem != null) {
                    notificationRequestItem = notificationItem.NotificationRequestItem;
                }
            }
        }
        return notificationRequestItem;
    }


    /**
    * Creates and records (ie saves) the notificationsaveresult.
    *
    * @param adyenNotificationResponse
    * @return commercepayments.NotificationSaveResult.
    */
    private static commercepayments.NotificationSaveResult createNotificationSaveResult( AdyenService.NotificationRequestItem notificationRequestItem ) {

        Boolean unsupportedNotificationType = false;
        commercepayments.BaseNotification notification = null;
        commercepayments.NotificationStatus notificationStatus = null;
        commercepayments.SalesforceResultCode notificationStatusSF = null;

        if (!Boolean.valueOf(notificationRequestItem.success)){
            notificationStatus = commercepayments.NotificationStatus.Failed;
            notificationStatusSF = commercepayments.SalesforceResultCode.Decline; 
        } else {
            notificationStatus = commercepayments.NotificationStatus.Success;
            notificationStatusSF = commercepayments.SalesforceResultCode.Success; 
        }
        if (NOTIFICATION_REQUEST_TYPE_CAPTURE.equalsIgnoreCase(notificationRequestItem.eventCode)) {
            notification = new commercepayments.CaptureNotification();
        } else if ( NOTIFICATION_REQUEST_TYPE_REFUND.equalsIgnoreCase(notificationRequestItem.eventCode)) {
            notification = new commercepayments.ReferencedRefundNotification();
        } else {
            if (NOTIFICATION_REQUEST_TYPE_CAPTURE_FAILED.equalsIgnoreCase(notificationRequestItem.eventCode))
            {
                // process exception caught via platform event subscriber
            }
            unsupportedNotificationType = true;
        }

        commercepayments.NotificationSaveResult notificationSaveResult;
        if(!unsupportedNotificationType) {
            notification.setStatus(notificationStatus);
            notification.setSalesforceResultCodeInfo(new commercepayments.SalesforceResultCodeInfo(notificationStatusSF));
            notification.setGatewayReferenceNumber(notificationRequestItem.pspReference);
            notification.setGatewayResultCode(notificationRequestItem.eventCode);
            notification.setGatewayResultCodeDescription(notificationRequestItem.reason);
            if(String.isBlank(notificationRequestItem.reason) && notificationStatus == commercepayments.NotificationStatus.Success) {
                if ( NOTIFICATION_REQUEST_TYPE_CAPTURE.equalsIgnoreCase(notificationRequestItem.eventCode)) {
                    notification.setGatewayMessage('[capture-complete]');
                } else if ( NOTIFICATION_REQUEST_TYPE_REFUND.equalsIgnoreCase(notificationRequestItem.eventCode)) {
                    notification.setGatewayMessage('[refund-complete]');
                } else if ( NOTIFICATION_REQUEST_TYPE_CANCEL.equalsIgnoreCase(notificationRequestItem.eventCode)) {
                    notification.setGatewayMessage('[cancel-complete]');
                }
            }else{
                notification.setGatewayMessage(notificationRequestItem.reason);
            }
                
            //notification.setGatewayDate(System.now());

            Decimal value;
            if(notificationRequestItem.amount != null) {
                value = notificationRequestItem.amount.value;
            }
            value = value / AdyenPaymentUtility.getAmountMultiplier(notificationRequestItem.amount.currency_x);
            
            Double dValue = value;
            notification.setAmount(dValue);
            notificationSaveResult = commercepayments.NotificationClient.record(notification);
            return notificationSaveResult;
        } else {
            notificationSaveResult = null;
            System.debug('---> Exiting AdyenPaymentHelper.createNotificationSaveResult after ignoring unsupported notification='+notificationRequestItem.eventCode);
            return notificationSaveResult;
        }
    }
}