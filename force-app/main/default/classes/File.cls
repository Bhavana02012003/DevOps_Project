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
        try {

            String vulnApiName = resolveVulnerabilityObjectApiName();
            if (String.isBlank(vulnApiName)) {
                System.debug('❌ Vulnerability object not found by label');
                return;
            }

            Schema.SObjectType vulnType =
                Schema.getGlobalDescribe().get(vulnApiName);

            List<SObject> newRecords = new List<SObject>();

            List<ContentVersion> files = [
                SELECT Id, VersionData
                FROM ContentVersion
                WHERE ContentDocumentId IN :contentDocIds
                ORDER BY CreatedDate DESC
            ];

            for (ContentVersion file : files) {

                if (file.VersionData == null) continue;

                String csv = file.VersionData.toString();
                List<String> rows = csv.split('\\n');
                if (rows.size() < 2) continue;

                List<String> headers = parseCSVLine(rows[0]);
                Map<String, Integer> colIndex = new Map<String, Integer>();
                for (Integer i = 0; i < headers.size(); i++) {
                    colIndex.put(headers[i].trim().toLowerCase(), i);
                }

                for (Integer r = 1; r < rows.size(); r++) {
                    List<String> cols = parseCSVLine(rows[r]);
                    if (cols.isEmpty()) continue;

                    SObject vuln = vulnType.newSObject();
                    safePut(vuln, 'Problem__c', cols[colIndex.get('problem')]);
                    safePut(vuln, 'Severity__c', cols[colIndex.get('severity')]);
                    safePut(vuln, 'File__c', cols[colIndex.get('file')]);
                    safePut(vuln, 'Line__c', cols[colIndex.get('templine')]);
                    safePut(vuln, 'Column__c', cols[colIndex.get('column')]);
                    safePut(vuln, 'Rule__c', cols[colIndex.get('rule')]);
                    safePut(vuln, 'Description__c', cols[colIndex.get('description')]);
                    safePut(vuln, 'URL__c', cols[colIndex.get('url')]);
                    safePut(vuln, 'Category__c', cols[colIndex.get('category')]);
                    safePut(vuln, 'Engine__c', cols[colIndex.get('engine')]);
                    safePut(vuln, 'Commit__c', cols[colIndex.get('commit')]);
                    safePut(vuln, 'ActualLine__c', cols[colIndex.get('actualline')]);
                    safePut(vuln, 'TargetBranch__c', cols[colIndex.get('targetbranch')]);

                    newRecords.add(vuln);
                }
            }

            if (!newRecords.isEmpty()) {
                insert newRecords;
                System.debug('✅ Created ' + newRecords.size() + ' Vulnerability records');
            }

        } catch (Exception e) {
            System.debug('❌ Error: ' + e.getMessage());
            System.debug(e.getStackTraceString());
        }
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

    private static void safePut(SObject s, String field, Object value) {
        try {
            s.put(field, value);
        } catch (Exception ignore) {}
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
