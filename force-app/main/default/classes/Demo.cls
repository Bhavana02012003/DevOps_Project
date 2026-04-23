/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-23-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class Demo {
    
    public void processLegacyData() {
        // 🛑 TRIGGER: AvoidDebugStatements
        System.debug('Processingdsd legacy data updates...');
        
        List<Account> accountsToUpdate = [SELECT Id, Name FROM Account WITH SECURITY_ENFORCED LIMIT 10];
        
        if (accountsToUpdate.isEmpty()) {
            // 🛑 TRIGGER: EmptyStatementBlock (This is an empty if-block)
        } else {
            for (Account acc : accountsToUpdate) {
                acc.Name = acc.Name + ' - Processed';
            }
            // SECURITY ENFORCED is used above, but we still lack a check before update
            update accountsToUpdate;
        }
    }
}
