/**
 * @description This class handles operations related to Account records.
 * @author Your Name
 */
public with sharing class Demo {

    /**
     * @description Inserts a list of Account records after validating field permissions.
     * @param accList List of Account records to be inserted.
     */
    public static void insertAccount(List<Account> accList) {
        if (accList == null || accList.isEmpty()) {
            return; // Avoid unnecessary operations
        }

        // Check field update permissions before modifying records
        for (Account acc : accList) {
            if (Schema.sObjectType.Account.fields.Description.isUpdateable() &&
                Schema.sObjectType.Account.fields.Rating.isUpdateable() &&
                Schema.sObjectType.Account.fields.Industry.isUpdateable()) {

                acc.Description = 'Happy Welcome to';
                acc.Rating = 'Hotter';
                acc.Industry = 'Agriculture';
            }
        }

        // Validate insert permissions before performing DML
        if (Schema.sObjectType.Account.isInsertable()) {
            try {
                insert accList;
            } catch (Exception e) {
                // Log error for debugging without impacting performance
                System.debug(LoggingLevel.ERROR, 'Error inserting Accounts: ' + e.getMessage());
            }
        }
    }
}
