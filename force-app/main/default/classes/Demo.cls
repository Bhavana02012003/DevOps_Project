public with sharing class Demo {
    public static void insertAccount(List<Account> accList) {
        if (accList == null || accList.isEmpty()) {
            return; // Avoid unnecessary processing
        }

        // Check Field-Level Security (FLS) before modifying fields
        if (Schema.sObjectType.Account.fields.Description.isUpdateable() &&
            Schema.sObjectType.Account.fields.Rating.isUpdateable() &&
            Schema.sObjectType.Account.fields.Industry.isUpdateable()) {
            
            for (Account acc : accList) {
                acc.Description = 'Welcome to Our Organization';
                acc.Rating = 'Hot';  // Avoid hardcoding if possible
                acc.Industry = 'Agriculture'; // Consider storing values in Custom Metadata
            }
        }
        
        try {
            insert accList;
        } catch (DmlException e) {
            System.debug('Error inserting accounts: ' + e.getMessage()); // Consider logging it properly
        }
    }
}
