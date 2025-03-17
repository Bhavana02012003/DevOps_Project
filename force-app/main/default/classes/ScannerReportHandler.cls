public with sharing class ScannerReportHandler {

    @future
    public static void processFilesAsync(Set<Id> contentDocumentIds) {
        System.debug('🔍 Processing Scanner Report Files (Async) for ContentDocumentIds: ' + contentDocumentIds);

        if (contentDocumentIds.isEmpty()) {
            System.debug('⚠️ No ContentDocumentIds provided. Skipping processing.');
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

                ContentDocumentLink link = new ContentDocumentLink();
                link.ContentDocumentId = createdCase.ContentDocumentId__c;
                link.LinkedEntityId = createdCase.Id;
                link.ShareType = 'V'; // Viewer access
                link.Visibility = 'AllUsers';

                linksToInsert.add(link);
            }

            if (!linksToInsert.isEmpty()) {
                insert linksToInsert;
                System.debug('✅ Successfully linked files to Case records.');
            }
        } else {
            System.debug('ℹ️ No new Cases to insert.');
        }
    }

    @AuraEnabled
    public static void createAttachmentForCase(String caseId) {
        try {
            System.debug('📂 Fetching Case ID: ' + caseId);

            Case caseRecord = [
                SELECT Id, ContentDocumentId__c, File_Name__c 
                FROM Case 
                WHERE Id = :caseId 
                LIMIT 1
            ];

            if (caseRecord.ContentDocumentId__c == null) {
                System.debug('⚠️ No file associated with this case.');
                return;
            }

            List<ContentVersion> fileVersions = [
                SELECT Id, Title, FileExtension, ContentDocumentId
                FROM ContentVersion 
                WHERE ContentDocumentId = :caseRecord.ContentDocumentId__c 
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];

            if (fileVersions.isEmpty()) {
                System.debug('⚠️ No ContentVersion file found for ContentDocumentId: ' + caseRecord.ContentDocumentId__c);
                return;
            }

            ContentVersion fileVersion = fileVersions[0];

            if (fileVersion.FileExtension != 'csv') {
                System.debug('⚠️ Skipping non-CSV file: ' + fileVersion.Title);
                return;
            }

            System.debug('✅ CSV File Found! Linking to Case Files...');

            List<ContentDocumentLink> existingLinks = [
                SELECT Id FROM ContentDocumentLink 
                WHERE LinkedEntityId = :caseRecord.Id 
                AND ContentDocumentId = :fileVersion.ContentDocumentId
            ];

            if (!existingLinks.isEmpty()) {
                System.debug('⚠️ File is already linked to the Case. Skipping.');
                return;
            }

            ContentDocumentLink newLink = new ContentDocumentLink();
            newLink.ContentDocumentId = fileVersion.ContentDocumentId;
            newLink.LinkedEntityId = caseRecord.Id;
            newLink.ShareType = 'V';
            newLink.Visibility = 'AllUsers';

            insert newLink;
            System.debug('✅ File successfully linked to Case Files related list.');

        } catch (Exception e) {
            System.debug('❌ Error linking file to Case Files: ' + e.getMessage());
        }
    }
}
