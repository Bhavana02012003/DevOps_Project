/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-23-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class Demo { 
    
    // Completely new method handling Opportunities
    public void processOpportunities(List<Opportunity> oppList) {
        if (oppList == null || oppList.isEmpty()) {
            return;
        }
        
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for (Opportunity opp : oppList) {
            if (opp.StageName == 'Prospecting') {
                opp.Description = 'Newly processed prospect.';
                oppsToUpdate.add(opp);
            }
        }
        
        if (!oppsToUpdate.isEmpty()) {
            // SECURITY NOTE: In a real scenario, check CRUD/FLS before updating.
            update oppsToUpdate;
        }
    }
    
    // Intentional minor PMD violation: AvoidDebugStatements (to test if the scanner catches it on a new line)
    public String generateGreeting(String name) {
        System.debug('Generating greeting for: ' + name); 
        
        // Intentional minor PMD violation: IfStmtsMustUseBraces
        if (String.isBlank(name)) return 'Hello, Guest!';
        
        return 'Hello, ' + name + '!';
    }
    
    // A clean, recursive math method just to round out the class
    public Integer calculateFactorial(Integer n) {
        if (n <= 1) {
            return 1;
        }
        return n * calculateFactorial(n - 1);
    }
}
