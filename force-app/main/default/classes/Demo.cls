public with sharing class Demo {
    @AuraEnabled
   public static Account createAccount(Account acc){
       System.debug('Hi');
    try {
        System.debug('Hi Welcome this is for testing');
        insert acc;
        return acc;
    } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
    }
}
}