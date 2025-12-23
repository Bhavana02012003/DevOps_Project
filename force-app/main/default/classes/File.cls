public with sharing class File {

    private static final String VULN_OBJECT_LABEL = 'Vulnerability';

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

    public static void importVulnerabilityData(List<Id> contentDocIds) {
        try {
            /* ---------------- CURRENT SCAN RUN ---------------- */
            String currentRunId = String.valueOf(System.now().getTime());

            /* ---------------- RESOLVE OBJECT ---------------- */
            String vulnObjectApi = resolveVulnerabilityObjectApiName();
            if (String.isBlank(vulnObjectApi)) return;

            Schema.SObjectType sType = Schema.getGlobalDescribe().get(vulnObjectApi);
            Map<String, Schema.SObjectField> fields = sType.getDescribe().fields.getMap();

            /* ---------------- LOAD FILES ---------------- */
            List<ContentVersion> fileList = [
                SELECT Id, VersionData
                FROM ContentVersion
                WHERE ContentDocumentId IN :contentDocIds
                ORDER BY CreatedDate DESC
            ];
            if (fileList.isEmpty()) return;

            /* ---------------- MASTER ---------------- */
            Map<String, SObject> masterMap = new Map<String, SObject>();
            for (SObject v : Database.query(
                'SELECT Id, Problem__c, Rule__c, File__c, Line__c, Engine__c, TargetBranch__c, ' +
                'Violation_Status__c, Last_Seen_Run_Id__c FROM ' + vulnObjectApi
            )) {
                masterMap.put(buildKey(v), v);
            }

            /* ---------------- DELTA ---------------- */
            Set<String> seenThisRun = new Set<String>();
            List<SObject> toInsert = new List<SObject>();
            List<SObject> toUpdate = new List<SObject>();

            for (ContentVersion cv : fileList) {
                if (cv.VersionData == null) continue;

                List<String> lines = cv.VersionData.toString().split('\\n');
                if (lines.size() < 2) continue;

                List<String> headers = parseCSVLine(lines[0]);
                Map<String, Integer> col = new Map<String, Integer>();
                for (Integer i = 0; i < headers.size(); i++) {
                    col.put(headers[i].trim().toLowerCase(), i);
                }

                for (Integer r = 1; r < lines.size(); r++) {
                    List<String> cols = parseCSVLine(lines[r]);
                    if (cols.size() < headers.size()) continue;

                    SObject delta = sType.newSObject();
                    safePut(delta, 'Problem__c', cols[col.get('problem')]);
                    safePut(delta, 'Rule__c', cols[col.get('rule')]);
                    safePut(delta, 'File__c', cols[col.get('file')]);
                    safePut(delta, 'Line__c', cols[col.get('templine')]);
                    safePut(delta, 'Engine__c', cols[col.get('engine')]);
                    safePut(delta, 'TargetBranch__c', cols[col.get('targetbranch')]);
                    safePut(delta, 'Violation_Status__c', 'Open');
                    safePut(delta, 'Last_Seen_Run_Id__c', currentRunId);
                    safePut(delta, 'Last_Seen_Date__c', System.now());

                    String key = buildKey(delta);
                    seenThisRun.add(key);

                    if (masterMap.containsKey(key)) {
                        SObject existing = masterMap.get(key);
                        existing.put('Violation_Status__c', 'Open');
                        existing.put('Last_Seen_Run_Id__c', currentRunId);
                        existing.put('Last_Seen_Date__c', System.now());
                        toUpdate.add(existing);
                    } else {
                        toInsert.add(delta);
                    }
                }
            }

            /* ---------------- CLOSE LOGIC ---------------- */
            for (SObject v : masterMap.values()) {
                String lastSeenRun = (String)v.get('Last_Seen_Run_Id__c');
                if (lastSeenRun != currentRunId) {
                    v.put('Violation_Status__c', 'Closed');
                    toUpdate.add(v);
                }
            }

            if (!toInsert.isEmpty()) insert toInsert;
            if (!toUpdate.isEmpty()) update toUpdate;

        } catch (Exception e) {
            System.debug(e.getMessage());
        }
    }

    /* ---------------- HELPERS ---------------- */

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
        try { r.put(f, v); } catch (Exception e) {}
    }

    public static List<String> parseCSVLine(String l) {
        List<String> out = new List<String>();
        Boolean q = false;
        String c = '';
        for (Integer i = 0; i < l.length(); i++) {
            String ch = l.substring(i, i+1);
            if (ch == '"') q = !q;
            else if (ch == ',' && !q) { out.add(c); c = ''; }
            else c += ch;
        }
        out.add(c);
        return out;
    }
}
