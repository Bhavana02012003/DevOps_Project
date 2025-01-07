public with sharing class Demo {
    @AuraEnabled
   public static Account createAccount(Account acc){
       System.debug('Hello');
    try {
        System.debug('Hi Welcome to demo apex class  ');
        insert acc;
        return acc;
    } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
    }
}
}