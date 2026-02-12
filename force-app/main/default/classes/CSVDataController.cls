public with sharing class CSVDataController {

    /* ============================================================
       RESPONSE WRAPPER
    ============================================================ */
    public class CSVDataResponse {
        @AuraEnabled public List<Map<String,String>> csvData = new List<Map<String,String>>();
        @AuraEnabled public Integer clsViolationCount = 0;
        @AuraEnabled public Integer lwcViolationCount = 0;
        @AuraEnabled public Integer auraViolationCount = 0;
        @AuraEnabled public Integer objectsViolationCount = 0;
    }

    /* ============================================================
       MAIN METHOD
    ============================================================ */
    @AuraEnabled(cacheable=true)
    public static CSVDataResponse getCSVData(String caseId) {

        CSVDataResponse response = new CSVDataResponse();

        try {

            System.debug('==== STEP 1: GET ALL FILES LINKED TO CASE ====');

            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :caseId
            ];

            if(links.isEmpty()){
                System.debug('❌ No files linked to this Case');
                return response;
            }

            Set<Id> docIds = new Set<Id>();
            for(ContentDocumentLink l : links){
                docIds.add(l.ContentDocumentId);
            }

            System.debug('Files found: ' + docIds.size());

            /* ====================================================
               STEP 2 — GET LATEST VERSION OF EACH FILE
            ==================================================== */

            List<ContentVersion> versions = [
                SELECT VersionData, Title, CreatedDate
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds
                ORDER BY CreatedDate DESC
            ];

            if(versions.isEmpty()){
                System.debug('❌ No ContentVersions found');
                return response;
            }

            /* ====================================================
               STEP 3 — FIND THE SCANNER CSV FILE
            ==================================================== */

            ContentVersion scannerFile;

            for(ContentVersion v : versions){
                if(v.Title != null && v.Title.contains('Code_Scanner_Report')){
                    scannerFile = v;
                    break;
                }
            }

            if(scannerFile == null){
                System.debug('❌ Scanner CSV not found');
                return response;
            }

            System.debug('✅ CSV FOUND: ' + scannerFile.Title);

            /* ====================================================
               STEP 4 — CONVERT BLOB → STRING
            ==================================================== */

            String csvContent = scannerFile.VersionData.toString();
            csvContent = csvContent.replace('\r\n','\n').replace('\r','\n');

            List<String> lines = csvContent.split('\n');
            System.debug('CSV Lines Count: ' + lines.size());

            if(lines.size() <= 1){
                System.debug('❌ CSV EMPTY');
                return response;
            }

            /* ====================================================
               STEP 5 — READ HEADERS
            ==================================================== */

            List<String> headers = parseCSVLine(lines[0]);

            for(Integer i=0;i<headers.size();i++){
                headers[i] = normalize(headers[i]);
            }

            System.debug('Headers: ' + headers);

            /* ====================================================
               STEP 6 — PARSE ROWS
            ==================================================== */

            for(Integer i=1;i<lines.size();i++){

                if(String.isBlank(lines[i])) continue;

                List<String> values = parseCSVLine(lines[i]);

                // allow extra columns safely
                if(values.size() < headers.size()) continue;

                Map<String,String> row = new Map<String,String>();

                for(Integer j=0;j<headers.size();j++){
                    row.put(headers[j], values[j]);
                }

                /* ===== COUNT BY FILE TYPE ===== */
                if(row.containsKey('file')){
                    String filePath = row.get('file').toLowerCase();

                    if(filePath.contains('classes')) response.clsViolationCount++;
                    else if(filePath.contains('lwc')) response.lwcViolationCount++;
                    else if(filePath.contains('aura')) response.auraViolationCount++;
                    else if(filePath.contains('objects')) response.objectsViolationCount++;
                }

                response.csvData.add(row);
            }

            System.debug('✅ TOTAL ROWS PARSED: ' + response.csvData.size());

        } catch(Exception e){
            System.debug('❌ CSV ERROR: '+e.getMessage());
        }

        return response;
    }

    /* ============================================================
       HELPER — NORMALIZE HEADER
    ============================================================ */
    private static String normalize(String h){
        return h.toLowerCase()
                .replace(' ','')
                .replace('_','')
                .replace('"','');
    }

    /* ============================================================
       HELPER — SAFE CSV PARSER (handles quotes + commas)
    ============================================================ */
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
