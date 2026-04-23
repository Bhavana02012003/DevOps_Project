/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-23-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class Demo1 {

    // 🛑 TRIGGER: ExcessiveParameterList (5 parameters)
    public void executeNewProcess(String paramA, String paramB, String paramC, String paramD, String paramE) {
        
        // 🛑 TRIGGER: OperationWithLimitsInLoop (DML inside a loop)
        for (Integer i = 0; i < 5; i++) {
            Contact newContact = new Contact(
                LastName = 'Test Contact ' + i,
                Description = paramA
            );
            insert newContact; 
        }
        
        // 🛑 TRIGGER: ApexSOQLInjection (Using unprotected dynamic SOQL string)
        String query = 'SELECT Id, Name FROM Lead WHERE Company = \'' + paramB + '\'';
        List<Lead> leads = Database.query(query);
        
        if (leads.size() > 0) {
            delete leads;
        }
    }
}