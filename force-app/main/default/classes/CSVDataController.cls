public with sharing class CSVDataController {
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
            // Fetch the latest Attachment (CSV file) related to the case
            List<Attachment> attachments = [
                SELECT Id, Body, Name
                FROM Attachment
                WHERE ParentId = :caseId AND Name LIKE '%.csv'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (attachments.isEmpty()) {
                System.debug('⚠️ No CSV file found for Case ID: ' + caseId);
                return response; // Return empty response to prevent null reference error
            }

            Attachment csvFile = attachments[0];

            // Read the CSV file content
            Blob csvBlob = csvFile.Body;
            String csvContent = csvBlob.toString();

            // Split lines
            List<String> lines = csvContent.split('\n');

            // Ensure headers exist
            if (lines.isEmpty()) {
                System.debug('⚠️ CSV file is empty.');
                return response;
            }

            List<String> headers = lines[0].split(',');

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
        } catch (Exception e) {
            System.debug('❌ Error processing CSV: ' + e.getMessage());
        }

        return response;
    }
}
