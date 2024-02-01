public with sharing class AdyenOMSConstants {

    public static final Set<String> THREE_DECIMAL_CURRENCIES = new Set<String> {'BHD','IQD','JOD','KWD','LWD','OMR','TND'};
    public static final Set<String> ZERO_DECIMAL_CURRENCIES = new Set<String> {
            'CVE', 'DJF', 'GNF', 'IDR', 'JPY', 'KMF', 'KRW',
            'PYG', 'RWF', 'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF'
    };

    public static final String EXTERNAL_PLATFORM_NAME_FOR_APPINFO = 'Adyen Salesforce OMS';
    public static final String ADYEN_LIBRARY_NAME_FOR_APPINFO = 'adyen-apex-api-library';
    public static final String ADYEN_LIBRARY_VERSION_FOR_APPINFO = '3.0.1';
    public static final String MERCHANT_APP_NAME_FOR_APPINFO = 'adyen-salesforce-oms';
    public static final String MERCHANT_APP_VERSION_FOR_APPINFO = '2.1.1';

    public static final String CARD_PAYMENTMETHOD_OBJECT = 'CardPaymentMethod';
    public static final String ALTERNATIVE_PAYMENTMETHOD_OBJECT = 'AlternativePaymentMethod';

    public static final String ADYEN_2GP_NAMESPACE = 'adyen_payment';
    public static final Set<String> OPEN_INVOICE_METHODS = new Set<String> {'klarna', 'afterpay', 'ratepay', 'facilypay', 'zip', 'affirm', 'atome', 'walley', 'clearpay'};
}