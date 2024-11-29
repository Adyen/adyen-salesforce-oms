global with sharing class PaymentLinkRegenerateAction {
    
    @InvocableMethod(Label = 'Regenerate Payment Link' Category = 'Payment Link' Callout = true)
    global static List<Id> regenerateLink(List<PBLRegenerateInput> pblRegenerateList) {
        if (pblRegenerateList == null || pblRegenerateList.isEmpty() || pblRegenerateList[0].orderSummaryId == null) {
            throw new IllegalArgumentException('Required order summary Id is missing!');
        }

        PBLRegenerateInput regenerateRequest = pblRegenerateList[0];

        OrderSummary orderSummary = [
            SELECT Id, OrderNumber, BillingCity, BillingCountry, BillingPostalCode, BillingState, BillingStreet
            FROM OrderSummary
            WHERE Id = :regenerateRequest.orderSummaryId
            LIMIT 1
        ];
        
        Payment_Link__c lastLink = getLatestLink(regenerateRequest.orderSummaryId);

        if (lastLink == null) {
            throw new HandledException('No previous payment link found for the given order summary.');
        }

        String shopperEmail = String.isNotBlank(regenerateRequest.shopperEmail) ? regenerateRequest.shopperEmail : lastLink.Shopper_Email__c;

        return generateAndPersistPaymentLink(orderSummary, lastLink, shopperEmail);
    }

    private static Payment_Link__c getLatestLink(Id orderSummaryId) {
        List<Payment_Link__c> paymentLinks = [
            SELECT Id, Amount__c, Shopper_Email__c, CurrencyIsoCode
            FROM Payment_Link__c
            WHERE Order_Summary__c = :orderSummaryId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        return paymentLinks.isEmpty() ? null : paymentLinks[0];
    }

    private static void expireExistingLink(Id orderSummaryId) {
        PaymentLinkExpireAction.PBLForceExpire forceExpireRequest = new PaymentLinkExpireAction.PBLForceExpire();
        forceExpireRequest.orderSummaryId = orderSummaryId;
        PaymentLinkExpireAction.forceExpireLink(new List<PaymentLinkExpireAction.PBLForceExpire>{ forceExpireRequest });
    }

    public static String getBillingAddressAsJson(OrderSummary orderSummary) {
        Map<String, String> addressMap = new Map<String, String>{
            'city' => orderSummary.BillingCity,
            'country' => orderSummary.BillingCountry,
            'postalCode' => orderSummary.BillingPostalCode,
            'state' => orderSummary.BillingState,
            'street' => orderSummary.BillingStreet
        };

        return JSON.serialize(addressMap);
    }

    private static List<Id> generateAndPersistPaymentLink(OrderSummary orderSummary, Payment_Link__c lastLink, String shopperEmail) {
        PaymentLinkGenerateAction.PBLCreateRequest pblCreateRequest = new PaymentLinkGenerateAction.PBLCreateRequest();
        pblCreateRequest.merchantReference = orderSummary.OrderNumber;
        pblCreateRequest.currencyIsoCode = lastLink.CurrencyIsoCode;
        pblCreateRequest.amount = lastLink.Amount__c;
        pblCreateRequest.billingAddressJson = getBillingAddressAsJson(orderSummary);

        List<PaymentLinkGenerateAction.PBLCreateResponse> responses = 
            PaymentLinkGenerateAction.handlePaymentLinkCreation(
                new List<PaymentLinkGenerateAction.PBLCreateRequest>{ pblCreateRequest }
            );

        if (!responses.isEmpty()) {
            expireExistingLink(orderSummary.Id);
            Payment_Link__c newLink = new Payment_Link__c(
                Order_Summary__c = orderSummary.Id,
                Order_Number__c = orderSummary.OrderNumber,
                Status__c = AdyenOMSConstants.PaymentLinkStatus.ACTIVE.name(),
                Amount__c = lastLink.Amount__c,
                Shopper_Email__c = shopperEmail,
                CurrencyIsoCode = lastLink.CurrencyIsoCode,
                URL__c = responses[0].paymentLink,
                Name = responses[0].paymentLinkId,
                Expire_Date__c = responses[0].expirationDateTime
            );
            insert newLink;
            return new List<Id>{ newLink.Id };
        } else {
            throw new HandledException('Failed to generate a new payment link.');
        }
    }

    global class PBLRegenerateInput {
        @InvocableVariable(Required=true)
        public Id orderSummaryId;

        @InvocableVariable
        public String shopperEmail;
    }
}
