@isTest
public class TestDataFactory {
    // constants
    public static final String TEST_PSP_REFERENCE = '853587067740652G';
    public static final String TEST_PSP_REFERENCE_FAIL = '853587067740652F';
    public static final String TEST_MERCHANT_ACCOUNT = 'TEST_MERCHANT_ACCOUNT';
    public static final String TEST_MERCHANT_REFERENCE = 'TEST_MERCHANT_REFERENCE';
    public static final String TEST_SHOPPER_REFERENCE = 'TEST_SHOPPER_REFERENCE';
    public static final String TEST_CARD_SUCCESS = '4242424242424242';
    public static final String TEST_PAYMENT_TOKEN = 'TEST_PAYMENT_TOKEN';
    public static final String TEST_AUTH_CODE = 'TEST_AUTH_CODE';
    public static final String RESULT_CODE_SUCCESS = 'Authorised';
    public static final String RESULT_CODE_FAIL = 'Failure';
    public static final Double TEST_AMOUNT = 19.99;
    public static final String ACTIVE_CURRENCY = [SELECT IsoCode FROM CurrencyType WHERE IsActive = true LIMIT 1].IsoCode;

    public static AdyenAsyncAdapter adyenAdapter = new AdyenAsyncAdapter();

    public static Account createAccount() {
        return new Account(Name = 'Test Account');
    }

    public static CardPaymentMethod createCardPaymentMethod() {
        return new CardPaymentMethod(
            GatewayToken = TEST_PAYMENT_TOKEN,
            GatewayTokenEncrypted = TEST_PAYMENT_TOKEN,
            CardHolderName = 'Test Cardholder',
            Email = 'test@asdf.com',
            Status = 'Active',
            ProcessingMode = 'External'
        );
    }

    public static AlternativePaymentMethod createAlternativePaymentMethod() {
        return new AlternativePaymentMethod(
            GatewayToken = TEST_PAYMENT_TOKEN,
            Email = 'test@asdf.com',
            Status = 'Active',
            ProcessingMode = 'External'
        );
    }

    public static PaymentGateway createPaymentGateway() {
        return new PaymentGateway(
            PaymentGatewayName = 'Adyen',
            Status = 'Active',
            ExternalReference = 'Adyen_Component',
            MerchantCredentialId = [SELECT Id FROM NamedCredential LIMIT 1]?.Id,
            PaymentGatewayProviderId = [SELECT Id FROM PaymentGatewayProvider LIMIT 1]?.Id
        );
    }

    public static PaymentAuthorization createPaymentAuthorization(Id acctId, Id cardPayMetId, Id payGatId) {
        return new PaymentAuthorization(
            AccountId = acctId,
            PaymentMethodId = cardPayMetId,
            Amount = TEST_AMOUNT,
            GatewayRefNumber = TEST_PSP_REFERENCE,
            Status = 'Processed',
            ProcessingMode = 'External',
            PaymentGatewayId = payGatId,
            CurrencyIsoCode = ACTIVE_CURRENCY
        );
    }

    public static Payment createPayment(Id acctId, Id cardPayMetId, Id payGatId, Id payAuthId) {
        return new Payment(
            AccountId = acctId,
            PaymentMethodId = cardPayMetId,
            Amount = TEST_AMOUNT,
            GatewayRefNumber = TEST_PSP_REFERENCE,
            Status = 'Processed',
            ProcessingMode = 'External',
            Type = 'Capture',
            PaymentGatewayId = payGatId,
            PaymentAuthorizationId = payAuthId
        );
    }

    public static void insertBasicPaymentRecords() {
        Account acct = createAccount();
        insert acct;
        
        CardPaymentMethod cardPayMeth = createCardPaymentMethod();
        insert cardPayMeth;
        
        PaymentGateway payGat = createPaymentGateway();
        insert payGat;
        
        PaymentAuthorization payAuth = createPaymentAuthorization(acct.Id, cardPayMeth.Id, payGat.Id);
        insert payAuth;
        
        Payment payment = createPayment(acct.Id, cardPayMeth.Id, payGat.Id, payAuth.Id);
        insert payment;
    }

