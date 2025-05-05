public with sharing class SampleTest {
    public void print(Integer num){
        System.debug('Hello');
        if(num>5){
            System.debug('Greater 5');
        }
    }
    public void hardCodedIdMethod() {
        String hardcodedId = '0019000000XXXXXXX';  // Violates AvoidHardcodingId
        // Account acc = [SELECT Id, Name FROM Account WHERE Id = :hardcodedId WITH SECURITY_ENFORCED];
        Account acc = [SELECT Id, Name FROM Account WHERE Id = :hardcodedId];
        System.debug('Accounts'+acc);
   } 
}