/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-23-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class Demo {
    
    public void triggerParseError() {
        // 🛑 TRIGGER: AvoidDebugStatements (PMD won't see this yet!)
        System.debug('Preparing to run the fatally broken SOQL query...');
        
        // 🛑 THE FATAL SYNTAX ERROR: WITH SECURITY_ENFORCED is in the wrong place.
        // This will cause the PMD AST Parser to crash and return 0 violations.
        List<Contact> badQueryList = [SELECT Id, Name, Email FROM Contact LIMIT 50 WITH SECURITY_ENFORCED];
        
        // 🛑 TRIGGER: EmptyIfStmt (PMD won't see this yet!)
        if (badQueryList.size() > 0) {
            // Doing absolutely nothing here
        }
    }
    
    public void standardViolations(Integer a, Integer b) {
        // 🛑 TRIGGER: IfStmtsMustUseBraces (PMD won't see this yet!)
        if (a > b) System.debug('A is greater than B');
    }
}
