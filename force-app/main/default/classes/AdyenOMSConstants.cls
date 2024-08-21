public with sharing class AdyenOMSConstants {

    public static final Set<String> THREE_DECIMAL_CURRENCIES = new Set<String> {'BHD','IQD','JOD','KWD','LWD','OMR','TND'};
    public static final Set<String> ZERO_DECIMAL_CURRENCIES = new Set<String> {
            'CVE', 'DJF', 'GNF', 'IDR', 'JPY', 'KMF', 'KRW',
            'PYG', 'RWF', 'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF'
    };

    public static final String EXTERNAL_PLATFORM_NAME_FOR_APP_INFO = 'Adyen Salesforce OMS';
    public static final String ADYEN_LIBRARY_NAME_FOR_APP_INFO = 'adyen-apex-api-library';
    public static final String ADYEN_LIBRARY_VERSION_FOR_APP_INFO = '3.2.0';
    public static final String MERCHANT_APP_NAME_FOR_APP_INFO = 'adyen-salesforce-oms';
    public static final String MERCHANT_APP_VERSION_FOR_APP_INFO = '3.0.0';

    public static final String CARD_PAYMENT_METHOD_OBJECT = 'CardPaymentMethod';
    public static final String ALTERNATIVE_PAYMENT_METHOD_OBJECT = 'AlternativePaymentMethod';

    public static final Set<String> OPEN_INVOICE_METHODS = new Set<String>{'klarna', 'afterpay', 'ratepay', 'facilypay', 'zip', 'affirm', 'atome', 'walley', 'clearpay'};
    public static final Set<String> VALID_NOTIFICATION_TYPES = new Set<String>{AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE, AdyenConstants.NOTIFICATION_REQUEST_TYPE_REFUND, AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE_FAILED, AdyenConstants.NOTIFICATION_REQUEST_TYPE_REFUND_FAILED};
}