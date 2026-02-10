public with sharing class File {

    // IMPORTANT: DO NOT hardcode Vulnerability__c type
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

    public static void processNewContentDocuments(Set<Id> contentDocIds) {
        importVulnerabilityData(new List<Id>(contentDocIds));
    }


    /* ================= CORE ================= */
    private static void importVulnerabilityData(List<Id> contentDocIds) {

        // 1️⃣ Check object exists (runtime-safe)
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(VULN_OBJECT_API)) {
            System.debug('❌ Object not found: ' + VULN_OBJECT_API);
            return;
        }

        Schema.SObjectType vulnType = gd.get(VULN_OBJECT_API);

        // 2️⃣ Get latest CSV files
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

            // 3️⃣ Parse rows
            for (Integer i = 1; i < rows.size(); i++) {

                if (String.isBlank(rows[i])) continue;

                List<String> cols = parseCSVLine(rows[i]);

                String rule = getValue(cols, headerIndex, 'rule');
                String file = getValue(cols, headerIndex, 'file');

                if (String.isBlank(rule) || String.isBlank(file)) continue;

                SObject vuln = vulnType.newSObject();

                // ⭐ CORE FIELDS FROM CSV
                vuln.put('Rule__c', rule);
                vuln.put('Engine__c', getValue(cols, headerIndex, 'engine'));
                vuln.put('Severity__c', getValue(cols, headerIndex, 'severity'));
                vuln.put('Category__c', getValue(cols, headerIndex, 'tags'));
                vuln.put('File__c', file);
                vuln.put('Line__c', getValue(cols, headerIndex, 'startline'));
                vuln.put('Column__c', getValue(cols, headerIndex, 'startcolumn'));
                vuln.put('Description__c', getValue(cols, headerIndex, 'message'));
                vuln.put('URL__c', getValue(cols, headerIndex, 'resources'));

                // ⭐ CI/CD METADATA
                vuln.put('Commit__c', getValue(cols, headerIndex, 'commitauthor'));
                vuln.put('ActualLine__c', getValue(cols, headerIndex, 'actualline'));
                vuln.put('TargetBranch__c', getValue(cols, headerIndex, 'targetbranch'));

                // ⭐ DEFAULT STATUS
                vuln.put('Violation_Status__c', 'Open');

                recordsToInsert.add(vuln);
            }
        }

        // 5️⃣ Insert
        if (!recordsToInsert.isEmpty()) {
            Database.SaveResult[] results = Database.insert(recordsToInsert, false);

            for (Database.SaveResult r : results) {
                if (!r.isSuccess()) {
                    for (Database.Error e : r.getErrors()) {
                        System.debug('❌ INSERT ERROR: ' + e.getMessage());
                    }
                }
            }

            System.debug('✅ Insert attempted: ' + recordsToInsert.size());
        } else {
            System.debug('⚠️ No records created from CSV File');
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

    // CSV parser (quoted-safe)
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
