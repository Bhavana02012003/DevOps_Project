public with sharing class CSVDataController {
    public class CSVDataResponse {
        @AuraEnabled public List<Map<String, String>> csvData;
        @AuraEnabled public Integer clsViolationCount;
        @AuraEnabled public Integer lwcViolationCount;
    }

    @AuraEnabled(cacheable=true)
    public static CSVDataResponse getCSVData(String caseId) {
        CSVDataResponse response = new CSVDataResponse();
        response.csvData = new List<Map<String, String>>();
        response.clsViolationCount = 0;
        response.lwcViolationCount = 0;

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
                return response;
            }

            Attachment csvFile = attachments[0];

            // Read the CSV file content
            Blob csvBlob = csvFile.Body;
            String csvContent = csvBlob.toString();

            // Split lines
            List<String> lines = csvContent.split('\n');

            // Parse CSV headers
            List<String> headers = lines[0].split(',');

            // Process CSV rows
            for (Integer i = 1; i < lines.size(); i++) {
                List<String> values = lines[i].split(',');

                if (values.size() == headers.size()) {
                    Map<String, String> rowData = new Map<String, String>();
                    for (Integer j = 0; j < headers.size(); j++) {
                        String fieldValue = values[j].trim().replaceAll('^\"|\"$', ''); // Remove surrounding quotes
                        rowData.put(headers[j].trim(), fieldValue);
                    }
                    
                    // Check for Apex Class violations (.cls)
                    if (rowData.containsKey('File')) {
                        String filePath = rowData.get('File').trim();
                        if (filePath.endsWith('.cls')) {
                            response.clsViolationCount++;
                        }
                        // Check for LWC Violations (.html, .js, .xml)
                        else if (filePath.endsWith('.html') || filePath.endsWith('.js') || filePath.endsWith('.xml')) {
                            response.lwcViolationCount++;
                        }
                    }

                    response.csvData.add(rowData);
                }
            }
        } catch (Exception e) {
            System.debug('❌ Error reading CSV file: ' + e.getMessage());
        }

        return response;
    }
}
