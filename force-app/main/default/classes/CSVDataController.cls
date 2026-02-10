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
            // 🔥 STEP 1: Get File linked to Case (ContentDocumentLink)
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :caseId
                LIMIT 1
            ];

            if (links.isEmpty()) {
                System.debug('❌ No File linked to Case');
                return response;
            }

            Id docId = links[0].ContentDocumentId;

            // 🔥 STEP 2: Get latest CSV version
            ContentVersion fileVersion = [
                SELECT VersionData, Title
                FROM ContentVersion
                WHERE ContentDocumentId = :docId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            // 🔥 STEP 3: Read CSV
            String csvContent = fileVersion.VersionData.toString();
            List<String> lines = csvContent.split('\n');

            if (lines.isEmpty()) return response;

            // 🔥 Support Code Analyzer v4 + v5 headers
            List<String> headers = normalizeHeaders(lines[0]);

            // 🔥 STEP 4: Parse rows
            for (Integer i = 1; i < lines.size(); i++) {

                if (String.isBlank(lines[i])) continue;

                List<String> values = parseCSVLine(lines[i]);

                if (values.size() != headers.size()) continue;

                Map<String,String> rowData = new Map<String,String>();

                for (Integer j=0; j<headers.size(); j++) {
                    rowData.put(headers[j], values[j]);
                }

                // 🔥 Count violations
                if (rowData.containsKey('file')) {
                    String filePath = rowData.get('file').toLowerCase();

                    if (filePath.contains('classes')) response.clsViolationCount++;
                    else if (filePath.contains('lwc')) response.lwcViolationCount++;
                    else if (filePath.contains('aura')) response.auraViolationCount++;
                    else if (filePath.contains('objects')) response.objectsViolationCount++;
                }

                response.csvData.add(rowData);
            }

        } catch (Exception e) {
            System.debug('❌ CSV ERROR: ' + e.getMessage());
        }

        return response;
    }

    // ⭐ Normalize headers for Code Analyzer v4 + v5
    private static List<String> normalizeHeaders(String headerRow) {

        List<String> rawHeaders = parseCSVLine(headerRow);
        List<String> normalized = new List<String>();

        for(String h : rawHeaders) {

            h = h.toLowerCase()
                 .replace(' ', '')
                 .replace('_', '');

            // 🔥 map camelCase → lowercase
            if(h == 'startline') h = 'startline';
            if(h == 'startcolumn') h = 'startcolumn';

            normalized.add(h);
        }

        return normalized;
    }

    // ⭐ Proper CSV parser (handles commas inside quotes)
    private static List<String> parseCSVLine(String line) {

        List<String> cols = new List<String>();
        Boolean inQuotes = false;
        String cur = '';

        for (Integer i=0; i<line.length(); i++) {
            String c = line.substring(i,i+1);

            if (c == '"') inQuotes = !inQuotes;
            else if (c == ',' && !inQuotes) {
                cols.add(cur.replace('"','').trim());
                cur = '';
            }
            else cur += c;
        }

        cols.add(cur.replace('"','').trim());
        return cols;
    }
}
