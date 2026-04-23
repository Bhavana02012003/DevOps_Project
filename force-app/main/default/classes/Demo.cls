/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-23-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class Demo {
    
    public void triggerParseError() {
        // 🛑 TRIGGER: AvoidDebugStatements (PMD will catch this now!)
        System.debug('Preparing to run the valid SOQL query...');
        
        // ✅ THE FIX: WITH SECURITY_ENFORCED is now before LIMIT.
        // PMD will successfully parse this and move on to find the other violations.
        List<Contact> badQueryList = [SELECT Id, Name, Email FROM Contact WITH SECURITY_ENFORCED LIMIT 50];
        
        // 🛑 TRIGGER: EmptyIfStmt (PMD will catch this now!)
        if (badQueryList.size() > 0) {
            // Doing absolutely nothing here
        }
    }
    
    public void standardViolations(Integer a, Integer b) {
        // 🛑 TRIGGER: IfStmtsMustUseBraces (PMD will catch this now!)
        if (a > b) System.debug('A is greater than B');
    }
}
