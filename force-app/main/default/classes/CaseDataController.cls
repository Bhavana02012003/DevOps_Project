public with sharing class CaseDataController {
    public class CSVDataResponse {
        @AuraEnabled public List<Map<String, String>> csvData = new List<Map<String, String>>();
        @AuraEnabled public Integer clsViolationCount = 0;
        @AuraEnabled public Integer lwcViolationCount = 0;
        @AuraEnabled public Integer auraViolationCount = 0;
        @AuraEnabled public Integer objectsViolationCount = 0;
    }

    @AuraEnabled(cacheable=true)
    public static CSVDataResponse getCSVData(String caseId) {
        CSVDataResponse response = new CSVDataResponse();

        try {
            System.debug('🔍 Fetching ContentDocumentId for Case ID: ' + caseId);

            // Step 1: Get ContentDocumentId from ContentDocumentLink
            List<ContentDocumentLink> contentLinks = [
                SELECT ContentDocumentId 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :caseId
            ];

            if (contentLinks.isEmpty()) {
                System.debug('⚠️ No ContentDocumentLink found for Case ID: ' + caseId);
                return response;
            }

            Set<Id> contentDocumentIds = new Set<Id>();
            for (ContentDocumentLink link : contentLinks) {
                contentDocumentIds.add(link.ContentDocumentId);
            }

            System.debug('✅ Found ContentDocumentIds: ' + contentDocumentIds);

            // Step 2: Get latest CSV ContentVersion using ContentDocumentIds
            List<ContentVersion> contentVersions = [
                SELECT Id, VersionData, Title 
                FROM ContentVersion
                WHERE ContentDocumentId IN :contentDocumentIds
                AND Title LIKE '%.csv'
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];

            if (contentVersions.isEmpty()) {
                System.debug('⚠️ No CSV file found for Case ID: ' + caseId);
                return response;
            }

            ContentVersion csvFile = contentVersions[0];
            System.debug('✅ Found CSV file: ' + csvFile.Title);

            // Read the CSV file content
            Blob csvBlob = csvFile.VersionData;
            String csvContent = csvBlob.toString();

            // Print CSV Content for Debugging
            System.debug('📂 CSV File Content: ' + csvContent);

            // Split lines
            List<String> lines = csvContent.split('\n');

            // Ensure headers exist
            if (lines.isEmpty()) {
                System.debug('⚠️ CSV file is empty.');
                return response;
            }

            List<String> headers = lines[0].split(',');

            System.debug('✅ CSV Headers: ' + headers);

            // Process CSV rows
            for (Integer i = 1; i < lines.size(); i++) {
                List<String> values = lines[i].split(',');

                if (values.size() == headers.size()) {
                    Map<String, String> rowData = new Map<String, String>();
                    for (Integer j = 0; j < headers.size(); j++) {
                        String fieldValue = values[j].trim().replaceAll('^\"|\"$', ''); // Remove quotes
                        rowData.put(headers[j].trim(), fieldValue);
                    }

                    // Count violations based on file path
                    if (rowData.containsKey('File')) {
                        String filePath = rowData.get('File').trim();
                        if (filePath.contains('classes')) {
                            response.clsViolationCount++;
                        } else if (filePath.contains('lwc')) {
                            response.lwcViolationCount++;
                        } else if (filePath.contains('aura')) {
                            response.auraViolationCount++;
                        } else if (filePath.contains('objects')) {
                            response.objectsViolationCount++;
                        }
                    }

                    response.csvData.add(rowData);
                }
            }

            System.debug('✅ Successfully processed CSV data. Returning response.');

        } catch (Exception e) {
            System.debug('❌ Error processing CSV: ' + e.getMessage());
        }

        return response;
    }
}
