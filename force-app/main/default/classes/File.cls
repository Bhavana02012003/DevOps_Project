public with sharing class File {

    private static final String VULN_LABEL = 'Vulnerability';
    private static final String STATUS_OPEN   = 'Open';
    private static final String STATUS_CLOSED = 'Closed';

    /* ===================== ENTRY ===================== */
    public static void processNewFiles(List<ContentVersion> cvs) {
        Set<Id> docIds = new Set<Id>();
        for (ContentVersion cv : cvs) {
            if (cv.ContentDocumentId != null) {
                docIds.add(cv.ContentDocumentId);
            }
        }
        if (!docIds.isEmpty()) {
            importVulnerabilityData(new List<Id>(docIds));
        }
    }

    /* ===================== MAIN ===================== */
    public static void importVulnerabilityData(List<Id> contentDocIds) {

        String vulnApi = resolveVulnerabilityObjectApiName();
        if (String.isBlank(vulnApi)) {
            throw new AuraHandledException(
                'Vulnerability object not found by label'
            );
        }

        Schema.SObjectType vulnType =
            Schema.getGlobalDescribe().get(vulnApi);

        List<ContentVersion> files = [
            SELECT Id, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocIds
            ORDER BY CreatedDate DESC
        ];

        for (ContentVersion cv : files) {

            if (cv.VersionData == null) continue;

            List<String> rows = cv.VersionData.toString().split('\n');
            if (rows.size() < 2) continue;

            Map<String,Integer> idx = buildHeaderIndex(rows[0]);

            Set<String> currentKeys = new Set<String>();
            Set<String> scannedFiles = new Set<String>();

            List<SObject> toInsert = new List<SObject>();
            List<SObject> toUpdate = new List<SObject>();

            String repo;
            String branch;

            /* ---------- CSV PARSE ---------- */
            for (Integer i = 1; i < rows.size(); i++) {

                List<String> c = parseCSVLine(rows[i]);
                if (c.isEmpty()) continue;

                String fileName = get(c, idx, 'file');
                String problem  = get(c, idx, 'problem');
                String rule     = get(c, idx, 'rule');

                if (String.isBlank(fileName) || String.isBlank(problem)) continue;

                repo   = repo   == null ? get(c, idx, 'repo') : repo;
                branch = branch == null ? get(c, idx, 'targetbranch') : branch;

                scannedFiles.add(fileName);

                String keySource = String.join(new List<String>{
                    safe(repo),
                    safe(branch),
                    safe(fileName),
                    safe(rule),
                    safe(problem)
                }, '|');

                String vKey = EncodingUtil.convertToHex(
                    Crypto.generateDigest('SHA-256', Blob.valueOf(keySource))
                );

                currentKeys.add(vKey);

                SObject v = vulnType.newSObject();
                v.put('Violation_Key__c', vKey);
                v.put('Problem__c', problem);
                v.put('Severity__c', get(c, idx, 'severity'));
                v.put('File__c', fileName);
                v.put('Line__c', get(c, idx, 'templine'));
                v.put('Rule__c', rule);
                v.put('Category__c', get(c, idx, 'category'));
                v.put('Engine__c', get(c, idx, 'engine'));
                v.put('Repo__c', repo);
                v.put('TargetBranch__c', branch);
                v.put('Violation_Status__c', STATUS_OPEN);
                v.put('Last_Seen__c', System.now());

                toInsert.add(v);
            }

            if (toInsert.isEmpty()) continue;

            /* ---------- EXISTING ---------- */
            Map<String, SObject> existing = new Map<String, SObject>();
            for (SObject e : Database.query(
                'SELECT Id, Violation_Key__c FROM ' + vulnApi +
                ' WHERE Violation_Key__c IN :currentKeys'
            )) {
                existing.put((String)e.get('Violation_Key__c'), e);
            }

            List<SObject> finalInsert = new List<SObject>();

            for (SObject v : toInsert) {
                String k = (String)v.get('Violation_Key__c');
                if (!existing.containsKey(k)) {
                    v.put('First_Seen__c', System.now());
                    finalInsert.add(v);
                } else {
                    SObject upd = existing.get(k);
                    upd.put('Violation_Status__c', STATUS_OPEN);
                    upd.put('Closed_On__c', null);
                    upd.put('Last_Seen__c', System.now());
                    toUpdate.add(upd);
                }
            }

            Database.SaveResult[] insRes =
                Database.insert(finalInsert, false);
            Database.SaveResult[] updRes =
                Database.update(toUpdate, false);

            logResults(insRes);
            logResults(updRes);

            /* ---------- AUTO CLOSE ---------- */
            List<SObject> toClose = Database.query(
                'SELECT Id FROM ' + vulnApi +
                ' WHERE Violation_Status__c = :STATUS_OPEN' +
                ' AND File__c IN :scannedFiles' +
                ' AND TargetBranch__c = :branch' +
                ' AND Repo__c = :repo' +
                ' AND Violation_Key__c NOT IN :currentKeys'
            );

            for (SObject cRec : toClose) {
                cRec.put('Violation_Status__c', STATUS_CLOSED);
                cRec.put('Closed_On__c', System.now());
            }

            if (!toClose.isEmpty()) Database.update(toClose, false);
        }
    }

    /* ===================== HELPERS ===================== */

    private static void logResults(Database.SaveResult[] r) {
        if (r == null) return;
        for (Database.SaveResult sr : r) {
            if (!sr.isSuccess()) {
                for (Database.Error e : sr.getErrors()) {
                    System.debug('❌ DML ERROR: ' + e.getMessage());
                }
            }
        }
    }

    private static String resolveVulnerabilityObjectApiName() {
        for (String api : Schema.getGlobalDescribe().keySet()) {
            if (Schema.getGlobalDescribe().get(api)
                .getDescribe().getLabel() == VULN_LABEL) {
                return api;
            }
        }
        return null;
    }

    private static Map<String,Integer> buildHeaderIndex(String h) {
        Map<String,Integer> m = new Map<String,Integer>();
        List<String> p = parseCSVLine(h);
        for (Integer i = 0; i < p.size(); i++) {
            m.put(p[i].toLowerCase().trim(), i);
        }
        return m;
    }

    private static String get(List<String> r, Map<String,Integer> m, String k) {
        return (m.containsKey(k) && m.get(k) < r.size()) ? r[m.get(k)] : null;
    }

    private static String safe(String s) {
        return s == null ? '' : s.trim();
    }

    private static List<String> parseCSVLine(String line) {
        List<String> res = new List<String>();
        Boolean q = false;
        String c = '';
        for (Integer i = 0; i < line.length(); i++) {
            String ch = line.substring(i,i+1);
            if (ch == '"') q = !q;
            else if (ch == ',' && !q) { res.add(c.trim()); c=''; }
            else c+=ch;
        }
        res.add(c.trim());
        return res;
    }
}
