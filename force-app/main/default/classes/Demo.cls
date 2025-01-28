/**
 * @description This class handles Account insertion while ensuring proper security checks.
 * @author [Your Name]
 * @date [Current Date]
 */
public with sharing class Demo {

    /**
     * @description Inserts a list of Accounts after validating field-level security (FLS) and CRUD permissions.
     * @param accList List of Account records to insert.
     */
    public static void insertAccount(List<Account> accList) {
        if (accList == null || accList.isEmpty()) {
            return; // Avoid unnecessary processing
        }

        // Check if the user has permission to create Account records
        if (!Schema.sObjectType.Account.isCreateable()) {
            throw new SecurityException('Insufficient permissions to create Account records.');
        }

        // Check Field-Level Security (FLS) before modifying fields
        Boolean canUpdateFields = Schema.sObjectType.Account.fields.Description.isUpdateable() &&
                                  Schema.sObjectType.Account.fields.Rating.isUpdateable() &&
                                  Schema.sObjectType.Account.fields.Industry.isUpdateable();

        if (canUpdateFields) {
            for (Account acc : accList) {
                acc.Description = 'Welcome to Our Organization';
                acc.Rating = 'Hot';  // Consider using Custom Metadata instead of hardcoding
                acc.Industry = 'Agriculture';
            }
        }

        try {
            insert accList;
        } catch (DmlException e) {
            System.debug(LoggingLevel.ERROR, 'Error inserting accounts: ' + e.getMessage()); // Using LoggingLevel
        }
    }
}
