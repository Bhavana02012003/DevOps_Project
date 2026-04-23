/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-23-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
global class Demo { 

    // 🛑 TRIGGER: FieldNamingConventions (Variables should be camelCase)
    public String BAD_NAMING_CONVENTION = 'Static Test String';
    private Integer constant_Value_Not_caps = 42;

    // ----------------------------------------------------------------------
    // Method 1: The Database Nightmare
    // ----------------------------------------------------------------------
    // 🛑 TRIGGER: ExcessiveParameterList (5 parameters)
    public void processMassiveData(String param1, String param2, String param3, String param4, String param5) { 
        // 🛑 TRIGGER: AvoidDebugStatements
        System.debug('Starting heavy processing...'); 

        // 🛑 TRIGGER: OperationWithLimitsInLoop (SOQL inside a loop)
        // 🛑 TRIGGER: OperationWithLimitsInLoop (DML inside a loop)
        // 🛑 TRIGGER: AvoidHardcodingId (Using a hardcoded 15-char ID)
        for (Integer i = 0; i < 5; i++) {
            Account acc = [SELECT Id, Name FROM Account WHERE Id = '001D000000IRt53' LIMIT 1];
            acc.Name = acc.Name + ' Updated';
            update acc; 
        }

        // 🛑 TRIGGER: ApexSOQLInjection (Dynamic SOQL without escaping/binding)
        // 🛑 TRIGGER: ApexCRUDViolation (No WITH SECURITY_ENFORCED)
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

    // ----------------------------------------------------------------------
    // Method 2: The Complexity Monster
    // ----------------------------------------------------------------------
    // 🛑 TRIGGER: AvoidDeeplyNestedIfStmts
    // 🛑 TRIGGER: CyclomaticComplexity 
    // 🛑 TRIGGER: CognitiveComplexity
    public String nestedNightmare(Integer score, String type, Boolean isActive, Boolean hasHistory, String region) {
        String result = 'Unknown';

        if (isActive) {
            if (score > 100) {
                if (type == 'Premium') {
                    if (score > 500) {
                        if (hasHistory) {
                            result = 'Ultra VIP with History';
                        } else {
                            result = 'Ultra VIP';
                        }
                    } else {
                        result = 'VIP';
                    }
                } else {
                    if (region == 'NA' || region == 'EU') {
                        result = 'Standard High Tier 1';
                    } else {
                        result = 'Standard High Tier 2';
                    }
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
    // Method 3: Bad Naming & Empty Statements
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
    // Method 4: Missing Assertions & Unused Variables
    // ----------------------------------------------------------------------
    public void testVariableUsage() {
        // 🛑 TRIGGER: UnusedLocalVariable
        String unusedString = 'I am never used'; 
        Integer anotherUnused = 42; 
        
        System.debug('I am doing nothing with those variables.');
    }

    // ----------------------------------------------------------------------
    // Method 5: A Valid, Clean Method (To balance things out)
    // ----------------------------------------------------------------------
    public List<Opportunity> getClosedWonOpportunities(Id accountId) {
        if (accountId == null) {
            return new List<Opportunity>();
        }
        
        // Clean SOQL with bind variables and security enforced
        return [
            SELECT Id, Name, Amount, CloseDate 
            FROM Opportunity 
            WHERE AccountId = :accountId 
              AND StageName = 'Closed Won' 
            WITH SECURITY_ENFORCED
        ];
    }

    // ----------------------------------------------------------------------
    // Method 6: High Cost Operations in Loops
    // ----------------------------------------------------------------------
    public void highCostOperations() {
        List<Account> accs = [SELECT Id FROM Account LIMIT 10 WITH SECURITY_ENFORCED];
        
        // 🛑 TRIGGER: OperationWithHighCostInLoop (Schema describe inside a loop)
        for (Account a : accs) {
            Schema.DescribeSObjectResult describeResult = Account.sObjectType.getDescribe();
            System.debug(describeResult.getName());
        }
    }

    // ----------------------------------------------------------------------
    // Method 7: Large Switch Statement
    // ----------------------------------------------------------------------
    // Contributes to overall class Cyclomatic Complexity
    public String analyzeStatus(Integer statusCode) {
        String description;
        switch on statusCode {
            when 100 { description = 'Continue'; }
            when 200 { description = 'OK'; }
            when 201 { description = 'Created'; }
            when 202 { description = 'Accepted'; }
            when 400 { description = 'Bad Request'; }
            when 401 { description = 'Unauthorized'; }
            when 403 { description = 'Forbidden'; }
            when 404 { description = 'Not Found'; }
            when 500 { description = 'Internal Server Error'; }
            when else { description = 'Unknown Status'; }
        }
        return description;
    }
    
    // ----------------------------------------------------------------------
    // Method 8: Unused Private Method
    // ----------------------------------------------------------------------
    // 🛑 TRIGGER: UnusedMethod 
    private void secretMethod() {
        System.debug('Shh, I am a secret');
    }
}
