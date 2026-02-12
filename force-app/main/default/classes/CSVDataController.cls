public with sharing class CSVDataController {

    public class CSVDataResponse {
        @AuraEnabled public List<Map<String, String>> csvData = new List<Map<String, String>>();
        @AuraEnabled public Integer clsViolationCount = 0;
        @AuraEnabled public Integer lwcViolationCount = 0;
        @AuraEnabled public Integer auraViolationCount = 0;
        @AuraEnabled public Integer objectsViolationCount = 0;
    }

    // IMPORTANT: Do NOT make this cacheable, because files get attached AFTER case creation
    @AuraEnabled(cacheable=false)
    public static CSVDataResponse getCSVData(String caseId) {

        CSVDataResponse response = new CSVDataResponse();

        if (String.isBlank(caseId)) {
            return response;
        }

        try {
            // 1) Get ALL files linked to this Case
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :caseId
            ];

            if (links.isEmpty()) {
                System.debug('❌ No files linked to this Case');
                return response;
            }

            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink l : links) {
                if (l.ContentDocumentId != null) docIds.add(l.ContentDocumentId);
            }

            if (docIds.isEmpty()) return response;

            // 2) From those linked docs, pick the LATEST CSV ContentVersion
            //    (This avoids picking an older header-only CSV)
            List<ContentVersion> versions = [
                SELECT Id, ContentDocumentId, Title, PathOnClient, FileExtension, CreatedDate, VersionData
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds
                  AND IsLatest = true
                  AND FileExtension = 'csv'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (versions.isEmpty()) {
                System.debug('❌ No latest CSV found among linked files');
                return response;
            }

            ContentVersion fileVersion = versions[0];

            if (fileVersion.VersionData == null) {
                System.debug('❌ CSV VersionData is null');
                return response;
            }

            // 3) Convert Blob -> String
            String csvContent = fileVersion.VersionData.toString();
            csvContent = csvContent.replace('\r\n', '\n').replace('\r', '\n');

            // 4) Parse CSV using a safe parser that respects quotes/commas
            List<List<String>> rows = parseCSV(csvContent);

            if (rows == null || rows.size() <= 1) {
                System.debug('⚠️ CSV has no data rows (only header or empty)');
                return response;
            }

            // 5) Headers (normalized)
            List<String> headersRaw = rows[0];
            List<String> headers = new List<String>();
            for (String h : headersRaw) {
                headers.add(normalizeHeader(h));
            }

            // 6) Data rows
            Integer rowCounter = 0;
            for (Integer i = 1; i < rows.size(); i++) {
                List<String> values = rows[i];
                if (values == null || values.isEmpty()) continue;

                // If row has fewer columns than header, skip
                if (values.size() < headers.size()) continue;

                Map<String, String> row = new Map<String, String>();

                // ✅ Add synthetic Id for lightning-datatable key-field="Id"
                rowCounter++;
                row.put('Id', String.valueOf(rowCounter));

                for (Integer j = 0; j < headers.size(); j++) {
                    row.put(headers[j], values[j]);
                }

                // Count violations by file path
                String filePath = '';
                if (row.containsKey('file') && row.get('file') != null) {
                    filePath = row.get('file').toLowerCase();
                }

                if (!String.isBlank(filePath)) {
                    // Works for both real paths and your temp_scanner_files names
                    if (filePath.contains('classes')) response.clsViolationCount++;
                    else if (filePath.contains('lwc')) response.lwcViolationCount++;
                    else if (filePath.contains('aura')) response.auraViolationCount++;
                    else if (filePath.contains('objects')) response.objectsViolationCount++;
                }

                response.csvData.add(row);
            }

            System.debug('✅ Parsed rows: ' + response.csvData.size());

        } catch (Exception e) {
            System.debug('❌ CSV ERROR: ' + e.getMessage() + ' | ' + e.getStackTraceString());
        }

        return response;
    }

    // Normalize headers to match your JS usage (item.file, etc.)
    private static String normalizeHeader(String h) {
        if (h == null) return '';
        String x = h.toLowerCase();
        x = x.replace('"', '').replace(' ', '').replace('_', '').replace('-', '');
        return x;
    }

    // -------- CSV Parser (handles quotes, commas, escaped quotes, newlines in quotes) --------
    private static List<List<String>> parseCSV(String input) {
        List<List<String>> rows = new List<List<String>>();
        if (String.isBlank(input)) return rows;

        List<String> currentRow = new List<String>();
        String currentField = '';
        Boolean inQuotes = false;

        for (Integer i = 0; i < input.length(); i++) {
            String c = input.substring(i, i + 1);

            if (c == '"') {
                // escaped quote inside quoted field: ""
                if (inQuotes && i + 1 < input.length() && input.substring(i + 1, i + 2) == '"') {
                    currentField += '"';
                    i++;
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (c == ',' && !inQuotes) {
                currentRow.add(currentField);
                currentField = '';
            } else if (c == '\n' && !inQuotes) {
                currentRow.add(currentField);
                rows.add(currentRow);
                currentRow = new List<String>();
                currentField = '';
            } else {
                currentField += c;
            }
        }

        // last field
        currentRow.add(currentField);
        rows.add(currentRow);

        return rows;
    }
}
