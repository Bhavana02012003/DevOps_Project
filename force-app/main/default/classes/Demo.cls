/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-23-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
global class Demo { // 🛑 TRIGGER: AvoidGlobalModifier

    // 🛑 TRIGGER: FieldNamingConventions (Variables should be camelCase)
    public String BAD_NAMING_CONVENTION = 'Static Test String';

    // ----------------------------------------------------------------------
    // Method 1: The ParseException Trap
    // ----------------------------------------------------------------------
    public void triggerParseError() {
        // 🚨 FATAL SYNTAX ERROR: WITH SECURITY_ENFORCED is after LIMIT.
        // This crashes the AST parser. PMD will stop reading here!
        List<Account> crashList = [SELECT Id, Name FROM Account LIMIT 100 WITH SECURITY_ENFORCED];
    }

    // ----------------------------------------------------------------------
    // Method 2: The DML and SOQL Looper
    // ----------------------------------------------------------------------
    // 🛑 TRIGGER: ExcessiveParameterList (5 parameters)
    public void processMassiveData(String param1, String param2, String param3, String param4, String param5) { 
        // 🛑 TRIGGER: AvoidDebugStatements
        // 🛑 TRIGGER: DebugsShouldUseLoggingLevel
        System.debug('Starting heavy processing...'); 

        // 🛑 TRIGGER: OperationWithLimitsInLoop (SOQL inside a loop)
        // 🛑 TRIGGER: AvoidHardcodingId (Using a hardcoded 15-char ID)
        for (Integer i = 0; i < 5; i++) {
            Account acc = [SELECT Id, Name FROM Account WHERE Id = '001D000000IRt53' WITH SECURITY_ENFORCED LIMIT 1];
            acc.Name = acc.Name + ' Updated';
            
            // 🛑 TRIGGER: OperationWithLimitsInLoop (DML inside a loop)
            update acc; 
        }

        // 🛑 TRIGGER: ApexSOQLInjection (Dynamic SOQL without escaping/binding)
        // 🛑 TRIGGER: ApexCRUDViolation (No WITH SECURITY_ENFORCED)
        String dynamicQuery = 'SELECT Id, Name FROM Contact WHERE Name LIKE \'%' + param1 + '%\'';
        List<Contact> contacts = Database.query(dynamicQuery);

        try {
            // 🛑 TRIGGER: IfStmtsMustUseBraces (Single-line if statements without {})
            if (contacts.size() > 0)
                delete contacts;

        } catch (Exception e) {
            // 🛑 TRIGGER: EmptyCatchBlock (Silently swallowing exceptions)
        }
    }

    // ----------------------------------------------------------------------
    // Method 3: The Complexity Monster
    // ----------------------------------------------------------------------
    // 🛑 TRIGGER: AvoidDeeplyNestedIfStmts
    // 🛑 TRIGGER: CyclomaticComplexity 
    // 🛑 TRIGGER: CognitiveComplexity
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
                    result = 'Standard High Tier 1';
                }
            } else {
                result = 'Active Low';
            }
        } else {
            result = 'Inactive';
        }

        return result;
    }

    // ----------------------------------------------------------------------
    // Method 4: Bad Naming & Empty Statements
    // ----------------------------------------------------------------------
    // 🛑 TRIGGER: MethodNamingConventions
    public void bad_Method_Name() { 
        // 🛑 TRIGGER: LocalVariableNamingConventions
        Integer Local_Var_Bad = 10; 

        // 🛑 TRIGGER: EmptyIfStmt
        if (Local_Var_Bad > 5) {
            // Do nothing
        }

        // 🛑 TRIGGER: WhileLoopsMustUseBraces
        while (Local_Var_Bad < 15) Local_Var_Bad++;
    }

    // ----------------------------------------------------------------------
    // Method 5: Unused Variables and Methods
    // ----------------------------------------------------------------------
    public void testVariableUsage() {
        // 🛑 TRIGGER: UnusedLocalVariable
        String unusedString = 'I am never used'; 
        Integer anotherUnused = 42; 
    }

    // 🛑 TRIGGER: UnusedMethod 
    private void secretMethod() {
        System.debug('Shh, I am a secret');
    }
}
