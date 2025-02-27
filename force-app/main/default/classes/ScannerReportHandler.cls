public with sharing class ScannerReportHandler {
    public static void processFiles(Set<Id> documentIds) {
        try {
            // Fetch the latest ContentVersion associated with the ContentDocuments
            List<ContentVersion> files = [SELECT Id, VersionData, ContentDocumentId
                                          FROM ContentVersion
                                          WHERE ContentDocumentId IN :documentIds
                                          ORDER BY CreatedDate DESC];

            for (ContentVersion file : files) {
                // Convert Blob to String
                String csvContent = file.VersionData.toString();
                
                // Parse CSV and create Cases
                createCasesFromCSV(csvContent, file.ContentDocumentId);
            }
        } catch (Exception e) {
            System.debug('Error processing scanner report:: ' + e.getMessage());
        }
    }

    private static void createCasesFromCSV(String csvContent, Id documentId) {
        List<Case> caseList = new List<Case>();
        List<String> lines = csvContent.split('\n');

        for (Integer i = 1; i < lines.size(); i++) { // Skipping header row
            List<String> values = lines[i].split(',');

            if (values.size() < 6) continue; // Ensure enough columns exist

            Case newCase = new Case();
            newCase.Subject = 'Scanner Report Violation: ' + values[0]; // Problem Column
            newCase.Description = 'Severity: ' + values[1] +
                                  '\nFile: ' + values[2] +
                                  '\nLine: ' + values[3] +
                                  '\nRule: ' + values[4] +
                                  '\nDescription: ' + values[5];
            newCase.Priority = values[1] == 'High' ? 'High' : 'Medium'; // Map Severity to Case Priority
            newCase.Status = 'New';
            newCase.Origin = 'Automation';
            newCase.Scanner_Report_File_ID__c = documentId; // Store the file ID as a reference

            caseList.add(newCase);
        }

        if (!caseList.isEmpty()) {
            insert caseList;
        }
    }
}
