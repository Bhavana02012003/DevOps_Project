public with sharing class File {

    // ---- CONFIG ----
    private static final String VULN_OBJECT_API = 'Vulnerability__c';

    private static final String STATUS_OPEN   = 'Open';
    private static final String STATUS_CLOSED = 'Closed';

    /* ===================== ENTRY POINT ===================== */
    public static void processNewFiles(List<ContentVersion> contentVersions) {
        Set<Id> docIds = new Set<Id>();
        for (ContentVersion cv : contentVersions) {
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

        // 1) Validate object exists in THIS org at runtime
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(VULN_OBJECT_API)) {
            // This is the REAL reason you see "Invalid type" when you hardcode Vulnerability__c
            System.debug('❌ Object not found in this org: ' + VULN_OBJECT_API);
            return;
        }

        Schema.SObjectType vulnType = gd.get(VULN_OBJECT_API);

        // 2) Load latest file versions
        List<ContentVersion> files = [
            SELECT Id, VersionData, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocIds
            ORDER BY CreatedDate DESC
        ];

        for (ContentVersion cv : files) {

            if (cv.VersionData == null) continue;

            // Handle CRLF + LF
            String csv = cv.VersionData.toString();
            csv = csv.replace('\r\n', '\n').replace('\r', '\n');

            List<String> rows = csv.split('\n');
            if (rows.size() < 2) continue;

            Map<String, Integer> idx = buildHeaderIndex(rows[0]);

            Set<String> currentKeys  = new Set<String>();
            Set<String> scannedFiles = new Set<String>();

            List<SObject> staged = new List<SObject>();

            String repo;
            String branch;

            // 3) Parse CSV lines
            for (Integer i = 1; i < rows.size(); i++) {

                if (String.isBlank(rows[i])) continue;

                List<String> cols = parseCSVLine(rows[i]);
                if (cols.isEmpty()) continue;

                String fileName = get(cols, idx, 'file');
                String problem  = get(cols, idx, 'problem');
                String rule     = get(cols, idx, 'rule');

                // Keep this minimal to avoid skipping all rows
                if (String.isBlank(fileName) || String.isBlank(problem)) continue;

                if (repo == null)   repo   = get(cols, idx, 'repo');
                if (branch == null) branch = get(cols, idx, 'targetbranch');

                scannedFiles.add(fileName);

                // 4) Create stable key (same as your approach)
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

                // 5) Create dynamic SObject record
                SObject v = vulnType.newSObject();
                v.put('Violation_Key__c', vKey);
                v.put('Problem__c', problem);
                v.put('Severity__c', get(cols, idx, 'severity'));
                v.put('File__c', fileName);
                v.put('Line__c', get(cols, idx, 'templine'));
                v.put('Column__c', get(cols, idx, 'column'));
                v.put('Rule__c', rule);
                v.put('Description__c', get(cols, idx, 'description'));
                v.put('URL__c', get(cols, idx, 'url'));
                v.put('Category__c', get(cols, idx, 'category'));
                v.put('Engine__c', get(cols, idx, 'engine'));
                v.put('Commit__c', get(cols, idx, 'commit'));
                v.put('ActualLine__c', get(cols, idx, 'actualline'));
                v.put('TargetBranch__c', branch);
                v.put('Repo__c', repo);

                v.put('Violation_Status__c', STATUS_OPEN);
                v.put('Last_Seen__c', System.now());

                staged.add(v);
            }

            if (staged.isEmpty()) continue;

            // 6) Fetch existing by key
            Map<String, SObject> existingByKey = new Map<String, SObject>();
            for (SObject e : Database.query(
                'SELECT Id, Violation_Key__c FROM ' + VULN_OBJECT_API +
                ' WHERE Violation_Key__c IN :currentKeys'
            )) {
                existingByKey.put((String)e.get('Violation_Key__c'), e);
            }

            List<SObject> toInsert = new List<SObject>();
            List<SObject> toUpdate = new List<SObject>();

            for (SObject v : staged) {
                String k = (String)v.get('Violation_Key__c');
                if (!existingByKey.containsKey(k)) {
                    v.put('First_Seen__c', System.now());
                    toInsert.add(v);
                } else {
                    SObject upd = existingByKey.get(k);
                    upd.put('Violation_Status__c', STATUS_OPEN);
                    upd.put('Closed_On__c', null);
                    upd.put('Last_Seen__c', System.now());
                    toUpdate.add(upd);
                }
            }

            // 7) DML (partial success)
            Database.SaveResult[] insRes = Database.insert(toInsert, false);
            Database.SaveResult[] updRes = Database.update(toUpdate, false);
            logResults('INSERT', insRes);
            logResults('UPDATE', updRes);

            // 8) Auto-close fixed ones (same file + repo + branch, not present now)
            if (!String.isBlank(repo) && !String.isBlank(branch) && !scannedFiles.isEmpty()) {

                List<SObject> toClose = Database.query(
                    'SELECT Id FROM ' + VULN_OBJECT_API +
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

                Database.SaveResult[] closeRes = Database.update(toClose, false);
                logResults('CLOSE', closeRes);
            }
        }
    }

    /* ===================== LOGGING ===================== */
    private static void logResults(String label, Database.SaveResult[] results) {
        if (results == null) return;
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                for (Database.Error e : sr.getErrors()) {
                    System.debug('❌ ' + label + ' ERROR: ' + e.getStatusCode() + ' - ' + e.getMessage());
                }
            }
        }
    }

    /* ===================== HELPERS ===================== */
    private static Map<String,Integer> buildHeaderIndex(String header) {
        Map<String,Integer> m = new Map<String,Integer>();
        List<String> h = parseCSVLine(header);
        for (Integer i = 0; i < h.size(); i++) {
            m.put(h[i].toLowerCase().trim().replace(' ', ''), i);
        }
        return m;
    }

    // Supports both "targetbranch" and "target branch"
    private static String get(List<String> row, Map<String,Integer> idx, String key) {
        if (row == null || idx == null || String.isBlank(key)) return null;
        String k = key.toLowerCase().trim().replace(' ', '');
        if (idx.containsKey(k) && idx.get(k) < row.size()) return row[idx.get(k)];
        return null;
    }

    private static String safe(String s) {
        return s == null ? '' : s.trim();
    }

    // Basic CSV parsing with quotes support
    public static List<String> parseCSVLine(String line) {
        List<String> cols = new List<String>();
        if (line == null) return cols;

        Boolean inQuotes = false;
        String current = '';

        for (Integer i = 0; i < line.length(); i++) {
            String ch = line.substring(i, i + 1);
            if (ch == '"') {
                inQuotes = !inQuotes;
            } else if (ch == ',' && !inQuotes) {
                cols.add(current.trim());
                current = '';
            } else {
                current += ch;
            }
        }
        cols.add(current.trim());
        return cols;
    }
}
