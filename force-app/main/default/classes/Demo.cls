/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-22-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class Demo { 
    // Fixed: AvoidGlobalModifier -> Changed to 'public'
 
    // Fixed: ExcessiveParameterList -> Passed a List of strings instead of 5 individual parameters
    public void processParameters(List<String> paramsList) { 
        if (paramsList == null || paramsList.isEmpty()) {
            return;
        }
        for (String param : paramsList) {
            System.debug('Parameter: ' + param);
        }
        System.debug('Clean Parameters Testing!!');
    }

    // Fixed: AvoidHardcodingId -> Changed to accept a proper Id parameter and added SECURITY_ENFORCED
    public void queryAccountById(Id accountId) {
        if (accountId != null) {
            Account acc = [SELECT Id, Name FROM Account WHERE Id = :accountId WITH SECURITY_ENFORCED];
            System.debug('Account: ' + acc);
        }
    } 

    // Fixed: AvoidDeeplyNestedIfStmts -> Flattened logic using guard clauses
    public void flattenedIfMethod(Integer value) {  
        if (value <= 30) {
            System.debug('Value is 30 or less. Exiting early.');
            return;
        }
        
        System.debug('Passed initial thresholds Testing!!');
        
        if (value > 40) {
            System.debug('Value is greater than 40 Testing!!');
        } else {
            System.debug('Value is between 31 and 40');
        }
    }

    public void sampleTestMethod(Integer num) { 
        if (num > 5) {
            System.debug('Num is greater than 5');
        }
        System.debug('Testing new method Bro');
    }

    // Fixed: ApexSOQLInjection -> Utilized bind variables for the dynamic query
    public void secureSoqlQuery(String userInput) {  
        String searchString = '%' + userInput + '%';
        List<Account> accounts = [SELECT Id, Name FROM Account WHERE Name LIKE :searchString WITH SECURITY_ENFORCED];
        System.debug(accounts);
    }
}
