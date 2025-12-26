public with sharing class File {

    private static final String VULN_OBJECT_LABEL = 'Vulnerability';

    /* ============================================================
       ENTRY POINT
    ============================================================ */
    public static void processNewFiles(List<ContentVersion> contentVersions) {
        List<Id> contentDocIds = new List<Id>();
        for (ContentVersion cv : contentVersions) {
            if (cv.ContentDocumentId != null) {
                contentDocIds.add(cv.ContentDocumentId);
            }
        }
        if (!contentDocIds.isEmpty()) {
            importVulnerabilityData(contentDocIds);
        }
    }

    /* ============================================================
       MAIN PROCESSOR
    ============================================================ */
    public static void importVulnerabilityData(List<Id> contentDocIds) {

        String currentRunId = String.valueOf(System.now().getTime());

        String vulnObjectApi = resolveVulnerabilityObjectApiName();
        if (String.isBlank(vulnObjectApi)) return;

        Schema.SObjectType sType = Schema.getGlobalDescribe().get(vulnObjectApi);

        List<ContentVersion> fileList = [
            SELECT Id, Title, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocIds
            ORDER BY CreatedDate DESC
        ];
        if (fileList.isEmpty()) return;

        /* ---------------- LOAD EXISTING RECORDS ---------------- */
        Map<String, SObject> existingMap = new Map<String, SObject>();
        for (SObject v : Database.query(
            'SELECT Id, Problem__c, Rule__c, File__c, Line__c, Engine__c, TargetBranch__c,' +
            ' Violation_Status__c, Last_Seen_Run_Id__c FROM ' + vulnObjectApi
        )) {
            existingMap.put(buildKey(v), v);
        }

        List<SObject> toInsert = new List<SObject>();
        List<SObject> toUpdate = new List<SObject>();

        /* ============================================================
           PARSE scanner-report.csv → INSERT / UPDATE
        ============================================================ */
        for (ContentVersion cv : fileList) {

            if (cv.VersionData == null) continue;
            if (cv.Title != null && cv.Title.toLowerCase().contains('scanned_files')) continue;

            List<String> lines = cv.VersionData.toString().split('\\n');
            if (lines.size() < 2) continue;

            List<String> headers = parseCSVLine(lines[0]);
            Map<String, Integer> col = new Map<String, Integer>();
            for (Integer i = 0; i < headers.size(); i++) {
                col.put(headers[i].trim().toLowerCase(), i);
            }

            for (Integer r = 1; r < lines.size(); r++) {

                List<String> cols = parseCSVLine(lines[r]);
                if (cols.isEmpty()) continue;

                SObject record = sType.newSObject();
                safePut(record, 'Problem__c', cols[col.get('problem')]);
                safePut(record, 'Rule__c', cols[col.get('rule')]);
                safePut(record, 'File__c', cols[col.get('file')]);
                safePut(record, 'Line__c', cols[col.get('templine')]);
                safePut(record, 'Engine__c', cols[col.get('engine')]);
                safePut(record, 'TargetBranch__c', cols[col.get('targetbranch')]);
                safePut(record, 'Violation_Status__c', 'Open');
                safePut(record, 'Last_Seen_Run_Id__c', currentRunId);
                safePut(record, 'Last_Seen_Date__c', System.now());

                String key = buildKey(record);

                if (existingMap.containsKey(key)) {
                    SObject existing = existingMap.get(key);
                    existing.put('Violation_Status__c', 'Open');
                    existing.put('Last_Seen_Run_Id__c', currentRunId);
                    existing.put('Last_Seen_Date__c', System.now());
                    toUpdate.add(existing);
                } else {
                    record.put('First_Seen_Run_Id__c', currentRunId);
                    toInsert.add(record);
                }
            }
        }

        /* ============================================================
           AUTO CLOSE LOGIC (FILES SCANNED BUT NO LONGER FOUND)
        ============================================================ */
        Set<String> scannedFiles = new Set<String>();

        for (ContentVersion cv : fileList) {
            if (cv.Title != null && cv.Title.toLowerCase().contains('scanned_files')) {
                List<String> rows = cv.VersionData.toString().split('\\n');
                for (Integer i = 1; i < rows.size(); i++) {
                    scannedFiles.add(rows[i].trim());
                }
            }
        }

        for (SObject existing : existingMap.values()) {
            if (
                scannedFiles.contains((String)existing.get('File__c')) &&
                existing.get('Last_Seen_Run_Id__c') != currentRunId &&
                existing.get('Violation_Status__c') == 'Open'
            ) {
                existing.put('Violation_Status__c', 'Closed');
                existing.put('Last_Seen_Date__c', System.now());
                toUpdate.add(existing);
            }
        }

        /* ---------------- FINAL DML ---------------- */
        if (!toInsert.isEmpty()) insert toInsert;
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    /* ============================================================
       HELPERS
    ============================================================ */
    private static String resolveVulnerabilityObjectApiName() {
        for (String api : Schema.getGlobalDescribe().keySet()) {
            Schema.SObjectType t = Schema.getGlobalDescribe().get(api);
            if (t != null && t.getDescribe().getLabel() == VULN_OBJECT_LABEL) {
                return api;
            }
        }
        return null;
    }

    private static String buildKey(SObject r) {
        return String.join(new List<String>{
            String.valueOf(r.get('Problem__c')),
            String.valueOf(r.get('Rule__c')),
            String.valueOf(r.get('File__c')),
            String.valueOf(r.get('Line__c')),
            String.valueOf(r.get('Engine__c')),
            String.valueOf(r.get('TargetBranch__c'))
        }, '|');
    }

    private static void safePut(SObject r, String f, Object v) {
        try { r.put(f, v); } catch (Exception ignore) {}
    }

    public static List<String> parseCSVLine(String line) {
        List<String> result = new List<String>();
        Boolean inQuotes = false;
        String current = '';
        for (Integer i = 0; i < line.length(); i++) {
            String ch = line.substring(i, i + 1);
            if (ch == '"') inQuotes = !inQuotes;
            else if (ch == ',' && !inQuotes) {
                result.add(current);
                current = '';
            } else {
                current += ch;
            }
        }
        result.add(current);
        return result;
    }
}
