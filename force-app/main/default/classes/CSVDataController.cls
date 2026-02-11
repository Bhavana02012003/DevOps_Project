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
            // STEP 1 — Get File linked to Case
            ContentDocumentLink link = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :caseId
                LIMIT 1
            ];

            // STEP 2 — Get latest version
            ContentVersion fileVersion = [
                SELECT VersionData
                FROM ContentVersion
                WHERE ContentDocumentId = :link.ContentDocumentId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            // STEP 3 — Convert Blob → String safely
            String csvContent = fileVersion.VersionData.toString();
            csvContent = csvContent.replace('\r\n','\n').replace('\r','\n');

            List<String> lines = csvContent.split('\n');
            if(lines.size() <= 1) return response;

            // STEP 4 — Read headers
            List<String> headers = parseCSVLine(lines[0]);

            for(Integer i=0;i<headers.size();i++){
                headers[i] = normalize(headers[i]);
            }

            // STEP 5 — Parse rows (🔥 NEW SAFE PARSER)
            for(Integer i=1;i<lines.size();i++){

                if(String.isBlank(lines[i])) continue;

                List<String> values = parseCSVLine(lines[i]);

                // 🔥 FIX: allow column mismatch (Code Analyzer adds new cols)
                if(values.size() < headers.size()) continue;

                Map<String,String> row = new Map<String,String>();

                for(Integer j=0;j<headers.size();j++){
                    row.put(headers[j], values[j]);
                }

                // 🔥 COUNT VIOLATIONS
                if(row.containsKey('file')){
                    String filePath = row.get('file').toLowerCase();

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

    // 🔥 Normalize headers
    private static String normalize(String h){
        return h.toLowerCase()
                .replace(' ','')
                .replace('_','')
                .replace('"','');
    }

    // 🔥 SUPER SAFE CSV PARSER (handles quotes + commas)
    private static List<String> parseCSVLine(String line){

        List<String> cols = new List<String>();
        Boolean inQuotes = false;
        String cur = '';

        for(Integer i=0;i<line.length();i++){
            String c = line.substring(i,i+1);

            if(c == '"'){
                inQuotes = !inQuotes;
            }
            else if(c == ',' && !inQuotes){
                cols.add(cur.trim());
                cur = '';
            }
            else{
                cur += c;
            }
        }

        cols.add(cur.trim());
        return cols;
    }
}
