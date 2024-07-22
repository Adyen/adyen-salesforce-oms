public with sharing class AdyenPaymentUtility {
    @TestVisible
    private static final String NO_PAYMENT_FOUND_BY_ID = 'No Payment found with this id: ';
    @TestVisible
    private static final String NO_PAYMENT_AUTH_FOUND_BY_ID = 'No payment authorization found with this id: ';
    @TestVisible
    private static final String NO_ADYEN_ADAPTER_BY_NAME = 'No Adyen adapter found with this name: ';
    @TestVisible
    private static final String NO_ADYEN_ADAPTER_BY_MERCHANT = 'No Adyen adapter found for this merchant account: ';
    
    /**
    * Retrieve Payment Info.
    *
    * @param paymentId The Payment.Id value
    * @return a Payment sObject.
    */
    public static Payment retrievePayment(Id paymentId) {
        List<Payment> payments = [
            SELECT
                Id, GatewayRefNumber, GatewayRefDetails,
                PaymentAuthorization.GatewayRefNumber, PaymentAuthorization.Adyen_Payment_Method_Variant__c,
                PaymentAuthorization.Adyen_Payment_Method__c,CurrencyIsoCode, OrderPaymentSummary.FullName,
                OrderPaymentSummary.OrderSummary.SalesChannel.AdyenMerchantID__c
            FROM
                Payment
            WHERE
                Id = :paymentId
        ];
        if (payments.isEmpty()) {
            throw new AdyenAsyncAdapter.GatewayException(NO_PAYMENT_FOUND_BY_ID + paymentId);
        }
        return payments[0];
    }
    
    
    /**
    *  Retrieves custom meta data associated with Adyen (Endpoint info) pulls all fields.
    *  @param developerName name of the custom metadata type with Adyen configuration
    *  @return Adyen_Adapter__mdt for the passed metadata type with all fields.
    */
    public static Adyen_Adapter__mdt retrieveGatewayMetadata(String developerName) {
        List<Adyen_Adapter__mdt> adyenAdapters = [
            SELECT
                DeveloperName, MasterLabel, Capture_Endpoint__c, Endpoint_Api_Version__c,
                System_Integrator_Name__c, Endpoint_Path__c, Merchant_Account__c, Refund_Endpoint__c,
                Authorize_Endpoint__c, HMAC_Key__c
            FROM Adyen_Adapter__mdt
            WHERE DeveloperName = :developerName
        ];
        if (adyenAdapters.isEmpty()) {
            throw new AdyenAsyncAdapter.GatewayException(NO_ADYEN_ADAPTER_BY_NAME + developerName);
        }
        return adyenAdapters[0];
    }

    public static Adyen_Adapter__mdt retrieveAdapterByMerchantAcct(String merchantAccountName) {
        List<Adyen_Adapter__mdt> adyenAdapters = [
            SELECT
                DeveloperName, MasterLabel, Capture_Endpoint__c, Endpoint_Api_Version__c,
                System_Integrator_Name__c, Endpoint_Path__c, Merchant_Account__c, Refund_Endpoint__c,
                Authorize_Endpoint__c, HMAC_Key__c
            FROM Adyen_Adapter__mdt
            WHERE Merchant_Account__c = :merchantAccountName
        ];
        if (adyenAdapters.isEmpty()) {
            throw new AdyenAsyncAdapter.GatewayException(NO_ADYEN_ADAPTER_BY_MERCHANT + merchantAccountName);
        }
        return adyenAdapters[0];
    }

    public static Adyen_Adapter__mdt chooseAdapterWithFallBack(String merchantAccountName) {
        if (String.isNotBlank(merchantAccountName)) {
            return retrieveAdapterByMerchantAcct(merchantAccountName);
        } else {
            return retrieveGatewayMetadata(AdyenConstants.DEFAULT_ADAPTER_NAME);
        }
    }

    public static Boolean isValidNotification(NotificationRequestItem notificationRequestItem) {
        return AdyenOMSConstants.VALID_NOTIFICATION_TYPES.contains(notificationRequestItem.eventCode.toUpperCase())
            && isValidPspReference(notificationRequestItem.originalReference)
            && isValidPspReference(notificationRequestItem.pspReference);
    }

    // The Adyen PSP Reference number is a alphanumeric value containing 16 characters
    private static Boolean isValidPspReference(String pspReference) {
        return String.isNotBlank(pspReference) && pspReference.isAlphanumeric() && pspReference.length() == 16;
    }
    
    
    /**
    * Retrieve PaymentAuthorizations Info.
    *
    * @param paymentAuthId The sObject PaymentAuthorizationId
    * @return a PaymentAuthorization sObject.
    */
    public static PaymentAuthorization retrievePaymentAuthorization(Id paymentAuthId) {
        List<PaymentAuthorization> paymentAuthorizations = [
            SELECT
                Id, PaymentAuthorizationNumber, GatewayRefNumber, Adyen_Payment_Method_Variant__c,
                OrderPaymentSummary.LastPaymentGatewayLog.GatewayRefNumber,
                OrderPaymentSummary.Id,
                OrderPaymentSummary.FullName, CurrencyIsoCode,
                OrderPaymentSummary.OrderSummary.Id,
                OrderPaymentSummary.OrderSummary.SalesChannel.AdyenMerchantID__c
            FROM
                PaymentAuthorization
            WHERE
                Id = :paymentAuthId
        ];
        if (paymentAuthorizations.isEmpty()) {
            throw new AdyenAsyncAdapter.GatewayException(NO_PAYMENT_AUTH_FOUND_BY_ID + paymentAuthId);
        }
        return paymentAuthorizations[0];
    }
    
    /**
    * Check if Open Invoice method.
    *
    * @param pa The sObject PaymentAuthorizationId
    * @return Boolean denoting if the Authorization Id belongs to an Open Invoice payment method.
    */
    public static Boolean checkIfOpenInvoiceFromAuthorization(PaymentAuthorization pa) {
        if (pa != null && pa.Adyen_Payment_Method_Variant__c != null) {
            for (String openInvoiceMethod : AdyenOMSConstants.OPEN_INVOICE_METHODS) {
                 if (pa.Adyen_Payment_Method_Variant__c.containsIgnoreCase(openInvoiceMethod)) {
                     return true;
                 }
            }
        }
        return false;
    }
    
    /**
    * Retrieve apex adapter id from the gateway reference number.
    *
    * @param gatewayRefNumber original payment gateway reference number as received in the notification
    * @return apex class id for the payment gateway adapter.
    */
    public static Boolean relatedPaymentFound(String gatewayRefNumber) {
        // Prioritize the payment authorization record if it exists
        List<PaymentAuthorization> paymentAuthorizations = [
            SELECT PaymentGateway.PaymentGatewayProvider.ApexAdapter.Id
            FROM PaymentAuthorization
            WHERE GatewayRefNumber = :gatewayRefNumber
        ];
        if (!paymentAuthorizations.isEmpty()) {
            return true;
        }
        // Fall back to a payment record for pre-captured transactions
        List<Payment> payments = [
            SELECT PaymentGateway.PaymentGatewayProvider.ApexAdapter.Id
            FROM Payment
            WHERE GatewayRefNumber = :gatewayRefNumber
        ];
        return !payments.isEmpty();
    }
    
    public static Integer getAmountMultiplier(String currencyCode) {
        if (AdyenOMSConstants.THREE_DECIMAL_CURRENCIES.contains(currencyCode)) {
            return 1000;
        } else if (AdyenOMSConstants.ZERO_DECIMAL_CURRENCIES.contains(currencyCode)) {
            return 1;
        } else {
            return 100;
        }
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
                Integer.valueOf((taxAmount/amountExcludingTax).setScale(4, RoundingMode.HALF_UP) * 10000) :
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
        return replaceAttributeName(input, mapKeyToReplace);
    }
    
    /**
    * Convert a response from adyen into an Adyen apex library friendly object
    * (adds the '_x' back into attributes that are apex keywords)
    *
    * @param input - the json string missing the *_x from its keys
    * @return output - the same json string with *_x added back in
    */
    public static String makeSalesforceCompatible(String input) {
        Map<String, String> mapKeyToReplace = new Map<String, String>{
            'recurring.recurringDetailReference' => 'recurring_recurringDetailReference',
            'currency' => 'currency_x',
            'number' => 'number_x',
            'group' => 'group_x'
        };
        return replaceAttributeName(input, mapKeyToReplace);
    }

    private static String replaceAttributeName(String input, Map<String,String> fromKeyToValueMap) {
        String output = input;
        for (String key : fromKeyToValueMap.keySet()) {
            output = output.replace(key, fromKeyToValueMap.get(key));
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

    public static String getReference(CommercePayments.CaptureRequest captureRequest) {
        Id invoiceId = captureRequest.additionalData?.get('invoiceId');
        if (invoiceId == null) {
            return getRandomNumber(16);
        }
        List<FulfillmentOrder> fulfillmentOrders = [
            SELECT FulfillmentOrderNumber
            FROM FulfillmentOrder
            WHERE InvoiceId = :invoiceId
        ];
        if (fulfillmentOrders.isEmpty() || fulfillmentOrders.size() > 1) {
            return getRandomNumber(16);
        }
        return fulfillmentOrders[0].FulfillmentOrderNumber;
    }

    /**
    * Round an amount to a normalized value for consistency
    *
    * @param amount the decimal amount type to be normalized
    * @return the same amount with 2 decimal points using half even rounding mode
    */
    public static Decimal normalizeAmount(Decimal amount) {
        return amount.setScale(2, System.RoundingMode.HALF_UP);
    }
    
    /**
    * Add application information to the webservice request
    *
    * @param integratorName as specified in the custom metadata
    * @return application information map for the request.
    */
    public static ApplicationInfo getApplicationInfo(String integratorName) {
        ApplicationInfo info = new ApplicationInfo();
        
        ExternalPlatform exPlatform = new ExternalPlatform();
        exPlatform.name = AdyenOMSConstants.EXTERNAL_PLATFORM_NAME_FOR_APP_INFO;
        exPlatform.integrator = integratorName;
        info.externalPlatform = exPlatform;
        
        CommonField merchantApplication = new CommonField();
        merchantApplication.name = AdyenOMSConstants.MERCHANT_APP_NAME_FOR_APP_INFO;
        merchantApplication.version = AdyenOMSConstants.MERCHANT_APP_VERSION_FOR_APP_INFO;
        info.merchantApplication = merchantApplication;
        
        CommonField adyenLibrary = new CommonField();
        adyenLibrary.name = AdyenOMSConstants.ADYEN_LIBRARY_NAME_FOR_APP_INFO;
        adyenLibrary.version = AdyenOMSConstants.ADYEN_LIBRARY_VERSION_FOR_APP_INFO;
        info.adyenLibrary = adyenLibrary;
        
        return info;
    }

    public static CheckoutModificationRequest createModificationRequest(CommercePayments.PaymentGatewayRequest paymentRequest, String currencyIsoCode, Adyen_Adapter__mdt adyenAdapter) {
        CheckoutModificationRequest modRequest;
        Decimal price;
        String reference;

        if (paymentRequest instanceof CommercePayments.CaptureRequest) {
            CommercePayments.CaptureRequest captureRequest = (CommercePayments.CaptureRequest)paymentRequest;
            price = captureRequest.amount;
            modRequest = new CheckoutCaptureRequest();
            reference = getReference(captureRequest);
        } else if (paymentRequest instanceof CommercePayments.ReferencedRefundRequest) {
            CommercePayments.ReferencedRefundRequest refundRequest = (CommercePayments.ReferencedRefundRequest)paymentRequest;
            modRequest = new CheckoutRefundRequest();
            price = refundRequest.amount;
            reference = getRandomNumber(16);
        }

        Amount requestAmount = new Amount();
        requestAmount.value = (price * getAmountMultiplier(currencyIsoCode)).longValue();
        requestAmount.currency_x = currencyIsoCode;

        modRequest.setAmount(requestAmount);
        modRequest.setReference(reference);
        modRequest.setMerchantAccount(adyenAdapter.Merchant_Account__c);
        modRequest.setApplicationInfo(getApplicationInfo(adyenAdapter.System_Integrator_Name__c));

        return modRequest;
    }
    
    /**
    * Send modification request (payment/refund) to Adyen platform
    *
    * @param modRequest request to be sent
    * @param adyenAdapterMdt custom metadata used
    * @param pspReference Adyen payment reference
    * @return response from adyen platform.
    */
    public static CheckoutModificationResponse sendModificationRequest(CheckoutModificationRequest modRequest, Adyen_Adapter__mdt adyenAdapterMdt, String pspReference) {
        String endpoint = adyenAdapterMdt.Endpoint_Api_Version__c;
        if (modRequest instanceof CheckoutCaptureRequest) {
            endpoint += adyenAdapterMdt.Capture_Endpoint__c;
        } else if (modRequest instanceof CheckoutRefundRequest) {
            endpoint += adyenAdapterMdt.Refund_Endpoint__c;
        }
        endpoint = endpoint.replace('{paymentPspReference}', pspReference);

        HttpResponse response = makePostRequest(endpoint, JSON.serialize(modRequest, true));

        CheckoutModificationResponse modificationResponse;
        String salesforceCompatibleBody = AdyenPaymentUtility.makeSalesforceCompatible(response.getBody());
        if (modRequest instanceof CheckoutCaptureRequest) {
            modificationResponse = (CheckoutCaptureResponse)JSON.deserialize(salesforceCompatibleBody, CheckoutCaptureResponse.class);
        } else if (modRequest instanceof CheckoutRefundRequest) {
            modificationResponse = (CheckoutRefundResponse)JSON.deserialize(salesforceCompatibleBody, CheckoutRefundResponse.class);
        }
        return modificationResponse;
    }

    public static HttpResponse makePostRequest(String endpoint, String body) {
        String compatibleBody = makeAdyenCompatible(body);

        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(compatibleBody);

        CommercePayments.PaymentsHttp paymentsHttp = new CommercePayments.PaymentsHttp();
        HttpResponse response = paymentsHttp.send(request);
        if (response.getStatusCode() != 200 && response.getStatusCode() != 201) {
            throw new AdyenAsyncAdapter.GatewayException('Adyen Checkout API returned: ' + response.getStatusCode() + ', body: ' + response.getBody());
        } else {
            return response;
        }
    }
}
