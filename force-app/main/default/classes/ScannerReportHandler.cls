/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 02-19-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class ScannerReportHandler {

    private static Boolean isProcessing = false; // Prevent recursive execution
 
    @future

    public static void processFiles(Set<Id> contentDocumentIds) {

        if (isProcessing) {

            System.debug('⚠️ Process already running. Skipping to prevent recursion.');

            return;

        }
 
        isProcessing = true;
 
        System.debug('🔍 Processing Scanner Report Files for ContentDocumentIds: ' + contentDocumentIds);
 
        if (contentDocumentIds.isEmpty()) {

            isProcessing = false;

            return;

        }
 
        List<ContentVersion> contentVersions = [ 

            SELECT Id, ContentDocumentId, Title, PathOnClient 

            FROM ContentVersion 

            WHERE ContentDocumentId IN :contentDocumentIds

        ];
 
        if (contentVersions.isEmpty()) {

            isProcessing = false;

            return;

        }
 
        List<Case> casesToInsert = new List<Case>();

        Map<Id, Id> caseToFileMap = new Map<Id, Id>();
 
        for (ContentVersion cv : contentVersions) {

            if (cv.Title != null && cv.Title.toLowerCase().contains('code scanner')) {

            Case newCase = new Case();   // ✅ MISSING LINE (VERY IMPORTANT)

            newCase.Subject = 'Scanner Report - ' + cv.Title;
            newCase.Origin = 'Web';
            newCase.Status = 'New';
            newCase.File_Name__c = cv.Title;

            try {
                ContentVersion cvWithData = [SELECT VersionData FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

                Blob csvBlob = cvWithData.VersionData;
                String csvContent = csvBlob.toString();

                List<String> csvLines = csvContent.split('\n');

                if (csvLines.size() > 1) {

                    String headerLine = csvLines[0];
                    List<String> headers = headerLine.split(',');

                    Integer targetBranchIndex = headers.indexOf('TargetBranch');
                    Integer commitIndex = headers.indexOf('Commit');
                    Integer severityIndex = headers.indexOf('Severity');

                    Boolean setPriority = false;

                    for (Integer i = 1; i < csvLines.size(); i++) {

                        List<String> values = csvLines[i].split(',');

                        if (targetBranchIndex != -1 && values.size() > targetBranchIndex) {
                            newCase.Target_Environment__c = values[targetBranchIndex].trim();
                        }

                        if (commitIndex != -1 && values.size() > commitIndex) {
                            newCase.Case_Created_By__c = values[commitIndex].trim();
                        }

                        if (!setPriority && severityIndex != -1 && values.size() > severityIndex) {

                            String severityValue = values[severityIndex].trim();

                            if (severityValue == '1' || severityValue == '2') {
                                newCase.Priority = 'High';
                                setPriority = true;
                            } else if (severityValue == '3') {
                                newCase.Priority = 'Medium';
                                setPriority = true;
                            } else if (severityValue == '4' || severityValue == '5') {
                                newCase.Priority = 'Low';
                                setPriority = true;
                            }
                        }

                        if ((newCase.Target_Environment__c != null || newCase.Case_Created_By__c != null) && setPriority) {
                            break;
                        }
                    }
                }

            } catch (Exception e) {
                System.debug('❌ Error reading CSV content: ' + e.getMessage());
            }

            casesToInsert.add(newCase);
            caseToFileMap.put(cv.ContentDocumentId, null);
        }
                }
 
        if (!casesToInsert.isEmpty()) {

            try {

                insert casesToInsert;
 
                Integer i = 0;

                for (ContentVersion cv : contentVersions) {

                    if (cv.Title != null && cv.Title.toLowerCase().contains('code scanner')) {

                        Case createdCase = casesToInsert[i];
                        caseToFileMap.put(cv.ContentDocumentId, createdCase.Id);
                        i++;
                    }
                }
 
            } catch (DmlException e) {

                System.debug('❌ Error inserting Cases: ' + e.getMessage());

                isProcessing = false;

                return;

            }

        } else {

            isProcessing = false;

            return;

        }
 
        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
 
        for (Id contentDocId : caseToFileMap.keySet()) {

            Id caseId = caseToFileMap.get(contentDocId);
 
            if (caseId != null) {

                List<ContentDocumentLink> existingLinks = [

                    SELECT Id FROM ContentDocumentLink 

                    WHERE LinkedEntityId = :caseId 

                    AND ContentDocumentId = :contentDocId

                ];
 
                if (existingLinks.isEmpty()) {

                    ContentDocumentLink link = new ContentDocumentLink();

                    link.ContentDocumentId = contentDocId;

                    link.LinkedEntityId = caseId;

                    link.ShareType = 'V';

                    link.Visibility = 'AllUsers';
 
                    linksToInsert.add(link);

                }

            }

        }
 
        if (!linksToInsert.isEmpty()) {

            try {

                insert linksToInsert;

            } catch (DmlException e) {

                System.debug('❌ Error linking files to Case: ' + e.getMessage());

            }

        }
 
        // 🔗 Link file to Case done above

        isProcessing = false;

        // ✅ NOW call File processor
        if (!caseToFileMap.isEmpty()) {
            File.processNewContentDocuments(contentDocumentIds);
        }

    }

}