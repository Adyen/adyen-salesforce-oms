/**
 *  AdyenService will contain all callouts to the Adyen API. as well as build of the body json to be submitted.
 *  Additionally it will parse and serialize any response from the Adyen Payment Gateway.
 */
public with sharing class AdyenService {

    public static final String MERCHANT_API_KEY        = '{!$Credential.Password}';

    /**
     *  Serialized version of the Http Response Body received from Adyen to make it easier to work with the JSON.
     */
    public class AdyenNotification {
        public String live                                      {get;set;}
        public List<NotificationItems> notificationItems        {get;set;}
    }

    public class NotificationItems {
        public NotificationRequestItem NotificationRequestItem  {get;set;}
    }

    public class NotificationRequestItem {
        public Amount amount                                    {get;set;}
        public String eventCode                                 {get;set;}
        public String eventDate                                 {get;set;}
        public String merchantAccountCode                       {get;set;}
        public String paymentMethod                             {get;set;}
        public String originalReference                         {get;set;}
        public String paymentPspReference                       {get;set;}
        public String pspReference                              {get;set;}
        public String reason                                    {get;set;}
        public String success                                   {get;set;}
    }
}