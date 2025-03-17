public with sharing class ScannerReportHandler {
    private static Set<Id> processedDocumentIds = new Set<Id>();

    public static void processFiles(Set<Id> contentDocumentIds) {
        System.debug('🔍 Processing Scanner Report Files for ContentDocumentIds: ' + contentDocumentIds);

        if (contentDocumentIds.isEmpty()) {
            System.debug('⚠️ No ContentDocumentIds provided. Skipping processing.');
            return;
        }

        // Prevent recursive trigger execution
        Set<Id> newDocumentsToProcess = new Set<Id>();
        for (Id docId : contentDocumentIds) {
            if (!processedDocumentIds.contains(docId)) {
                newDocumentsToProcess.add(docId);
            }
        }

        if (newDocumentsToProcess.isEmpty()) {
            System.debug('⚠️ All ContentDocumentIds have already been processed. Skipping.');
            return;
        }

        processedDocumentIds.addAll(newDocumentsToProcess);

        // Fetch ContentVersion records for processing
        List<ContentVersion> contentVersions = [ 
            SELECT Id, ContentDocumentId, Title, VersionData 
            FROM ContentVersion 
            WHERE ContentDocumentId IN :newDocumentsToProcess
        ];

        if (contentVersions.isEmpty()) {
            System.debug('⚠️ No matching ContentVersion records found.');
            return;
        }

        List<Case> casesToInsert = new List<Case>();
        Map<Id, String> caseFileMapping = new Map<Id, String>();

        for (ContentVersion cv : contentVersions) {
            if (cv.Title.contains('Code Scanner') || cv.Title.contains('Code Scanner Delta')) {
                Case newCase = new Case();
                newCase.ContentDocumentId__c = cv.ContentDocumentId;
                newCase.File_Name__c = cv.Title;
                newCase.Status = 'New';
                casesToInsert.add(newCase);

                caseFileMapping.put(cv.ContentDocumentId, cv.Title);
            }
        }

        if (!casesToInsert.isEmpty()) {
            insert casesToInsert;
            System.debug('✅ Inserted ' + casesToInsert.size() + ' new Case records.');

            // Step 2: Link files to the newly created cases
            List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();

            for (Case createdCase : casesToInsert) {
                System.debug('📂 Case Created: ' + createdCase.Id + ' | File: ' + createdCase.File_Name__c);

                // Check if ContentDocumentLink already exists
                List<ContentDocumentLink> existingLinks = [
                    SELECT Id FROM ContentDocumentLink 
                    WHERE LinkedEntityId = :createdCase.Id 
                    AND ContentDocumentId = :createdCase.ContentDocumentId__c
                ];

                if (existingLinks.isEmpty()) {
                    ContentDocumentLink link = new ContentDocumentLink();
                    link.ContentDocumentId = createdCase.ContentDocumentId__c;
                    link.LinkedEntityId = createdCase.Id;
                    link.ShareType = 'V'; // Viewer access
                    link.Visibility = 'AllUsers';

                    linksToInsert.add(link);
                } else {
                    System.debug('⚠️ File already linked to this Case. Skipping.');
                }
            }

            if (!linksToInsert.isEmpty()) {
                insert linksToInsert;
                System.debug('✅ Successfully linked files to Case records.');
            }
        } else {
            System.debug('ℹ️ No new Cases to insert.');
        }
    }
}
