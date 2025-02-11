public with sharing class Demo {
    
    @FakeAnnotation
    public void someMethod() {
        // Hardcoded ID - This violates the AvoidHardcodingId rule
        String accountId = '001ABC123456789';
        
        Account acc = [SELECT Id, Name FROM Account WHERE Id = :accountId LIMIT 1];
        System.debug('Account Name: ' + acc.Name);
        System.debug('Testing');
    }
}
