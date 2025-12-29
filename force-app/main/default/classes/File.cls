public with sharing class File {

    /* ============================================================
       CONSTANTS
    ============================================================ */
    private static final String VULN_OBJECT_LABEL = 'Vulnerability';
    private static final String STATUS_OPEN   = 'Open';
    private static final String STATUS_CLOSED = 'Closed';

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
            /* --------------------------------------------------------
               Resolve Vulnerability object dynamically (by LABEL)
            -------------------------------------------------------- */
            String vulnApiName = resolveVulnerabilityObjectApiName();
            if (String.isBlank(vulnApiName)) {
                System.debug('❌ Vulnerability object not found by label');
                return;
            }

            Schema.SObjectType vulnType =
                Schema.getGlobalDescribe().get(vulnApiName);

            /* --------------------------------------------------------
               Get uploaded CSV files
            -------------------------------------------------------- */
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

                /* ----------------------------------------------------
                   Header parsing
                ---------------------------------------------------- */
                List<String> headers = parseCSVLine(rows[0]);
                Map<String, Integer> colIndex = new Map<String, Integer>();
                for (Integer i = 0; i < headers.size(); i++) {
                    colIndex.put(headers[i].trim().toLowerCase(), i);
                }

                /* ----------------------------------------------------
                   Collections for this scan
                ---------------------------------------------------- */
                Set<String> currentKeys  = new Set<String>();
                Set<String> scannedFiles = new Set<String>();
                List<SObject> upsertRecords = new List<SObject>();

                String targetBranch;
                String repo;

                /* ----------------------------------------------------
                   Row processing
                ---------------------------------------------------- */
                for (Integer r = 1; r < rows.size(); r++) {
                    List<String> cols = parseCSVLine(rows[r]);
                    if (cols.isEmpty()) continue;

                    String problem     = getCol(cols, colIndex, 'problem');
                    String severity    = getCol(cols, colIndex, 'severity');
                    String fileName    = getCol(cols, colIndex, 'file');
                    String tempLine    = getCol(cols, colIndex, 'templine');
                    String column      = getCol(cols, colIndex, 'column');
                    String rule        = getCol(cols, colIndex, 'rule');
                    String description = getCol(cols, colIndex, 'description');
                    String url         = getCol(cols, colIndex, 'url');
                    String category    = getCol(cols, colIndex, 'category');
                    String engine      = getCol(cols, colIndex, 'engine');
                    String commitAuth  = getCol(cols, colIndex, 'commitauthor');
                    String actualLine  = getCol(cols, colIndex, 'actualline');
                    String branch      = getCol(cols, colIndex, 'targetbranch');
                    String repoVal     = getCol(cols, colIndex, 'repo');
                    String commitSha   = getCol(cols, colIndex, 'commitsha');
                    String runId       = getCol(cols, colIndex, 'runid');

                    if (String.isBlank(fileName) ||
                        String.isBlank(rule) ||
                        String.isBlank(problem)) {
                        continue;
                    }

                    scannedFiles.add(fileName);
                    if (targetBranch == null) targetBranch = branch;
                    if (repo == null) repo = repoVal;

                    /* ------------------------------------------------
                       Stable violation fingerprint
                    ------------------------------------------------ */
                    String keySource = String.join(new List<String>{
                        safe(repoVal),
                        safe(branch),
                        safe(fileName),
                        safe(engine),
                        safe(category),
                        safe(rule),
                        safe(problem),
                        safe(description)
                    }, '|');

                    String violationKey = EncodingUtil.convertToHex(
                        Crypto.generateDigest('SHA-256', Blob.valueOf(keySource))
                    );

                    currentKeys.add(violationKey);

                    /* ------------------------------------------------
                       Build Vulnerability record (dynamic)
                    ------------------------------------------------ */
                    SObject vuln = vulnType.newSObject();
                    vuln.put('Violation_Key__c', violationKey);
                    vuln.put('Problem__c', problem);
                    vuln.put('Severity__c', severity);
                    vuln.put('File__c', fileName);
                    vuln.put('Line__c', tempLine);
                    vuln.put('Column__c', column);
                    vuln.put('Rule__c', rule);
                    vuln.put('Description__c', description);
                    vuln.put('URL__c', url);
                    vuln.put('Category__c', category);
                    vuln.put('Engine__c', engine);
                    vuln.put('Commit__c', commitAuth);
                    vuln.put('ActualLine__c', actualLine);
                    vuln.put('TargetBranch__c', branch);
                    vuln.put('Repo__c', repoVal);
                    vuln.put('Commit_Sha__c', commitSha);
                    vuln.put('Run_Id__c', runId);
                    vuln.put('Violation_Status__c', STATUS_OPEN);
                    vuln.put('Last_Seen__c', System.now());

                    upsertRecords.add(vuln);
                }

                if (upsertRecords.isEmpty()) continue;

                /* ----------------------------------------------------
                   Preserve First_Seen__c and reopen if needed
                ---------------------------------------------------- */
                Map<String, SObject> existingByKey = new Map<String, SObject>();
                for (SObject rec : Database.query(
                    'SELECT Id, Violation_Key__c, First_Seen__c ' +
                    'FROM ' + vulnApiName +
                    ' WHERE Violation_Key__c IN :currentKeys'
                )) {
                    existingByKey.put(
                        (String)rec.get('Violation_Key__c'),
                        rec
                    );
                }

                for (SObject rec : upsertRecords) {
                    String key = (String)rec.get('Violation_Key__c');
                    if (!existingByKey.containsKey(key)) {
                        rec.put('First_Seen__c', System.now());
                    } else {
                        rec.put('Violation_Status__c', STATUS_OPEN);
                        rec.put('Closed_On__c', null);
                    }
                }

                /* ----------------------------------------------------
                   UPSERT (safe dynamic upsert)
                ---------------------------------------------------- */
                Database.upsert(upsertRecords, false);

                /* ----------------------------------------------------
                   AUTO-CLOSE FIXED VIOLATIONS (delta-aware)
                ---------------------------------------------------- */
                if (!scannedFiles.isEmpty()) {
                    List<SObject> toClose = Database.query(
                        'SELECT Id ' +
                        'FROM ' + vulnApiName +
                        ' WHERE Violation_Status__c = :STATUS_OPEN' +
                        ' AND File__c IN :scannedFiles' +
                        ' AND TargetBranch__c = :targetBranch' +
                        (String.isBlank(repo) ? '' : ' AND Repo__c = :repo') +
                        ' AND Violation_Key__c NOT IN :currentKeys'
                    );

                    for (SObject v : toClose) {
                        v.put('Violation_Status__c', STATUS_CLOSED);
                        v.put('Closed_On__c', System.now());
                    }

                    if (!toClose.isEmpty()) {
                        update toClose;
                    }
                }
            }

        } catch (Exception e) {
            System.debug('❌ ERROR: ' + e.getMessage());
            System.debug(e.getStackTraceString());
        }
    }

    /* ============================================================
       HELPERS
    ============================================================ */

    private static String resolveVulnerabilityObjectApiName() {
        for (String api : Schema.getGlobalDescribe().keySet()) {
            Schema.DescribeSObjectResult d =
                Schema.getGlobalDescribe().get(api).getDescribe();
            if (d.getLabel() == VULN_OBJECT_LABEL) {
                return api;
            }
        }
        return null;
    }

    private static String getCol(List<String> cols, Map<String,Integer> idx, String key) {
        Integer i = idx.get(key);
        return (i == null || i >= cols.size()) ? null : cols[i];
    }

    private static String safe(String s) {
        return s == null ? '' : s.trim();
    }

    private static List<String> parseCSVLine(String line) {
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
