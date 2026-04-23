/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-23-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class Demo { 

    // 🛑 TRIGGER: FieldNamingConventions (Variables should be camelCase)
    public String BAD_NAMING_CONVENTION = 'Static Test String';

    // 🛑 TRIGGER: ExcessiveParameterList (More than 4 parameters)
    public void processMassiveData(String param1, String param2, String param3, String param4, String param5) {
        
        // 🛑 TRIGGER: AvoidDebugStatements
        System.debug('Starting heavy processing...');

        // 🛑 TRIGGER: OperationWithLimitsInLoop (SOQL inside a loop)
        // 🛑 TRIGGER: AvoidHardcodingId (Using a hardcoded 15-char ID)
        for (Integer i = 0; i < 5; i++) {
            Account acc = [SELECT Id, Name FROM Account WHERE Id = '001D000000IRt53' LIMIT 1];
        }

        // 🛑 TRIGGER: ApexSOQLInjection (Dynamic SOQL without escaping/binding)
        // 🛑 TRIGGER: ApexCRUDViolation / ApexSharingViolations (No WITH SECURITY_ENFORCED)
        String dynamicQuery = 'SELECT Id, Name FROM Contact WHERE Name LIKE \'%' + param1 + '%\'';
        List<Contact> contacts = Database.query(dynamicQuery);

        try {
            // 🛑 TRIGGER: IfStmtsMustUseBraces (Single-line if statements without {})
            if (contacts.size() > 0) 
                update contacts;

        } catch (Exception e) {
            // 🛑 TRIGGER: EmptyCatchBlock (Silently swallowing exceptions)
        }
    }

    // 🛑 TRIGGER: AvoidDeeplyNestedIfStmts
    // 🛑 TRIGGER: CyclomaticComplexity / CognitiveComplexity
    public String nestedNightmare(Integer score, String type, Boolean isActive) {
        String result = 'Unknown';

        if (isActive) {
            if (score > 100) {
                if (type == 'Premium') {
                    if (score > 500) {
                        result = 'Ultra VIP';
                    } else {
                        result = 'VIP';
                    }
                } else {
                    result = 'Standard High';
                }
            } else {
                result = 'Active Low';
            }
        } else {
            result = 'Inactive';
        }

        return result;
    }
}
