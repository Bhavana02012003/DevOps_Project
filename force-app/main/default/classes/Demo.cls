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

        // Validate insert permissions before performing DML
        if (!Schema.sObjectType.Account.isInsertable()) {
            throw new SecurityException('User does not have insert permission on Account object.');
        }

        List<Account> validAccounts = new List<Account>();

        for (Account acc : accList) {
            if (Schema.sObjectType.Account.fields.Description.isUpdateable() &&
                Schema.sObjectType.Account.fields.Rating.isUpdateable() &&
                Schema.sObjectType.Account.fields.Industry.isUpdateable()) {

                acc.Description = 'Happy Welcome to';
                acc.Rating = 'Hotter';
                acc.Industry = 'Agriculture';
                validAccounts.add(acc); // Add only valid accounts
            }
        }

        if (!validAccounts.isEmpty()) {
            try {
                insert validAccounts;
            } catch (DmlException e) {
                // Log error safely without impacting performance
                System.enqueueJob(new AsyncLogger(LoggingLevel.ERROR, 'Error inserting Accounts: ' + e.getMessage()));
            }
        }
    }
}

/**
 * @description Asynchronous Logger to handle logging without performance impact.
 */
public class AsyncLogger implements Queueable {
    private LoggingLevel logLevel;
    private String message;

    public AsyncLogger(LoggingLevel logLevel, String message) {
        this.logLevel = logLevel;
        this.message = message;
    }

    public void execute(QueueableContext context) {
        System.debug(logLevel, message);
        System.debug('Testing');
    }
}
