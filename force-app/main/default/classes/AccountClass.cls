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
                System.debug('❌ Duplicate account name: ' + Name);
            } else {
                throw new AuraHandledException(
                    'Account creation failed: ' + ex.getMessage()
                );
                System.debug('❌ Account creation error:: ' + ex.getMessage());
            }
        }
    }
    @AuraEnabled(cacheable=true)
    public static Account getAccountById(Id accountId) {
        try {
            return [
                SELECT Id, Name, Phone, Type, Rating, BillingCity, BillingState, CustomerPriority__c
                FROM Account
                WHERE Id = :accountId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
        } catch (Exception ex) {
            System.debug('❌ Error retrieving account: ' + ex.getMessage());
            throw new AuraHandledException('Error retrieving account: ' + ex.getMessage());
        }
    }
    public static List<Account> searchAccounts(String searchTerm) {
        // Return an empty list early if the search term is empty or null
        if (String.isBlank(searchTerm)) {
            return new List<Account>();
        }

        // Append wildcards for the SOQL LIKE operator
        String searchKey = '%' + searchTerm + '%';

        try {
            return [
                SELECT Id, Name, Phone, Type, Industry, BillingCity
                FROM Account
                WHERE Name LIKE :searchKey
                WITH SECURITY_ENFORCED
                ORDER BY Name ASC
                LIMIT 10
            ];
        } catch (Exception ex) {
            System.debug('❌ Error searching accounts: ' + ex.getMessage());
            throw new AuraHandledException('Error searching accounts: ' + ex.getMessage());
        }
    }
}