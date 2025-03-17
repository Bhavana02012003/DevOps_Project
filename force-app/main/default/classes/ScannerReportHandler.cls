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
            SELECT Id, ContentDocumentId, Title 
            FROM ContentVersion 
            WHERE ContentDocumentId IN :contentDocumentIds
        ];

        if (contentVersions.isEmpty()) {
            System.debug('⚠️ No matching ContentVersion records found.');
            isProcessing = false;
            return;
        }

        List<Case> casesToInsert = new List<Case>();
        Map<Id, Id> caseToFileMap = new Map<Id, Id>(); // Store Case ID -> ContentDocumentId mapping

        for (ContentVersion cv : contentVersions) {
            System.debug('📂 Processing File: ' + cv.Title + ' | ContentDocumentId: ' + cv.ContentDocumentId);

            if (cv.Title.contains('Code Scanner') || cv.Title.contains('Code Scanner Delta')) {
                System.debug('✅ File Matches Condition: ' + cv.Title);

                Case newCase = new Case();
                newCase.File_Name__c = cv.Title;
                newCase.Status = 'New';

                casesToInsert.add(newCase);
                caseToFileMap.put(cv.ContentDocumentId, null); // Placeholder
            }
        }

        if (!casesToInsert.isEmpty()) {
            try {
                insert casesToInsert;
                System.debug('✅ Successfully inserted ' + casesToInsert.size() + ' Case records.');

                // Map newly created Cases to their corresponding ContentDocumentId
                Integer index = 0;
                for (Case createdCase : casesToInsert) {
                    Id docId = contentVersions[index].ContentDocumentId;
                    caseToFileMap.put(docId, createdCase.Id);
                    index++;
                }

            } catch (DmlException e) {
                System.debug('❌ Error inserting Cases: ' + e.getMessage());
                isProcessing = false;
                return;
            }
        } else {
            System.debug('⚠️ No Cases to insert.');
            isProcessing = false;
            return;
        }

        // ✅ Step 2: Ensure Files Are Linked to Cases
        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();

        for (Id contentDocId : caseToFileMap.keySet()) {
            Id caseId = caseToFileMap.get(contentDocId);

            if (caseId != null) {
                System.debug('🔗 Checking ContentDocumentLink for Case: ' + caseId + ' | File: ' + contentDocId);

                // Ensure ContentDocumentLink does not already exist
                List<ContentDocumentLink> existingLinks = [
                    SELECT Id FROM ContentDocumentLink 
                    WHERE LinkedEntityId = :caseId 
                    AND ContentDocumentId = :contentDocId
                ];

                if (existingLinks.isEmpty()) {
                    System.debug('✅ Creating ContentDocumentLink for Case: ' + caseId + ' | File: ' + contentDocId);

                    ContentDocumentLink link = new ContentDocumentLink();
                    link.ContentDocumentId = contentDocId;
                    link.LinkedEntityId = caseId;
                    link.ShareType = 'V'; // Viewer access
                    link.Visibility = 'AllUsers';

                    linksToInsert.add(link);
                } else {
                    System.debug('⚠️ File already linked to this Case. Skipping.');
                }
            }
        }

        // Insert ContentDocumentLinks to link files to Cases
        if (!linksToInsert.isEmpty()) {
            try {
                insert linksToInsert;
                System.debug('✅ Successfully linked ' + linksToInsert.size() + ' files to Case records.');
            } catch (DmlException e) {
                System.debug('❌ Error linking files to Case: ' + e.getMessage());
            }
        } else {
            System.debug('⚠️ No new files to link.');
        }

        isProcessing = false; // Reset flag after execution
    }
}
