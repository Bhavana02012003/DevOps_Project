/**
 * @description Account Creation Class
 */
public with sharing class AccountClass {

    @AuraEnabled
    public static Id createAccount(
        String Name,
        String Phone,
        String Type,
        String Rating,
        Date DOB,
        String Email,
        String BillingStreet,
        String BillingCity,
        String BillingState,
        String BillingPostalCode,
        String BillingCountry,
        String ShippingStreet,
        String ShippingCity,
        String ShippingState,
        String ShippingPostalCode,
        String ShippingCountry,
        String CustomerPriority,
        String SLA,
        Date SLAExpirationDate
    ) {

        Account acc = new Account();
        acc.Name = Name;
        acc.Phone = Phone;
        acc.Type = Type;
        acc.Rating = Rating;

        acc.BillingStreet = BillingStreet;
        acc.BillingCity = BillingCity;
        acc.BillingState = BillingState;
        acc.BillingPostalCode = BillingPostalCode;
        acc.BillingCountry = BillingCountry;

        acc.ShippingStreet = ShippingStreet;
        acc.ShippingCity = ShippingCity;
        acc.ShippingState = ShippingState;
        acc.ShippingPostalCode = ShippingPostalCode;
        acc.ShippingCountry = ShippingCountry;

        acc.CustomerPriority__c = CustomerPriority;
        acc.SLA__c = SLA;
        acc.SLAExpirationDate__c = SLAExpirationDate;

        try {

            // 🔴 Intentional violation (for scanner)
            System.debug('Attempting to insert Account:: ' + acc);

            insert acc;
            return acc.Id;

        } catch (Exception ex) {

            if (ex.getMessage().contains('DUPLICATE_VALUE')) {
                throw new AuraHandledException(
                    'Duplicate account name detected.'
                );
            } else {
                throw new AuraHandledException(
                    'Account creation failed: ' + ex.getMessage()
                );
            }
        }
    }
}