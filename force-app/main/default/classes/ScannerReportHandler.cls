public with sharing class ScannerReportHandler {
    private static Boolean isProcessing = false; // Prevent recursive execution

    @future
    public static void processFiles(Set<Id> contentDocumentIds) {
        if (isProcessing) {
            System.debug('⚠️ Process already running. Skipping to prevent recursion.');
            return;
        }

        isProcessing = true; // Set flag to prevent recursion

        System.debug('🔍 Processing Scanner Report Files for ContentDocumentIds: ' + contentDocumentIds);

        if (contentDocumentIds.isEmpty()) {
            System.debug('⚠️ No ContentDocumentIds provided. Skipping processing.');
            isProcessing = false;
            return;
        }

        // Fetch ContentVersion records for processing
        List<ContentVersion> contentVersions = [ 
            SELECT Id, ContentDocumentId, Title, VersionData 
            FROM ContentVersion 
            WHERE ContentDocumentId IN :contentDocumentIds
        ];

        if (contentVersions.isEmpty()) {
            System.debug('⚠️ No matching ContentVersion records found.');
            isProcessing = false;
            return;
        }

        List<Case> casesToInsert = new List<Case>();

        for (ContentVersion cv : contentVersions) {
            if (cv.Title.contains('Code Scanner') || cv.Title.contains('Code Scanner Delta')) {
                Case newCase = new Case();
                newCase.ContentDocumentId__c = cv.ContentDocumentId;
                newCase.File_Name__c = cv.Title;
                newCase.Status = 'New';
                casesToInsert.add(newCase);
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

        isProcessing = false; // Reset flag after execution
    }
}
