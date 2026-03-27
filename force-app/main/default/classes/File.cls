public with sharing class File {

    private static final String VULN_OBJECT_API = 'Vulnerability__c';

    public static void processNewContentDocuments(Set<Id> contentDocIds) {

        System.debug('🔥 ENTRY: processNewContentDocuments');
        System.debug('📂 Incoming Doc IDs: ' + contentDocIds);

        if(contentDocIds == null || contentDocIds.isEmpty()){
            System.debug('❌ No ContentDocumentIds received');
            return;
        }

        // STEP 1: Create Case
        ensureStandardCasesExist(contentDocIds);

        // STEP 2: Create Vulnerabilities
        importVulnerabilityData(new List<Id>(contentDocIds));
    }

    // ================= CASE CREATION =================
    private static void ensureStandardCasesExist(Set<Id> contentDocIds) {

        System.debug('🔥 STEP 1: Creating Cases');

        List<ContentDocument> docs = [
            SELECT Id, Title
            FROM ContentDocument
            WHERE Id IN :contentDocIds
        ];

        List<Case> casesToInsert = new List<Case>();
        Map<Id, ContentDocument> pendingDocs = new Map<Id, ContentDocument>();

        for (ContentDocument doc : docs) {

            if (
                doc.Title != null &&
                doc.Title.toLowerCase().contains('code scanner')
            ) {

                Case c = new Case();
                c.Subject = 'Scanner Report - ' + doc.Title;
                c.Origin = 'Web';
                c.Status = 'New';
                c.File_Name__c = doc.Title;
                c.pk__c = 'new';

                // CSV → Case fields
                ContentVersion cv = [
                    SELECT VersionData FROM ContentVersion 
                    WHERE ContentDocumentId = :doc.Id LIMIT 1
                ];

                String csv = cv.VersionData.toString();
                List<String> rows = csv.split('\n');

                if(rows.size() > 1){
                    Map<String, Integer> headerIndex = buildHeaderIndex(rows[0]);
                    List<String> cols = parseCSVLine(rows[1]);

                    c.Target_Environment__c = getValue(cols, headerIndex, 'targetbranch');

                    String severity = getValue(cols, headerIndex, 'severity');

                    if(severity == '1' || severity == '2'){
                        c.Priority = 'High';
                    } else if(severity == '3'){
                        c.Priority = 'Medium';
                    } else {
                        c.Priority = 'Low';
                    }
                }

                casesToInsert.add(c);
                pendingDocs.put(doc.Id, doc);
            }
        }

        if (!casesToInsert.isEmpty()) {

            insert casesToInsert;

            List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
            Integer i = 0;
            List<Id> docIdList = new List<Id>(pendingDocs.keySet());

            for (Id docId : docIdList) {

                ContentDocumentLink link = new ContentDocumentLink();
                link.ContentDocumentId = docId;
                link.LinkedEntityId = casesToInsert[i].Id;
                link.ShareType = 'V';
                link.Visibility = 'AllUsers';

                linksToInsert.add(link);
                i++;
            }

            insert linksToInsert;
        }
    }

    // ================= VULNERABILITY =================
    private static void importVulnerabilityData(List<Id> contentDocIds) {

        System.debug('🔥 STEP 3: Creating Vulnerabilities');

        Map<Id, Id> fileToCaseMap = getFileToCaseMap(new Set<Id>(contentDocIds));

        if (fileToCaseMap.isEmpty()) return;

        // 🔥 GLOBAL SET (VERY IMPORTANT FIX)
        Set<String> globalKeys = new Set<String>();

        // 🔥 EXISTING RECORDS FROM DB
        List<Vulnerability__c> existingRecords = [
            SELECT Id, Case__c, Rule__c, File__c, Line__c
            FROM Vulnerability__c
            WHERE Case__c IN :fileToCaseMap.values()
        ];

        for(Vulnerability__c ev : existingRecords){
            String key = buildUniqueKey(
                ev.Case__c,
                ev.Rule__c,
                ev.File__c,
                String.valueOf(ev.Line__c)
            );
            globalKeys.add(key);
        }

        List<ContentVersion> versions = [
            SELECT Id, VersionData, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocIds
            AND IsLatest = true
        ];

        List<Vulnerability__c> recordsToInsert = new List<Vulnerability__c>();

        for (ContentVersion cv : versions) {

            Id caseId = fileToCaseMap.get(cv.ContentDocumentId);
            if (caseId == null) continue;

            String csv = cv.VersionData.toString();
            List<String> rows = csv.split('\n');

            if(rows.isEmpty()) continue;

            Map<String, Integer> headerIndex = buildHeaderIndex(rows[0]);

            for (Integer i = 1; i < rows.size(); i++) {

                if (String.isBlank(rows[i])) continue;

                List<String> cols = parseCSVLine(rows[i]);

                String rule = getValue(cols, headerIndex, 'rule');
                String file = getValue(cols, headerIndex, 'file');
                String line = getValue(cols, headerIndex, 'startline');

                // 🔥 BUILD UNIQUE KEY EARLY
                String uniqueKey = buildUniqueKey(caseId, rule, file, line);

                // 🔥 FINAL DUPLICATE CHECK (GLOBAL)
                if(globalKeys.contains(uniqueKey)){
                    System.debug('🚫 DUPLICATE BLOCKED: ' + uniqueKey);
                    continue;
                }

                // 🔥 ADD TO GLOBAL BEFORE INSERT
                globalKeys.add(uniqueKey);

                Vulnerability__c v = new Vulnerability__c();

                v.Case__c = caseId;
                v.Rule__c = rule;
                v.Engine__c = getValue(cols, headerIndex, 'engine');
                v.Severity__c = getValue(cols, headerIndex, 'severity');
                v.Category__c = getValue(cols, headerIndex, 'tags');
                v.File__c = file;
                v.Line__c = line;
                v.Column__c = getValue(cols, headerIndex, 'startcolumn');
                v.Description__c = getValue(cols, headerIndex, 'message');
                v.URL__c = getValue(cols, headerIndex, 'resources');
                v.Commit__c = getValue(cols, headerIndex, 'commitauthor');
                v.TargetBranch__c = getValue(cols, headerIndex, 'targetbranch');
                v.ActualLine__c = getValue(cols, headerIndex, 'actualline');
                v.Violation_Status__c = 'Open';

                recordsToInsert.add(v);
            }
        }

        System.debug('📌 FINAL INSERT COUNT: ' + recordsToInsert.size());

        if (!recordsToInsert.isEmpty()) {
            insert recordsToInsert;
        }
    }

    // ================= UNIQUE KEY =================
    private static String buildUniqueKey(Id caseId, String rule, String file, String line) {
        return String.valueOf(caseId) + '|' +
               String.valueOf(rule) + '|' +
               String.valueOf(file) + '|' +
               String.valueOf(line);
    }

    // ================= HELPERS =================
    private static Map<Id, Id> getFileToCaseMap(Set<Id> contentDocIds) {

        Map<Id, Id> fileToCaseMap = new Map<Id, Id>();

        for (ContentDocumentLink link : [
            SELECT LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :contentDocIds
        ]) {
            if(link.LinkedEntityId.getSObjectType() == Case.SObjectType){
                fileToCaseMap.put(link.ContentDocumentId, link.LinkedEntityId);
            }
        }

        return fileToCaseMap;
    }

    private static List<String> parseCSVLine(String line) {
        List<String> cols = new List<String>();
        Boolean inQuotes = false;
        String cur = '';

        for (Integer i = 0; i < line.length(); i++) {
            String c = line.substring(i, i+1);

            if (c == '"') {
                inQuotes = !inQuotes;
            } else if (c == ',' && !inQuotes) {
                cols.add(cur.trim());
                cur = '';
            } else {
                cur += c;
            }
        }

        cols.add(cur.trim());
        return cols;
    }

    private static Map<String, Integer> buildHeaderIndex(String header) {
        Map<String, Integer> mapIndex = new Map<String, Integer>();
        List<String> headers = parseCSVLine(header);

        for (Integer i = 0; i < headers.size(); i++) {
            mapIndex.put(normalize(headers[i]), i);
        }
        return mapIndex;
    }

    private static String getValue(List<String> cols, Map<String, Integer> index, String key) {
        String k = normalize(key);
        if (index.containsKey(k) && index.get(k) < cols.size()) {
            return cols[index.get(k)];
        }
        return null;
    }

    private static String normalize(String s) {
        return s == null ? '' : s.toLowerCase().replace(' ', '').replace('_', '');
    }
}