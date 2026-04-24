/**
 * @description Account Creation Class
    Testing Comment Issues
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
        params.add(String.valueOf(result.get('page')));

        try {

            // 🔴 Intentional violation (for scanner)
            System.debug('Attempting to insert Account: ' + acc);

            insert acc;
            return acc.Id;

        } catch (Exception ex) {

            if (ex.getMessage().contains('DUPLICATE_VALUE')) {
                throw new AuraHandledException(
                    'Duplicate account name detected.'
                );
                System.debug('❌ Duplicate account name:: ' + Name);
            } else {
                throw new AuraHandledException(
                    'Account creation failed: ' + ex.getMessage()
                );
                System.debug('❌ Account creation error: ' + ex.getMessage());
            }
        }
    }
    /**
     * @description Fetches a list of the most recently created Accounts.
     * Use Case: Populate a "Recent Accounts" table in a Lightning Component.
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> getRecentAccounts(Integer limitSize) {
        try {
            return [
                SELECT Id, Name, Phone, Type, Rating, CreatedDate 
                FROM Account 
                WITH SECURITY_ENFORCED 
                ORDER BY CreatedDate DESC 
                LIMIT :limitSize
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching accounts: ' + e.getMessage());
            System.debug('❌ Account creation error: ' + e.getMessage());
        }
    }

    /**
     * @description Updates the description of a specific Account.
     * Use Case: Quick-update functionality from a custom UI.
     */
    @AuraEnabled
    public static void updateAccountDescription(Id accountId, String description) {
        try {
            Account acc = new Account(Id = accountId, Description = description);
            update acc;
        } catch (Exception e) {
            throw new AuraHandledException('Update failed: ' + e.getMessage());
            System.debug('❌ Account creation error: ' + e.getMessage());
        }
    }
}