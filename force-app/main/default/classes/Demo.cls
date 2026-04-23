/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-23-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class Demo {
    
    // --- CONSTANTS ---
    private static final String STATUS_ACTIVE = 'Active';
    private static final String STATUS_ESCALATED = 'Escalated';
    private static final Integer MAX_RETRY_ATTEMPTS = 3;

    // --- WRAPPER CLASSES ---
    public class IntegrationPayload {
        public String externalId;
        public String customerName;
        public Decimal totalRevenue;
        public Boolean isPremium;
    }

    // --- METHOD 1: Bulkified Account Processing ---
    public void processAccountsInBulk(List<Account> accountsToProcess) {
        if (accountsToProcess == null || accountsToProcess.isEmpty()) {
            return;
        }

        List<Account> accountsToUpdate = new List<Account>();
        for (Account acc : accountsToProcess) {
            if (acc.AnnualRevenue > 1000000) {
                acc.Rating = 'Hot';
                acc.Type = 'Enterprise Customer';
                accountsToUpdate.add(acc);
            } else if (acc.AnnualRevenue > 500000) {
                acc.Rating = 'Warm';
                acc.Type = 'Mid-Market';
                accountsToUpdate.add(acc);
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            try {
                // Secure DML check
                if (Schema.sObjectType.Account.isUpdateable()) {
                    Database.SaveResult[] srList = Database.update(accountsToUpdate, false);
                    logSaveResults(srList);
                }
            } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR, 'DML Exception occurred: ' + e.getMessage());
            }
        }
    }

    // --- METHOD 2: Dynamic SOQL with Bind Variables ---
    public List<Contact> searchContactsDynamically(String searchTerm, String departmentFilter) {
        String searchKey = '%' + searchTerm + '%';
        String query = 'SELECT Id, FirstName, LastName, Email, Department FROM Contact WHERE LastName LIKE :searchKey';
        
        if (String.isNotBlank(departmentFilter)) {
            query += ' AND Department = :departmentFilter';
        }
        
        query += ' WITH SECURITY_ENFORCED LIMIT 100';
        
        return Database.query(query);
    }

    // --- METHOD 3: Complex Business Logic (High Cognitive Complexity) ---
    public String evaluateCustomerTier(Integer loyaltyPoints, Decimal lifetimeValue, Boolean hasActiveContract, Integer openCases) {
        String finalTier = 'Standard';

        // Intentional deep nesting for PMD AvoidDeeplyNestedIfStmts testing
        if (hasActiveContract) {
            if (lifetimeValue > 50000) {
                if (loyaltyPoints > 10000) {
                    if (openCases == 0) {
                        finalTier = 'Platinum Elite';
                    } else {
                        finalTier = 'Platinum';
                    }
                } else {
                    finalTier = 'Gold';
                }
            } else {
                if (loyaltyPoints > 5000) {
                    finalTier = 'Silver';
                }
            }
        } else {
            if (lifetimeValue > 100000) {
                finalTier = 'Win-back Target';
            }
        }

        return finalTier;
    }

    // --- METHOD 4: Mock Callout Logic ---
    public HttpResponse syncCustomerDataToERP(IntegrationPayload payload) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:My_ERP_Named_Credential/api/v1/customers');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        
        String jsonBody = JSON.serialize(payload);
        request.setBody(jsonBody);
        
        HttpResponse response = new HttpResponse();
        
        try {
            response = http.send(request);
            if (response.getStatusCode() == 200) {
                // Success logic
                System.debug(LoggingLevel.INFO, 'Sync Successful');
            } else {
                // Failure logic
                System.debug(LoggingLevel.WARN, 'Sync Failed with status: ' + response.getStatusCode());
            }
        } catch (CalloutException ce) {
            // Intentional empty catch block for PMD EmptyCatchBlock testing
        }
        
        return response;
    }

    // --- METHOD 5: Opportunity Aggregation (Loops and Maps) ---
    public Map<Id, Decimal> calculateTotalPipelineByAccount(List<Opportunity> openOpportunities) {
        Map<Id, Decimal> pipelineMap = new Map<Id, Decimal>();
        
        for (Opportunity opp : openOpportunities) {
            if (opp.AccountId != null && opp.Amount != null && !opp.IsClosed) {
                if (pipelineMap.containsKey(opp.AccountId)) {
                    Decimal currentTotal = pipelineMap.get(opp.AccountId);
                    pipelineMap.put(opp.AccountId, currentTotal + opp.Amount);
                } else {
                    pipelineMap.put(opp.AccountId, opp.Amount);
                }
            }
        }
        
        return pipelineMap;
    }

    // --- METHOD 6: Case Escalation Engine ---
    public void processCaseEscalations(List<Id> caseIds) {
        List<Case> casesToEscalate = [
            SELECT Id, Status, Priority, CreatedDate 
            FROM Case 
            WHERE Id IN :caseIds AND Status != :STATUS_ESCALATED 
            WITH SECURITY_ENFORCED
        ];

        List<Case> updates = new List<Case>();
        for (Case c : casesToEscalate) {
            if (c.Priority == 'High' && c.CreatedDate < Datetime.now().addHours(-4)) {
                c.Status = STATUS_ESCALATED;
                c.IsEscalated = true;
                updates.add(c);
            }
        }

        if (!updates.isEmpty() && Schema.sObjectType.Case.isUpdateable()) {
            update updates;
        }
    }

    // --- METHOD 7: Utility / Helper Method ---
    private void logSaveResults(Database.SaveResult[] results) {
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                for(Database.Error err : sr.getErrors()) {
                    System.debug(LoggingLevel.ERROR, 'The following error has occurred.');                    
                    System.debug(LoggingLevel.ERROR, err.getStatusCode() + ': ' + err.getMessage());
                    System.debug(LoggingLevel.ERROR, 'Fields that affected this error: ' + err.getFields());
                }
            }
        }
    }

    // --- METHOD 8: Data Cleansing (Deleting old records) ---
    public void purgeOldLeads(Integer daysOld) {
        Datetime cutoffDate = Datetime.now().addDays(-daysOld);
        
        // Using a safe query to find un-converted leads older than X days
        List<Lead> staleLeads = [
            SELECT Id 
            FROM Lead 
            WHERE CreatedDate < :cutoffDate AND IsConverted = false 
            WITH SECURITY_ENFORCED 
            LIMIT 500
        ];
        
        if (!staleLeads.isEmpty() && Schema.sObjectType.Lead.isDeletable()) {
            try {
                delete staleLeads;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Failed to purge leads: ' + e.getMessage());
            }
        }
    }
}
