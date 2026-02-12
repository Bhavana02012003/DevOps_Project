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

    try {

        if(String.isBlank(caseId)) return response;

        // 🔥 THE REAL FIX — find CSV using FirstPublishLocationId
        ContentVersion fileVersion = [
            SELECT Id, Title, VersionData, CreatedDate
            FROM ContentVersion
            WHERE FirstPublishLocationId = :caseId
            AND FileExtension = 'csv'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if(fileVersion == null){
            System.debug('❌ No CSV found for this case');
            return response;
        }

        // Convert Blob → String
        String csvContent = fileVersion.VersionData.toString();
        csvContent = csvContent.replace('\r\n','\n').replace('\r','\n');

        List<List<String>> rows = parseCSV(csvContent);
        if(rows.size() <= 1) return response;

        // Headers
        List<String> headers = new List<String>();
        for(String h : rows[0]){
            headers.add(normalizeHeader(h));
        }

        Integer counter = 0;

        // Rows
        for(Integer i=1;i<rows.size();i++){
            List<String> values = rows[i];
            if(values.size() < headers.size()) continue;

            Map<String,String> row = new Map<String,String>();
            counter++;
            row.put('Id', String.valueOf(counter));

            for(Integer j=0;j<headers.size();j++){
                row.put(headers[j], values[j]);
            }

            // Count violations
            String filePath = row.get('file');
            if(filePath != null){
                filePath = filePath.toLowerCase();
                if(filePath.contains('classes')) response.clsViolationCount++;
                else if(filePath.contains('lwc')) response.lwcViolationCount++;
                else if(filePath.contains('aura')) response.auraViolationCount++;
                else if(filePath.contains('objects')) response.objectsViolationCount++;
            }

            response.csvData.add(row);
        }

    } catch(Exception e){
        System.debug('CSV ERROR: '+e.getMessage());
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
