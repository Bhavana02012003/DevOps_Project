public with sharing class ScannerReportHandler {
    @AuraEnabled
    public static void createAttachmentForCase(String caseId) {
        try {
            System.debug('📂 Creating attachment for Case ID: ' + caseId);

            // Fetch the related Case record
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

            // Retrieve the CSV file from ContentVersion
            List<ContentVersion> fileVersions = [
                SELECT VersionData, Title, FileExtension
                FROM ContentVersion 
                WHERE ContentDocumentId = :caseRecord.ContentDocumentId__c 
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];

            if (fileVersions.isEmpty()) {
                System.debug('⚠️ File not found for ContentDocumentId: ' + caseRecord.ContentDocumentId__c);
                return;
            }

            ContentVersion fileVersion = fileVersions[0];

            // Ensure the file is a CSV before creating an attachment
            if (fileVersion.FileExtension != 'csv') {
                System.debug('⚠️ Skipping non-CSV file: ' + fileVersion.Title);
                return;
            }

            // Ensure the file name has a .csv extension
            String fileName = fileVersion.Title;
            if (!fileName.toLowerCase().endsWith('.csv')) {
                fileName += '.csv';
            }

            // Convert file data into a Blob
            Blob fileBlob = fileVersion.VersionData;

            // Create an Attachment record
            Attachment attachment = new Attachment();
            attachment.Name = fileName; // Ensure correct file extension
            attachment.Body = fileBlob; // Store CSV content correctly
            attachment.ParentId = caseRecord.Id; // Attach to Case record
            attachment.ContentType = 'application/octet-stream'; // Ensure it downloads correctly as a CSV

            insert attachment;

            System.debug('✅ CSV Attachment successfully created for Case ID: ' + caseId);

        } catch (Exception e) {
            System.debug('❌ Error creating CSV attachment: ' + e.getMessage());
        }
    }

    // ✅ Add the missing method that your trigger might be calling
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
