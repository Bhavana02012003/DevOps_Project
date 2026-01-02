public with sharing class File {

    private static final String VULN_OBJECT_API = 'Vulnerability__c';

    /* ================= ENTRY ================= */
    public static void processNewFiles(List<ContentVersion> contentVersions) {

        Set<Id> contentDocIds = new Set<Id>();

        for (ContentVersion cv : contentVersions) {
            if (cv.ContentDocumentId != null) {
                contentDocIds.add(cv.ContentDocumentId);
            }
        }

        if (!contentDocIds.isEmpty()) {
            importVulnerabilityData(new List<Id>(contentDocIds));
        }
    }

    /* ================= CORE ================= */
    private static void importVulnerabilityData(List<Id> contentDocIds) {

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(VULN_OBJECT_API)) {
            System.debug('❌ Object not found: ' + VULN_OBJECT_API);
            return;
        }

        Schema.SObjectType vulnType = gd.get(VULN_OBJECT_API);

        List<ContentVersion> versions = [
            SELECT Id, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocIds
            AND IsLatest = true
        ];

        List<SObject> recordsToInsert = new List<SObject>();

        for (ContentVersion cv : versions) {

            if (cv.VersionData == null) continue;

            String csv = cv.VersionData.toString()
                .replace('\r\n', '\n')
                .replace('\r', '\n');

            List<String> rows = csv.split('\n');
            if (rows.size() < 2) continue;

            Map<String, Integer> headerIndex = buildHeaderIndex(rows[0]);

            for (Integer i = 1; i < rows.size(); i++) {

                if (String.isBlank(rows[i])) continue;

                List<String> cols = parseCSVLine(rows[i]);

                String problem = getValue(cols, headerIndex, 'problem');
                String file    = getValue(cols, headerIndex, 'file');

                if (String.isBlank(problem) || String.isBlank(file)) continue;

                SObject vuln = vulnType.newSObject();

                vuln.put('Problem__c', problem);
                vuln.put('Severity__c', getValue(cols, headerIndex, 'severity'));
                vuln.put('File__c', file);
                vuln.put('Line__c', getValue(cols, headerIndex, 'templine'));
                vuln.put('Column__c', getValue(cols, headerIndex, 'column'));
                vuln.put('Rule__c', getValue(cols, headerIndex, 'rule'));
                vuln.put('Description__c', getValue(cols, headerIndex, 'description'));
                vuln.put('URL__c', getValue(cols, headerIndex, 'url'));
                vuln.put('Category__c', getValue(cols, headerIndex, 'category'));
                vuln.put('Engine__c', getValue(cols, headerIndex, 'engine'));

                /* ================= SAFE AUTO-POPULATION ================= */

                // Commit Author → supports CommitAuthor OR Commit
                String commitAuthor =
                    getValue(cols, headerIndex, 'commitauthor') != null
                    ? getValue(cols, headerIndex, 'commitauthor')
                    : getValue(cols, headerIndex, 'commit');

                vuln.put('Commit_Author__c', commitAuthor);

                vuln.put('ActualLine__c', getValue(cols, headerIndex, 'actualline'));
                vuln.put('TargetBranch__c', getValue(cols, headerIndex, 'targetbranch'));

                // Repo (safe)
                vuln.put('Repo__c',
                    getValue(cols, headerIndex, 'repo')
                );

                // Commit SHA → supports CommitSha OR Commit_Sha
                vuln.put('Commit_Sha__c',
                    getValue(cols, headerIndex, 'commitsha') != null
                    ? getValue(cols, headerIndex, 'commitsha')
                    : getValue(cols, headerIndex, 'commit_sha')
                );

                // Run Id → supports RunId OR Run_Id
                vuln.put('Run_Id__c',
                    getValue(cols, headerIndex, 'runid') != null
                    ? getValue(cols, headerIndex, 'runid')
                    : getValue(cols, headerIndex, 'run_id')
                );

                vuln.put('Violation_Status__c', 'Open');

                recordsToInsert.add(vuln);
            }
        }

        if (!recordsToInsert.isEmpty()) {
            Database.insert(recordsToInsert, false);
            System.debug('✅ Insert attempted: ' + recordsToInsert.size());
        } else {
            System.debug('⚠️ No records created from CSV');
        }
    }

    /* ================= HELPERS ================= */

    private static Map<String, Integer> buildHeaderIndex(String header) {
        Map<String, Integer> indexMap = new Map<String, Integer>();
        List<String> headers = parseCSVLine(header);

        for (Integer i = 0; i < headers.size(); i++) {
            indexMap.put(normalize(headers[i]), i);
        }
        return indexMap;
    }

    private static String getValue(
        List<String> row,
        Map<String, Integer> headerIndex,
        String key
    ) {
        String normalizedKey = normalize(key);
        if (headerIndex.containsKey(normalizedKey)
            && headerIndex.get(normalizedKey) < row.size()) {
            return row[headerIndex.get(normalizedKey)];
        }
        return null;
    }

    private static String normalize(String s) {
        return s == null ? ''
            : s.toLowerCase()
                .replace(' ', '')
                .replace('_', '')
                .replace('-', '');
    }

    private static List<String> parseCSVLine(String line) {
        List<String> cols = new List<String>();
        Boolean inQuotes = false;
        String cur = '';

        for (Integer i = 0; i < line.length(); i++) {
            String c = line.substring(i, i + 1);
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
}