    public static String createNotificationRequestBody(String eventCode) {
        NotificationRequestItem nri = new NotificationRequestItem();
        Amount a = new Amount();
        a.currency_x = ACTIVE_CURRENCY;
        a.value = (Long)Integer.valueOf(TEST_AMOUNT*10);
        nri.amount = a;
        nri.eventCode = eventCode;
        nri.pspReference = 'pspref';
        nri.eventDate = String.valueOf(System.TODAY());
        nri.paymentpspReference = 'paymentpspref';
        nri.success = 'true';
        nri.merchantAccountCode = 'merchant_account_code';
        
        NotificationItems notificationItems = new NotificationItems();
        notificationItems.NotificationRequestItem = nri;
        AdyenNotification adyenNotification = new AdyenNotification();
        adyenNotification.live = 'false';
        adyenNotification.notificationItems = new List<NotificationItems>{notificationItems};
        return JSON.serialize(adyenNotification);
    }

    public static CommercePayments.AuthorizationRequest createAuthorisationRequest(Id payMethodId) {
        CommercePayments.AuthorizationRequest authRequest = new CommercePayments.AuthorizationRequest(TEST_AMOUNT);
        authRequest.currencyIsoCode = ACTIVE_CURRENCY;
        
        CommercePayments.CardPaymentMethodRequest cardPayMeth = new CommercePayments.CardPaymentMethodRequest(CommercePayments.CardCategory.CreditCard);
        authRequest.paymentMethod = new CommercePayments.AuthApiPaymentMethodRequest(cardPayMeth);
        authRequest.paymentMethod.Id = payMethodId;

        CommercePayments.PaymentGatewayContext payGatecontext = new CommercePayments.PaymentGatewayContext(authRequest, CommercePayments.RequestType.Authorize);
        CommercePayments.PaymentGatewayRequest paymentRequest = payGatecontext.getPaymentRequest();
        return (CommercePayments.AuthorizationRequest)paymentRequest;
    }

    public class EchoHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(AdyenConstants.HTTP_SUCCESS_CODE);
            Map<String, Object> responseBody = new Map<String, Object> {
                'pspReference' => TEST_PSP_REFERENCE,
                'status' => AdyenConstants.NOTIFICATION_RECEIVED_CHECKOUT
            };
            Map<String, Object> additionalData = new Map<String, Object>();
            Map<String, Object> amount = new Map<String, Object> {
                'currency' => ACTIVE_CURRENCY,
                'value' => 0
            };
            
            String endpoint = req.getEndpoint();
            Map<String, Object> requestBody = (Map<String, Object>)JSON.deserializeUntyped(req.getBody());
            
            if(endpoint.containsIgnoreCase('payment')) {
                Map<String, Object> paymentMethod = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize((requestBody.get('paymentMethod'))));
                Object spm = requestBody.get('storePaymentMethod');
                responseBody.put('resultCode', RESULT_CODE_SUCCESS);
                // Authorize
                if(TEST_PAYMENT_TOKEN.equals(paymentMethod.get('storedPaymentMethodId'))) { // Successful Auth
                    additionalData.put('authCode', TEST_AUTH_CODE);
                    amount.put('value', Integer.valueOf(TEST_AMOUNT*10));
                } else { // Failed Auth
                    responseBody.put('resultCode', RESULT_CODE_FAIL);
                    res.setStatusCode(AdyenConstants.HTTP_ERROR_CODE);
                }
                responseBody.put('additionalData', additionalData);
            } else if(endpoint.containsIgnoreCase('capture')) {
                // Capture
                responseBody.put('reference', TEST_SHOPPER_REFERENCE);
                if(requestBody.get('merchantAccount') != '' && requestBody.get('amount') != null) { // Successful Capture
                    amount.put('value', Integer.valueOf(TEST_AMOUNT*10));
                } else { // Failed Capture
                    res.setStatusCode(AdyenConstants.HTTP_ERROR_CODE);
                }
            } else if(endpoint.containsIgnoreCase('refund')) {
                // Refund
                responseBody.put('reference', TEST_SHOPPER_REFERENCE);
                if(requestBody.get('merchantAccount') != '' && requestBody.get('amount') != null) { // Successful Refund
                    amount.put('value', Integer.valueOf(TEST_AMOUNT*10));
                } else { // Failed Refund
                    res.setStatusCode(AdyenConstants.HTTP_ERROR_CODE);
                }
            }
            res.setBody(JSON.serialize(responseBody));
            return res;
        }
    }
}