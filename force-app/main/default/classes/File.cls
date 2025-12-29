public with sharing class File {

    /* ===================== CONSTANTS ===================== */
    private static final String VULN_OBJECT_LABEL = 'Vulnerability';
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
            System.debug('❌ Vulnerability object not found');
            return;
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

            List<SObject> inserts = new List<SObject>();
            List<SObject> updates = new List<SObject>();

            String targetBranch;
            String repo;

            /* ---------- Parse CSV ---------- */
            for (Integer i = 1; i < rows.size(); i++) {

                List<String> c = parseCSVLine(rows[i]);
                if (c.isEmpty()) continue;

                String fileName = get(c, idx, 'file');
                String rule     = get(c, idx, 'rule');
                String problem  = get(c, idx, 'problem');
                if (String.isBlank(fileName) || String.isBlank(rule)) continue;

                scannedFiles.add(fileName);
                if (targetBranch == null) targetBranch = get(c, idx, 'targetbranch');
                if (repo == null) repo = get(c, idx, 'repo');

                String keySource = String.join(new List<String>{
                    safe(get(c, idx, 'repo')),
                    safe(get(c, idx, 'targetbranch')),
                    safe(fileName),
                    safe(get(c, idx, 'engine')),
                    safe(get(c, idx, 'category')),
                    safe(rule),
                    safe(problem),
                    safe(get(c, idx, 'description'))
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
                v.put('TargetBranch__c', get(c, idx, 'targetbranch'));
                v.put('Repo__c', repo);
                v.put('Violation_Status__c', STATUS_OPEN);
                v.put('Last_Seen__c', System.now());

                inserts.add(v);
            }

            if (inserts.isEmpty()) continue;

            /* ---------- Existing lookup ---------- */
            Map<String,SObject> existing = new Map<String,SObject>();
            for (SObject e : Database.query(
                'SELECT Id, Violation_Key__c FROM ' + vulnApi +
                ' WHERE Violation_Key__c IN :currentKeys'
            )) {
                existing.put((String)e.get('Violation_Key__c'), e);
            }

            List<SObject> finalInsert = new List<SObject>();
            for (SObject v : inserts) {
                String k = (String)v.get('Violation_Key__c');
                if (!existing.containsKey(k)) {
                    v.put('First_Seen__c', System.now());
                    finalInsert.add(v);
                } else {
                    SObject upd = existing.get(k);
                    upd.put('Violation_Status__c', STATUS_OPEN);
                    upd.put('Closed_On__c', null);
                    upd.put('Last_Seen__c', System.now());
                    updates.add(upd);
                }
            }

            if (!finalInsert.isEmpty()) insert finalInsert;
            if (!updates.isEmpty()) update updates;

            /* ---------- AUTO CLOSE ---------- */
            List<SObject> toClose = Database.query(
                'SELECT Id FROM ' + vulnApi +
                ' WHERE Violation_Status__c = :STATUS_OPEN' +
                ' AND File__c IN :scannedFiles' +
                ' AND TargetBranch__c = :targetBranch' +
                ' AND Repo__c = :repo' +
                ' AND Violation_Key__c NOT IN :currentKeys'
            );

            for (SObject c : toClose) {
                c.put('Violation_Status__c', STATUS_CLOSED);
                c.put('Closed_On__c', System.now());
            }

            if (!toClose.isEmpty()) update toClose;
        }
    }

    /* ===================== HELPERS ===================== */
    private static String resolveVulnerabilityObjectApiName() {
        for (String api : Schema.getGlobalDescribe().keySet()) {
            if (Schema.getGlobalDescribe().get(api).getDescribe().getLabel()
                == VULN_OBJECT_LABEL) {
                return api;
            }
        }
        return null;
    }

    private static Map<String,Integer> buildHeaderIndex(String header) {
        Map<String,Integer> m = new Map<String,Integer>();
        List<String> h = parseCSVLine(header);
        for (Integer i = 0; i < h.size(); i++) {
            m.put(h[i].toLowerCase().trim(), i);
        }
        return m;
    }

    private static String get(List<String> r, Map<String,Integer> m, String k) {
        return m.containsKey(k) && m.get(k) < r.size() ? r[m.get(k)] : null;
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
            else if (ch == ',' && !q) { res.add(c); c=''; }
            else c+=ch;
        }
        res.add(c);
        return res;
    }
}
