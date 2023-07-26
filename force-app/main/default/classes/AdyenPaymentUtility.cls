public with sharing class AdyenPaymentUtility {
    
    @TestVisible
    private static final String TEST_ENDPOINT = 'https://test.com';
    public static final String MERCHANT_API_KEY = '{!$Credential.Password}';
    public static Boolean skipMerchantAccount = false;
    
    /**
    * Looks for the Gateway ref number on the Payment record passed in. If not found gets its from
    * the LastPaymentGateway log on the OrderPaymentSummary record.
    *
    * @param payment the Payment sObject.
    * @return the GatewayRefNumber for the request.
    */
    public static String getRefundGatewayRefNumber(Payment payment) {
        if (payment == null) {
            throw new AdyenAsyncAdapter.GatewayException('Payment Info Missing');
        }
        return payment.PaymentAuthorization?.GatewayRefNumber != null ? payment.PaymentAuthorization.GatewayRefNumber : payment.GatewayRefNumber;
    }
    
    /**
    * Retrieve Payment Info.
    *
    * @param paymentId The Payment.Id value
    * @return a Payment sObject.
    */
    public static Payment retrievePayment(Id paymentId) {
        Payment payment;
        
        if ( Test.isRunningTest() || (
        Schema.SObjectType.Payment.fields.Id.isAccessible() &&
        Schema.SObjectType.Payment.fields.GatewayRefNumber.isAccessible() &&
        Schema.SObjectType.Payment.fields.GatewayRefDetails.isAccessible() &&
        Schema.SObjectType.Payment.fields.adyenOverrideMerchantConfig__c.isAccessible() &&
        Schema.SObjectType.PaymentAuthorization.fields.GatewayRefNumber.isAccessible() &&
        Schema.SObjectType.PaymentAuthorization.fields.adyenOverrideMerchantConfig__c.isAccessible() &&
        Schema.SObjectType.PaymentAuthorization.fields.Adyen_Payment_Method_Variant__c.isAccessible() &&
        Schema.SObjectType.PaymentAuthorization.fields.Adyen_Payment_Method__c.isAccessible() &&
        Schema.SObjectType.Payment.fields.CurrencyIsoCode.isAccessible() &&
        Schema.SObjectType.OrderPaymentSummary.fields.FullName.isAccessible() &&
        Schema.SObjectType.SalesChannel.fields.AdyenMerchantID__c.isAccessible()
        ) ) {
            List<Payment> payments = [
            SELECT
                Id, GatewayRefNumber, GatewayRefDetails,
                PaymentAuthorization.GatewayRefNumber, PaymentAuthorization.Adyen_Payment_Method_Variant__c,
                PaymentAuthorization.Adyen_Payment_Method__c, adyenOverrideMerchantConfig__c,
                PaymentAuthorization.adyenOverrideMerchantConfig__c,CurrencyIsoCode,
                OrderPaymentSummary.FullName, OrderPaymentSummary.OrderSummary.SalesChannel.AdyenMerchantID__c
            FROM
                Payment
            WHERE
                Id = :paymentId
            ];
            
            if (!payments.isEmpty()) {
                payment = payments[0];
            }
            
        }
        return payment;
    }
    
    
    /**
    *  Retrieves custom meta data associated with Adyen (Endpoint info) pulls all fields.
    *
    *  @return Adyen_Adapter__mdt for the passed metadata type with all fields.
    */
    public static Adyen_Adapter__mdt retrieveGatewayMetadata(String metaType) {
        if (Test.isRunningTest()) {
            return new Adyen_Adapter__mdt(
                MasterLabel = 'AdyenDefault',
                Single_Currency_Code__c = 'USD',
                System_Integrator_Name__c = 'Test integrator',
                Endpoint_Method__c = 'POST',
                Authorize_Endpoint__c = '/payments',
                Refund_Endpoint__c = '/{paymentPspReference}/refund',
                Capture_Endpoint__c = '/{paymentPspReference}/capture',
                Endpoint_Api_Version__c = '/v1',
                Merchant_Account__c = skipMerchantAccount ? '' : 'TEST_MERCHANT_ACCOUNT'
            );
        } else {
            Adyen_Adapter__mdt adyenAdapterMdt;
            if (
                Schema.SObjectType.Adyen_Adapter__mdt.fields.Developername.isAccessible() && Schema.SObjectType.Adyen_Adapter__mdt.fields.NamespacePrefix.isAccessible() &&
                Schema.SObjectType.Adyen_Adapter__mdt.fields.MasterLabel.isAccessible() && Schema.SObjectType.Adyen_Adapter__mdt.fields.Capture_Endpoint__c.isAccessible() &&
                Schema.SObjectType.Adyen_Adapter__mdt.fields.Endpoint_Api_Version__c.isAccessible() && Schema.SObjectType.Adyen_Adapter__mdt.fields.Endpoint_Method__c.isAccessible() &&
                Schema.SObjectType.Adyen_Adapter__mdt.fields.Endpoint_Path__c.isAccessible() && Schema.SObjectType.Adyen_Adapter__mdt.fields.Merchant_Account__c.isAccessible() &&
                Schema.SObjectType.Adyen_Adapter__mdt.fields.System_Integrator_Name__c.isAccessible() && Schema.SObjectType.Adyen_Adapter__mdt.fields.Refund_Endpoint__c.isAccessible() &&
                Schema.SObjectType.Adyen_Adapter__mdt.fields.Single_Currency_Code__c.isAccessible() && Schema.SObjectType.Adyen_Adapter__mdt.fields.Service_Username__c.isAccessible() &&
                Schema.SObjectType.Adyen_Adapter__mdt.fields.Service_Password__c.isAccessible() && Schema.SObjectType.Adyen_Adapter__mdt.fields.Authorize_Endpoint__c.isAccessible()
            ) {
                adyenAdapterMdt = [
                    SELECT
                        DeveloperName, NamespacePrefix, MasterLabel, Capture_Endpoint__c, Endpoint_Api_Version__c,
                        System_Integrator_Name__c, Endpoint_Method__c, Endpoint_Path__c, Merchant_Account__c,
                        Refund_Endpoint__c, Single_Currency_Code__c, Service_Username__c, Service_Password__c, Authorize_Endpoint__c
                    FROM
                        Adyen_Adapter__mdt
                    WHERE
                        DeveloperName = :metaType
                ];
            }
            return adyenAdapterMdt;
        }
    }
    
    
    /**
    * Retrieve PaymentAuthorizations Info.
    *
    * @param paymentAuthId The sObject PaymentAuthorizationId
    * @return a PaymentAuthorization sObject.
    */
    public static PaymentAuthorization retrievePaymentAuthorization(Id paymentAuthId) {
        PaymentAuthorization pa;
        
        if ( Test.isRunningTest() || (
        Schema.SObjectType.PaymentAuthorization.fields.Id.isAccessible() &&
        Schema.SObjectType.PaymentAuthorization.fields.PaymentAuthorizationNumber.isAccessible() &&
        Schema.SObjectType.PaymentAuthorization.fields.GatewayRefNumber.isAccessible() &&
        Schema.SObjectType.PaymentAuthorization.fields.CurrencyIsoCode.isAccessible() &&
        Schema.SObjectType.PaymentAuthorization.fields.adyenOverrideMerchantConfig__c.isAccessible() &&
        Schema.SObjectType.PaymentAuthorization.fields.Adyen_Payment_Method__c.isAccessible() &&
        Schema.SObjectType.PaymentGatewayLog.fields.GatewayRefNumber.isAccessible() &&
        Schema.SObjectType.OrderPaymentSummary.fields.Id.isAccessible() &&
        Schema.SObjectType.OrderPaymentSummary.fields.FullName.isAccessible() &&
        Schema.SObjectType.SalesChannel.fields.AdyenMerchantID__c.isAccessible()) )
        {
            List<PaymentAuthorization> paymentAuthorizations = [
                SELECT
                    Id, PaymentAuthorizationNumber, GatewayRefNumber, adyenOverrideMerchantConfig__c, Adyen_Payment_Method__c,
                    OrderPaymentSummary.LastPaymentGatewayLog.GatewayRefNumber,
                    OrderPaymentSummary.Id,
                    OrderPaymentSummary.FullName, CurrencyIsoCode,
                    OrderPaymentSummary.OrderSummary.Id,
                    OrderPaymentSummary.OrderSummary.SalesChannel.AdyenMerchantID__c
                FROM
                    PaymentAuthorization
                WHERE
                    Id = :paymentAuthId
                ORDER BY
                    CreatedDate DESC
            ];
            if(!paymentAuthorizations.isEmpty()) {
                pa = paymentAuthorizations[0];
                System.debug(LoggingLevel.INFO, 'SalesChannel Config: ' + pa.OrderPaymentSummary.OrderSummary.SalesChannel.AdyenMerchantID__c);
            }
        }
        return pa;
    }
    
    /**
    * Check if Klarna Order.
    *
    * @param pa The sObject PaymentAuthorizationId
    * @return Boolean denoting if the Authorization Id belongs to a Klarna Order.
    */
    public static Boolean checkIfKlarnaOrderFromAuthorization(PaymentAuthorization pa) {
        Boolean isKlarnaOrder = false;
        
        if (pa != null && pa.Adyen_Payment_Method__c != null) {
            isKlarnaOrder = pa.Adyen_Payment_Method__c.containsIgnoreCase('klarna');
        }

        return isKlarnaOrder;
    }
    
    /**
    * Retrieve apex adapter id from the gateway reference number.
    *
    * @param gatewayRefNumber original payment gatewayrefnumber as recieved in the notification
    * @return apexclass id for the payment gateway adapter.
    */
    public static String retrieveApexAdapterId(String gatewayRefNumber) {
        String apexAdapterId = null;
        
        // Prioritize the payment authorization record if it exists
        for (PaymentAuthorization paymentAuthorization : [
            SELECT PaymentGateway.PaymentGatewayProvider.ApexAdapter.Id
            FROM PaymentAuthorization
            WHERE GatewayRefNumber = :gatewayRefNumber
        ]) {
            if (paymentAuthorization.PaymentGateway.PaymentGatewayProvider.ApexAdapter!=null) {
                apexAdapterId = paymentAuthorization.PaymentGateway.PaymentGatewayProvider.ApexAdapter.Id;
            }
        }
        
        // Fall back to a payment record for pre-captured transactions
        if (apexAdapterId==null) {
            for (Payment payment : [
            SELECT PaymentGateway.PaymentGatewayProvider.ApexAdapter.Id
            FROM Payment
            WHERE GatewayRefNumber = :gatewayRefNumber
            ]) {
                if (payment.PaymentGateway.PaymentGatewayProvider.ApexAdapter!=null) {
                    apexAdapterId = payment.PaymentGateway.PaymentGatewayProvider.ApexAdapter.Id;
                }
            }
        }
        
        return apexAdapterId;
    }
    
    public static Integer getAmountMultiplier(String currencyCode) {
        if (AdyenOMSConstants.threeDecimalCurrencies.contains(currencyCode)) {
            return 1000;
        } else if (AdyenOMSConstants.zeroDecimalCurrencies.contains(currencyCode)) {
            return 1;
        } else {
            return 100;
        }
    }
    
    /**
    * Looks for the Gateway ref number on the PaymentAuthorization record passed in. If not found gets its from
    * the LastPaymentGateway log on the OrderPaymentSummary record.
    *
    * @param pa  The PaymentAuthorization sObject
    * @return the GatewayRefNumber for the request.
    * @see https://ca-test.adyen.com/ca/ca/accounts/showTx.shtml?pspReference=852588546520527A&txType=Payment
    */
    public static String getCaptureGatewayRefNumber(PaymentAuthorization pa) {
        if (pa == null) {
            throw new AdyenAsyncAdapter.GatewayException('Payment Authorization Missing');
        }
        return pa.GatewayRefNumber != null ? pa.GatewayRefNumber : pa.OrderPaymentSummary?.LastPaymentGatewayLog?.GatewayRefNumber;
    }
    
    public static List<LineItem> addInvoiceData(Id invoiceId) {
        List<InvoiceLine> invoiceLines = [
            SELECT Id, Product2.Name, Quantity, CurrencyIsoCode, ChargeAmount, ChargeTaxAmount, ChargeAmountWithTax, Type
            FROM InvoiceLine
            WHERE Type = 'Charge' AND InvoiceId = :invoiceId
        ];
        return parseLineItemsData(invoiceLines);
    }

    public static List<LineItem> addCreditMemoData(Id orderSummaryId) {
        List<CreditMemoLine> creditMemoLines = [
            SELECT Product2.Name, CurrencyIsoCode, ChargeAmount, ChargeTaxAmount, ChargeAmountWithTax
            FROM CreditMemoLine
            WHERE Type = 'Charge' AND CreditMemo.ReferenceEntityId = :orderSummaryId
        ];
        return parseLineItemsData(creditMemoLines);
    }

    private static List<LineItem> parseLineItemsData(List<SObject> lineItemRecords) {
        List<LineItem> lineItems = new List<LineItem>();
        LineItem lineItem;
        for (SObject lineItemRecord : lineItemRecords) {
            String currencyIsoCode = (String)lineItemRecord.get('CurrencyIsoCode');
            Decimal amountExcludingTax = (Decimal)lineItemRecord.get('ChargeAmount');
            Decimal amountIncludingTax = (Decimal)lineItemRecord.get('ChargeAmountWithTax');
            Decimal taxAmount = (Decimal)lineItemRecord.get('ChargeTaxAmount');
            lineItem = new LineItem();
            lineItem.amountExcludingTax = Integer.valueOf(amountExcludingTax * getAmountMultiplier(currencyIsoCode));
            lineItem.amountIncludingTax = Integer.valueOf(amountIncludingTax * getAmountMultiplier(currencyIsoCode));
            lineItem.taxAmount = Integer.valueOf(taxAmount * getAmountMultiplier(currencyIsoCode));
            lineItem.taxPercentage = amountExcludingTax != 0 ?
                Integer.valueOf((taxAmount/amountExcludingTax).setScale(4, RoundingMode.HALF_EVEN) * 10000) :
                0;
            lineItem.description = ((Product2)lineItemRecord.getSObject('Product2')).Name;
            if (lineItemRecord.getSObjectType() == Schema.InvoiceLine.getSObjectType()) { // credit memo line does not have quantity
                lineItem.quantity = Integer.valueOf((Decimal)lineItemRecord.get('Quantity'));
            }
            lineItems.add(lineItem);
        }
        return lineItems;
    }
    
    /**
    * Convert a request body from the adyen apex library into an api consumable json string
    * (strips the '_x' from attributes that would otherwise be Apex reserved keywords)
    *
    * @param input - the json string containing a *_x key
    * @return output - the same json string with the _x removed
    */
    public static String makeAdyenCompatible(String input) {
        Map<String, String> mapKeyToReplace = new Map<String, String> {
            'currency_x' => 'currency',
            'number_x' => 'number',
            'group_x' => 'group'
        };
        String output = input;
        for (String key : mapKeyToReplace.keySet()) {
            output = output.replace(key, mapKeyToReplace.get(key));
        }
        return output;
    }
    
    /**
    * Convert a response from adyen into an Adyen apex library friendly object
    * (adds the '_x' back into attributes that are apex keywords)
    *
    * @param input - the json string missing the *_x from its keys
    * @return output - the same json string with *_x added back in
    */
    public static String makeSalesforceCompatible(String input) {
        String output = input;
        Map<String, String> mapKeyToReplace = new Map<String, String>{
            'recurring.recurringDetailReference' => 'recurring_recurringDetailReference',
            'currency' => 'currency_x',
            'number' => 'number_x',
            'group' => 'group_x'
        };
        for (String key : mapKeyToReplace.keySet()) {
            output = output.replace(key, mapKeyToReplace.get(key));
        }
        return output;
    }
    
    /**
    * For generating payment tokens
    *
    * @param stringLength integer containing the number of characters
    * @return a random number with stringLength characters
    */
    public static String getRandomNumber(Integer stringLength) {
        final Integer MAX = Integer.valueOf(Math.pow(10, stringLength) - 1);
        return String.valueOf(Math.round(Math.random() * MAX)).leftPad(stringLength, '0');
    }

    public static FulfillmentOrder getFulfillmentOrder(Id orderSummaryId) {
        FulfillmentOrder fulfillmentOrder;
        try {
            fulfillmentOrder = [
                SELECT FulfillmentOrderNumber, Status, StatusCategory, Type, TypeCategory
                FROM FulfillmentOrder
                WHERE OrderSummaryId = :orderSummaryId
            ];
        } catch (Exception ex) {
            logException(ex, LoggingLevel.ERROR);
        }
        return fulfillmentOrder;
    }

    public static String getReference(SObject anyPaymentTypeRecord) {
        Id orderSummaryId = ((OrderPaymentSummary)anyPaymentTypeRecord.getSObject('OrderPaymentSummary')).OrderSummaryId;
        String reference = getFulfillmentOrder(orderSummaryId)?.FulfillmentOrderNumber;
        return String.isNotBlank(reference) ? reference : getRandomNumber(16);
    }

    public static void logException(Exception ex, LoggingLevel loggingLevel) {
        System.debug(loggingLevel, 'Exception message : ' + ex.getMessage());
        System.debug(loggingLevel, 'Exception type : ' + ex.getTypeName());
        System.debug(loggingLevel, 'Exception line : ' + ex.getLineNumber());
        System.debug(loggingLevel, 'Stacktrace : ' + ex.getStackTraceString());
    }
    
    /**
    * Round an amount to a normalized value for consistency
    *
    * @param amount the decimal amount type to be normalized
    * @return the same amount with 2 decimal points using half even rounding mode
    */
    public static Double normalizeAmount(Double amount) {
        return Double.valueOf(Decimal.valueOf(amount).setScale(2, System.RoundingMode.HALF_EVEN));
    }
    
    /**
    * Add application information to the webservice request
    *
    * @return application information map for the request.
    */
    public static ApplicationInfo getApplicationInfo(String integratorName) {
        
        ApplicationInfo info = new ApplicationInfo();
        
        ExternalPlatform exPlatform = new ExternalPlatform();
        exPlatform.name = AdyenOMSConstants.EXTERNAL_PLATFORM_NAME_FOR_APPINFO;
        exPlatform.integrator = integratorName;
        info.externalPlatform = exPlatform;
        
        CommonField merchantApplication = new CommonField();
        merchantApplication.name = AdyenOMSConstants.MERCHANT_APP_NAME_FOR_APPINFO;
        merchantApplication.version = AdyenOMSConstants.MERCHANT_APP_VERSION_FOR_APPINFO;
        info.merchantApplication = merchantApplication;
        
        CommonField adyenLibrary = new CommonField();
        adyenLibrary.name = AdyenOMSConstants.ADYEN_LIBRARY_NAME_FOR_APPINFO;
        adyenLibrary.version = AdyenOMSConstants.ADYEN_LIBRARY_VERSION_FOR_APPINFO;
        info.adyenLibrary = adyenLibrary;
        
        return info;
    }
    
    /**
    * Create a modification request by populating required properties (capture/refund)
    *
    * @return CheckoutModificationRequest to send to Adyen.
    */
    public static CheckoutModificationRequest createModificationRequest(CommercePayments.RequestType paymentType, String currencyCode, Double amount, String merchantAccount, String reference) {
        CheckoutModificationRequest modRequest;
        if (paymentType == CommercePayments.RequestType.Capture) {
            modRequest = new CheckoutCaptureRequest();
        } else if (paymentType == CommercePayments.RequestType.ReferencedRefund) {
            modRequest = new CheckoutRefundRequest();
        }
        modRequest.setReference(reference);
        modRequest.setMerchantAccount(merchantAccount);
        Amount requestAmount = new Amount();
        requestAmount.value = (amount * AdyenPaymentUtility.getAmountMultiplier(currencyCode)).longValue();
        requestAmount.currency_x = currencyCode;
        modRequest.setAmount(requestAmount);
        return modRequest;
    }
    
    /**
    * Send modification request (payment/refund) to Adyen platform
    *
    * @return response from adyen platform.
    */
    public static HttpResponse sendModificationRequest(CheckoutModificationRequest modRequest, Adyen_Adapter__mdt adyenAdapterMdt, String endpoint) {
        String body = AdyenPaymentUtility.makeAdyenCompatible(JSON.serialize(modRequest, true));
        String apiKey = MERCHANT_API_KEY;
        endpoint = Test.isRunningTest() ? TEST_ENDPOINT + endpoint : adyenAdapterMdt.Endpoint_Path__c + adyenAdapterMdt.Endpoint_Api_Version__c + endpoint;
        AdyenClient client = new AdyenClient(apiKey, endpoint);
        HttpResponse response = client.request(client.config, body);
        return response;
    }
    
    /**
    * Create an AUTH request by populating required properties
    *
    * @return AuthorisationRequest to send to Adyen.
    */
    public static AuthorisationRequest createAuthorisationRequest(CommercePayments.AuthorizationRequest authRequest, Adyen_Adapter__mdt adyenAdapterMdt){
        
        AuthorisationRequest adyenAuthorisationRequest = new AuthorisationRequest();
        try{
            CommercePayments.AuthApiPaymentMethodRequest paymentMethod = authRequest.paymentMethod;
            String currencyCode = authRequest.currencyIsoCode.toUpperCase();
            
            Double authAmount = AdyenPaymentUtility.normalizeAmount(authRequest.amount);
            adyenAuthorisationRequest.amount = new Amount();
            adyenAuthorisationRequest.amount.currency_x = currencyCode;
            adyenAuthorisationRequest.amount.value = (authAmount * AdyenPaymentUtility.getAmountMultiplier(currencyCode)).longValue();
            
            //Use existing token to create auth request
            if(paymentMethod.id != null){
                //paymentMethod.id would be a string that represents the Salesforce record id of CardPaymentMethod or AlternativePaymentMethod object
                String adyenToken;
                Id recordId = paymentMethod.id;
                String sObjName = recordId.getSobjectType().getDescribe().getName(); //determine object name
                
                if(sObjName == AdyenOMSConstants.CARD_PAYMENTMETHOD_OBJECT) {
                    //for CardPaymentMethod : Use GatewayTokenEncrypted field to retrieve token
                    CardPaymentMethod cpmRecord = [SELECT Id, GatewayTokenEncrypted FROM CardPaymentMethod WHERE Id = :recordId LIMIT 1];
                    adyenToken = cpmRecord.GatewayTokenEncrypted;
                } else if(sObjName == AdyenOMSConstants.ALTERNATIVE_PAYMENTMETHOD_OBJECT) {
                    //for AlternativePaymentMethod : Use GatewayToken field to retrieve token
                    AlternativePaymentMethod apmRecord = [SELECT Id, GatewayToken FROM AlternativePaymentMethod WHERE Id = :recordId LIMIT 1];
                    adyenToken = apmRecord.GatewayToken;
                }
                
                CardDetails cardDetails = new CardDetails();
                cardDetails.storedPaymentMethodId = adyenToken;
                adyenAuthorisationRequest.paymentMethod = cardDetails;
                adyenAuthorisationRequest.shopperInteraction = AuthorisationRequest.ShopperInteractionEnum.ContAuth;
                adyenAuthorisationRequest.recurringProcessingModel = AuthorisationRequest.RecurringProcessingModelEnum.CardOnFile;
                
            } else if(paymentMethod.cardPaymentMethod != null) {
                //use new card details to create auth request
                CommercePayments.CardPaymentMethodRequest cpmRequest = paymentMethod.cardPaymentMethod;
                CardDetails cardDetails = new CardDetails();
                cardDetails.number_x = cpmRequest.cardNumber;
                cardDetails.expiryMonth = String.valueOf(cpmRequest.expiryMonth);
                cardDetails.expiryYear = String.valueOf(cpmRequest.expiryYear);
                cardDetails.holderName = cpmRequest.cardHolderName;
                cardDetails.cvc = cpmRequest.cvv;
                adyenAuthorisationRequest.paymentMethod = cardDetails;
                adyenAuthorisationRequest.shopperInteraction = AuthorisationRequest.ShopperInteractionEnum.Ecommerce;
            }
            
            adyenAuthorisationRequest.reference = AdyenPaymentUtility.getRandomNumber(16);
            adyenAuthorisationRequest.merchantAccount = adyenAdapterMdt.Merchant_Account__c;
            adyenAuthorisationRequest.shopperReference = UserInfo.getUserId();
            adyenAuthorisationRequest.applicationInfo = AdyenPaymentUtility.getApplicationInfo(adyenAdapterMdt.System_Integrator_Name__c);
        } catch(Exception ex) {
            logException(ex, LoggingLevel.ERROR);
        }
        return adyenAuthorisationRequest;
    }
    
    /**
    * Send authorisation request to Adyen platform
    *
    * @return response from adyen platform.
    */
    public static HttpResponse sendAuthorisationRequest(AuthorisationRequest authRequest, Adyen_Adapter__mdt adyenAdapterMdt){
        HttpResponse response;
        String endpoint;
        try{
            String body = AdyenPaymentUtility.makeAdyenCompatible(JSON.serialize(authRequest, true));
            String apiKey = MERCHANT_API_KEY;
            endpoint = Test.isRunningTest() ? TEST_ENDPOINT + adyenAdapterMdt.Authorize_Endpoint__c : adyenAdapterMdt.Endpoint_Path__c + adyenAdapterMdt.Endpoint_Api_Version__c + adyenAdapterMdt.Authorize_Endpoint__c;
            AdyenClient client = new AdyenClient(apiKey, endpoint);
            response = client.request(client.config, body);
        } catch(Exception ex) {
            logException(ex, LoggingLevel.ERROR);
        }
        return response;
    }
    
}