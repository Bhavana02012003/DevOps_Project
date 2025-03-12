public with sharing class ScannerReportHandler {
    @AuraEnabled
    public static void createAttachmentForCase(String caseId) {
        try {
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
}
