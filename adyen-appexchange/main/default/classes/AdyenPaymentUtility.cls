public with sharing class AdyenPaymentUtility {

    @TestVisible private static final String  TEST_ENDPOINT             = 'https://bogus.unittest.com'; // Unit test EP
    @TestVisible private static final String  CONTENT_TYPE              = 'application/json';
    @TestVisible private static final String  INVALID_ADYEN_RESPONSE    = '[Invalid Adyen Response]';
    @TestVisible private static final String  TEST_REF_NUMBER           = '853589212870047B';  // default used for test postman

    public static final Integer HTTP_SUCCESS_CODE                       = 200;
    public static final Integer HTTP_SERVER_ERROR_CODE                  = 500;
    public static final String  GATEWAY_ERROR_RESPONSE_CODE             = '400';
    public static final String  APEX_RESERVED_CURRENCY_FIELD            = 'currency_x'; // allows deserialization of reserved words.

    public static final Set<String> threeDecimalCurrencies              = new Set<String> {'BHD','IQD','JOD','KWD','LWD','OMR','TND'};
    public static final Set<String> zeroDecimalCurrencies               = new Set<String>{
            'CVE', 'DJF', 'GNF', 'IDR', 'JPY', 'KMF', 'KRW',
            'PYG', 'RWF', 'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF'
    };


    private static final CommercePayments.SalesforceResultCodeInfo SUCCESS_SALESFORCE_RESULT_CODE_INFO =
            new CommercePayments.SalesforceResultCodeInfo(CommercePayments.SalesforceResultCode.Success);

    private static final CommercePayments.SalesforceResultCodeInfo DECLINE_SALESFORCE_RESULT_CODE_INFO =
            new CommercePayments.SalesforceResultCodeInfo(CommercePayments.SalesforceResultCode.Decline);

    @TestVisible private static final String NOTIFICATION_REQUEST_TYPE_CAPTURE  = 'capture';
    @TestVisible private static final String NOTIFICATION_REQUEST_TYPE_REFUND   = 'refund';
    @TestVisible private static final String NOTIFICATION_ACCEPTED_RESPONSE     = '[accepted]';


    /**
     * Looks for the Gateway ref number on the Payment record passed in. If not found gets its from
     * the LastPaymentGateway log on the OrderPaymentSummary record.
     *
     * @param payment the Payment sObject.
     * @return the GatewayRefNumber for the request.
     */
    public static String getRefundGatewayRefNumber( Payment payment ) {
        String originalRefNumber = '852588607835597D'; // defaulted for apex unit testing.
        String msg = '';
        String gwRefNumber;

        // For transactions that were originally authorized 
        if(payment != null && payment.PaymentAuthorization != null && payment.PaymentAuthorization.GatewayRefNumber != null) {
            gwRefNumber = payment.PaymentAuthorization.GatewayRefNumber;
        }
        // Transactions that were capture/sale by the front-end commerce platform
        else if (payment != null && payment.GatewayRefNumber != null) {
            gwRefNumber = payment.GatewayRefNumber;
        }
        else {
            // ERROR - need gateway ref number
        }
        if(gwRefNumber != null) {
            originalRefNumber = gwRefNumber;
            //msg += '-------> Using Payment.GatewayRefNumber as match to Adyen PSPReference via ';
            //msg += ' using Payment.PaymentAuthoriziation.GatwwayRefNumber as match to Adyen PspReference via: ';
            //msg += ' Payment:  '+payment + ' from captureRequest: '+originalRefNumber;
        } else {
            //https://ca-test.adyen.com/ca/ca/accounts/showTx.shtml?pspReference=852588546520527A&txType=Payment
            gwRefNumber = TEST_REF_NUMBER;
            msg += '-------> No paymentId or payment.GatewayRefNumber in captureRequest. ';
            msg += 'Payment=' + payment;
            msg += 'Using sample of ' + originalRefNumber;
            msg += 'Running Test? ' + String.valueOf(Test.isRunningTest());
        }
        return originalRefNumber;
    }


    /**
     * Retrieve Payment Info.
     *
     * @param paymentId The Payment.Id value
     * @return a Payment sObject.
     */
    public static Payment retrievePayment(Id paymentId) {
        Payment payment;

        if (
            Schema.sObjectType.Payment.fields.Id.isAccessible() && 
            Schema.sObjectType.Payment.fields.GatewayRefNumber.isAccessible() && 
            Schema.sObjectType.Payment.fields.adyenOverrideMerchantConfig__c.isAccessible() &&
            Schema.sObjectType.PaymentAuthorization.fields.GatewayRefNumber.isAccessible() && 
            Schema.sObjectType.PaymentAuthorization.fields.adyenOverrideMerchantConfig__c.isAccessible() &&
            Schema.sObjectType.Payment.fields.CurrencyIsoCode.isAccessible() && 
            Schema.sObjectType.OrderPaymentSummary.fields.FullName.isAccessible() && 
            Schema.sObjectType.SalesChannel.fields.AdyenMerchantID__c.isAccessible()
        ) {
            List<Payment> payments = [
                SELECT  
                    Id, 
                    GatewayRefNumber, PaymentAuthorization.GatewayRefNumber, 
                    adyenOverrideMerchantConfig__c, PaymentAuthorization.adyenOverrideMerchantConfig__c,
                    CurrencyIsoCode,
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
     *  @returns Adyen_Adapter__mdt for the passed metadata type with all fields.
     */
    public static Adyen_Adapter__mdt retrieveGatewayMetadata(String metaType) {

        if (Test.isRunningTest()) {
            Adyen_Adapter__mdt testAdyenAdapter = new Adyen_Adapter__mdt();
            testAdyenAdapter.MasterLabel = 'AdyenDefault';
            testAdyenAdapter.Single_Currency_Code__c = 'USD';
            testAdyenAdapter.System_Integrator_Name__c = 'CAPGEMINI';
            testAdyenAdapter.Endpoint_Method__c = 'POST';
            testAdyenAdapter.Refund_Endpoint__c = '/refund';
            testAdyenAdapter.Refund_Endpoint__c = '/capture';
            testAdyenAdapter.Endpoint_Api_Version__c = '/testEPV';
            testAdyenAdapter.Service_Password__c = 'ABC123';
            testAdyenAdapter.Service_Username__c = 'TEST_USER';
            return testAdyenAdapter;
        }
        else {
            Adyen_Adapter__mdt adyenAdapterMdt;
            if (
                Schema.sObjectType.Adyen_Adapter__mdt.fields.Developername.isAccessible() && Schema.sObjectType.Adyen_Adapter__mdt.fields.NamespacePrefix.isAccessible() &&
                Schema.sObjectType.Adyen_Adapter__mdt.fields.MasterLabel.isAccessible() && Schema.sObjectType.Adyen_Adapter__mdt.fields.Capture_Endpoint__c.isAccessible() &&
                Schema.sObjectType.Adyen_Adapter__mdt.fields.Endpoint_Api_Version__c.isAccessible() && Schema.sObjectType.Adyen_Adapter__mdt.fields.Endpoint_Method__c.isAccessible() &&
                Schema.sObjectType.Adyen_Adapter__mdt.fields.Endpoint_Path__c.isAccessible() && Schema.sObjectType.Adyen_Adapter__mdt.fields.Merchant_Account__c.isAccessible() &&
                Schema.sObjectType.Adyen_Adapter__mdt.fields.System_Integrator_Name__c.isAccessible() && Schema.sObjectType.Adyen_Adapter__mdt.fields.Refund_Endpoint__c.isAccessible() &&
                Schema.sObjectType.Adyen_Adapter__mdt.fields.Single_Currency_Code__c.isAccessible() && Schema.sObjectType.Adyen_Adapter__mdt.fields.Service_Username__c.isAccessible() && 
                Schema.sObjectType.Adyen_Adapter__mdt.fields.Service_Password__c.isAccessible())  {

                adyenAdapterMdt = [
                    SELECT
                        Developername, NamespacePrefix, MasterLabel, Capture_Endpoint__c, Endpoint_Api_Version__c, 
                        System_Integrator_Name__c, Endpoint_Method__c, Endpoint_Path__c, Merchant_Account__c, 
                        Refund_Endpoint__c, Single_Currency_Code__c, Service_Username__c, Service_Password__c
                    FROM
                        Adyen_Adapter__mdt
                    WHERE
                        Developername = :metaType
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

        if (
            Schema.sObjectType.PaymentAuthorization.fields.Id.isAccessible() &&
            Schema.sObjectType.PaymentAuthorization.fields.PaymentAuthorizationNumber.isAccessible() &&
            Schema.sObjectType.PaymentAuthorization.fields.GatewayRefNumber.isAccessible() &&
            Schema.sObjectType.PaymentAuthorization.fields.CurrencyIsoCode.isAccessible() &&
            Schema.sObjectType.PaymentAuthorization.fields.adyenOverrideMerchantConfig__c.isAccessible() &&
			Schema.sObjectType.PaymentGatewayLog.fields.GatewayRefNumber.isAccessible() &&
            Schema.sObjectType.OrderPaymentSummary.fields.Id.isAccessible() &&
            Schema.sObjectType.OrderPaymentSummary.fields.FullName.isAccessible() && 
            Schema.sObjectType.SalesChannel.fields.ADYENMERCHANTID__C.isAccessible()
		) {
            List<PaymentAuthorization> paymentAuthorizations = [
                SELECT
                    Id, PaymentAuthorizationNumber, GatewayRefNumber, adyenOverrideMerchantConfig__c,
                    OrderPaymentSummary.LastPaymentGatewayLog.GatewayRefNumber,
                    OrderPaymentSummary.Id,
                    OrderPaymentSummary.FullName, CurrencyIsoCode,
                    OrderPaymentSummary.OrderSummary.Id,
                    OrderPaymentSummary.OrderSummary.Adyen_paymentMethod__c,
                	OrderPaymentSummary.OrderSummary.SalesChannel.ADYENMERCHANTID__C
                FROM
                    PaymentAuthorization
                WHERE
                    Id = :paymentAuthId
                ORDER BY
                    CreatedDate DESC
            ];
            if(!paymentAuthorizations.isEmpty()) {
                pa = paymentAuthorizations[0];
                System.debug(LoggingLevel.INFO, 'SalesChannel Config: ' + pa.OrderPaymentSummary.OrderSummary.SalesChannel.ADYENMERCHANTID__C);
            }
        }
        return pa;
    }

    /**
     * Check if Klarna Order.
     *
     * @param paymentAuthId The sObject PaymentAuthorizationId
     * @return Boolean denoting if the Authorization Id belongs to a Klarna Order.
     */
    public static Boolean checkIfKlarnaOrderFromAuthorization(PaymentAuthorization pa) {
        OrderItemSummary ois;
        String adyenPaymentMethod;
        Boolean isKlarnaOrder = false;

        if (pa != null && pa.OrderPaymentSummary != null && pa.OrderPaymentSummary.OrderSummary.Adyen_paymentMethod__c != null) {
            isKlarnaOrder = pa.OrderPaymentSummary.OrderSummary.Adyen_paymentMethod__c.containsIgnoreCase('klarna');
        }
        // String soql = '';
        // soql =  'SELECT adyenPaymentMethod__c FROM PaymentAuthorization where Id = :paymentAuthId';

        // List<PaymentAuthorization> paymentAuthorizations = Database.query(soql);
        
        // if(!paymentAuthorizations.isEmpty()) {
        //     if (paymentAuthorizations[0].adyenPaymentMethod__c != null) {
        //         adyenPaymentMethod = paymentAuthorizations[0].adyenPaymentMethod__c;
        //         if(adyenPaymentMethod.containsIgnoreCase('klarna')){
        //             isKlarnaOrder = true;
        //         }
        //     }
        // }
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
                    SELECT 
                        PaymentGateway.PaymentGatewayProvider.ApexAdapter.Id 
                    FROM 
                        PaymentAuthorization 
                    WHERE 
                        GatewayRefNumber = :gatewayRefNumber
                ]
                ) {
                    if(null!=paymentAuthorization.PaymentGateway && null!=paymentAuthorization.PaymentGateway.PaymentGatewayProvider && null!=paymentAuthorization.PaymentGateway.PaymentGatewayProvider.ApexAdapter)
                    {
                        apexAdapterId = paymentAuthorization.PaymentGateway.PaymentGatewayProvider.ApexAdapter.Id;
                    }
                }

            // Fall back to a payment record for pre-captured transactions
            if (null==apexAdapterId) {
                    for (Payment payment : [
                        SELECT 
                            PaymentGateway.PaymentGatewayProvider.ApexAdapter.Id 
                        FROM 
                            Payment
                        WHERE 
                            GatewayRefNumber = :gatewayRefNumber
                    ]
                    ) {
                        if (null!=payment.PaymentGateway && null!=payment.PaymentGateway.PaymentGatewayProvider && null!=payment.PaymentGateway.PaymentGatewayProvider.ApexAdapter) 
                        {
                            apexAdapterId = payment.PaymentGateway.PaymentGatewayProvider.ApexAdapter.Id;
                        }
                    }
            }

        return apexAdapterId;
    }

    /**
     * Retrieve apex id from the class name and namespaceprefix.
     *
     * @param className The Class Name
     * @param namespace Namespace of the current class
     * @return apexclass id.
     */
    public static String retrieveApexClassId(String className, String namespace) {
        ApexClass apexClass = null;
        String apexAdapterId = null;
        String soql = 'SELECT Id FROM ApexClass WHERE Name = :className AND NamespacePrefix = :namespace';
        List<ApexClass> apexClasses = Database.query(soql);
        if(!apexClasses.isEmpty()) {
            apexClass = apexClasses[0];
            if(null!=apexClass){
                apexAdapterId = apexClass.Id;
            }
        }
        return apexAdapterId;
    }

    public static Integer getAmountMultiplier(String currencyCode) {
        if(threeDecimalCurrencies.contains(currencyCode))
            return 1000;
        else if (zeroDecimalCurrencies.contains(currencyCode))
            return 1;
        else
            return 100;
    }

    /**
     * Looks for the Gateway ref number on the PaymentAuthorization record passed in. If not found gets its from
     * the LastPaymentGateway log on the OrderPaymentSummary record.
     *
     * @param pa  The PaymentAuthorization sObject
     * @return the GatewayRefNumber for the request.
     */
    public static String getCaptureGatewayRefNumber( PaymentAuthorization pa ) {

        String originalRefNumber = TEST_REF_NUMBER; //  '852588546520527A';
        String msg = '';
        String gwRefNumber;
        if(pa!=null) {
            gwRefNumber = pa.GatewayRefNumber;
            if (gwRefNumber == null) {
                gwRefNumber = pa.OrderPaymentSummary.LastPaymentGatewayLog.GatewayRefNumber;
            }
        }
        if(gwRefNumber != null) {
            originalRefNumber = gwRefNumber;
            msg += '-------> Found payment gateway ref to Adyen PSPReference via ';
            msg += ' PaymentAuth:  '+pa + ' from captureRequest: '+originalRefNumber;
        } else {
            //https://ca-test.adyen.com/ca/ca/accounts/showTx.shtml?pspReference=852588546520527A&txType=Payment
            gwRefNumber = TEST_REF_NUMBER;
            msg += '-------> No paymentauthId or paymentAuthorization.GatewayRefNumber in captureRequest. ';
            msg += 'PaymentAuth='+pa + ' Where is the number supposed to come from? ';
            msg += 'Using sample of  '+originalRefNumber;
        }
        return originalRefNumber;
    }

    /**
     * Add application information to the webservice request
     *
     * @return application information map for the request.
     */
    public static Map<String, Object> getApplicationInfo(String integratorName) {

        Map<String, Object> applicationInfo = new Map<String, Object>();
        Map<String, Object> merchantApplication = new Map<String, Object>();
        Map<String, Object> externalPlatform = new Map<String, Object>();

        merchantApplication.put('name', 'AdyenSOM');
        merchantApplication.put('version', '1.0');

        externalPlatform.put('name', 'Salesforce Order Management');
        externalPlatform.put('version', '2020_winter');
        externalPlatform.put('integrator', integratorName);

        applicationInfo.put('merchantApplication', merchantApplication);
        applicationInfo.put('externalPlatform', externalPlatform);

        return applicationInfo;
    }
}