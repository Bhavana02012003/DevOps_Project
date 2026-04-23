/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-23-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class Demo1 {

    // 🛑 TRIGGER: ExcessiveParameterList (5 parameters)
    public void dummyTestProcess() {
        
        // This variable is declared but never actually used
        String unusedDummyVar = 'Just taking up space'; 
        
        try {
            // Querying with a hardcoded 15/18 character ID is a security/best-practice violation
            Account dummyAcc = [SELECT Id, Name FROM Account WHERE Id = '001000000000000AAA' WITH SECURITY_ENFORCED];
            
            // 🛑 TRIGGER: DebugsShouldUseLoggingLevel
            System.debug('Found accossunt: ' + dummyAcc.Name);
            
        } catch (Exception e) {
            // 🛑 TRIGGER: EmptyCatchBlock (Silently swallowing the exception)
            }
        }
        
        // 🛑 TRIGGER: ApexSOQLInjection (Using unprotected dynamic SOQL string)
        String query = 'SELECT Id, Name FROM Lead WHERE Company = \'' + paramB + '\'';
        List<Lead> leads = Database.query(query);
        
        if (leads.size() > 0) {
            delete leads;
        }
    }
}