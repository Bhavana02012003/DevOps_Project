public with sharing class ScannerReportHandler {
    @AuraEnabled
    public static void createAttachmentForCase(String caseId) {
        try {
            System.debug('📂 Fetching Case ID: ' + caseId);

            // Step 1: Fetch the related Case record
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

            // Step 2: Fetch the latest ContentVersion file
            List<ContentVersion> fileVersions = [
                SELECT Id, VersionData, Title, FileExtension, ContentDocumentId
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

            // Step 3: Ensure the file is a CSV before storing in Attachments
            if (fileVersion.FileExtension != 'csv') {
                System.debug('⚠️ Skipping non-CSV file: ' + fileVersion.Title);
                return;
            }

            System.debug('✅ CSV File Found! Converting to Attachment...');

            // Step 4: Convert ContentVersion to Attachment
            Blob fileBlob = fileVersion.VersionData;
            String fileName = fileVersion.Title;
            if (!fileName.toLowerCase().endsWith('.csv')) {
                fileName += '.csv';
            }

            // Check if an attachment already exists for this case
            List<Attachment> existingAttachments = [
                SELECT Id FROM Attachment 
                WHERE ParentId = :caseRecord.Id 
                AND Name = :fileName
            ];

            if (!existingAttachments.isEmpty()) {
                System.debug('⚠️ Attachment already exists for this Case. Skipping creation.');
                return;
            }

            // Step 5: **Manually create and insert the Attachment**
            Attachment newAttachment = new Attachment();
            newAttachment.Name = fileName;
            newAttachment.Body = fileBlob;
            newAttachment.ParentId = caseRecord.Id;
            newAttachment.ContentType = 'text/csv';

            insert newAttachment;
            System.debug('✅ CSV Attachment successfully created and linked to Case ID: ' + caseId);

        } catch (Exception e) {
            System.debug('❌ Error linking file to Case Attachments: ' + e.getMessage());
        }
    }

    // ✅ Fix: Ensure processFiles(Set<Id>) method exists
    public static void processFiles(Set<Id> contentDocumentIds) {
        System.debug('🔍 Processing Scanner Report Files for ContentDocumentIds: ' + contentDocumentIds);

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

        for (ContentVersion cv : contentVersions) {
            if (cv.Title.contains('Code Scanner')) {
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
        } else {
            System.debug('ℹ️ No new Cases to insert.');
        }
    }
}
