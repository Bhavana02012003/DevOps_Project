public with sharing class File {

    private static final String VULN_OBJECT = 'Vulnerability__c';

    /* ================= ENTRY ================= */
    public static void processNewFiles(List<ContentVersion> newFiles) {
        Set<Id> docIds = new Set<Id>();
        for (ContentVersion cv : newFiles) {
            if (cv.ContentDocumentId != null) {
                docIds.add(cv.ContentDocumentId);
            }
        }
        if (!docIds.isEmpty()) {
            System.enqueueJob(new ImportJob(new List<Id>(docIds)));
        }
    }

    /* ================= QUEUEABLE ================= */
    public class ImportJob implements Queueable {

        private List<Id> docIds;

        public ImportJob(List<Id> docIds) {
            this.docIds = docIds;
        }

        public void execute(QueueableContext qc) {
            importCsv(docIds);
        }
    }

    /* ================= CORE LOGIC ================= */
    private static void importCsv(List<Id> docIds) {

        // Object existence check
        if (!Schema.getGlobalDescribe().containsKey(VULN_OBJECT)) {
            System.debug('❌ Vulnerability__c does not exist');
            return;
        }

        Schema.SObjectType sType = Schema.getGlobalDescribe().get(VULN_OBJECT);

        List<ContentVersion> files = [
            SELECT Id, Title, FileExtension, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND IsLatest = true
        ];

        for (ContentVersion cv : files) {

            if (cv.VersionData == null || cv.FileExtension != 'csv') continue;

            String csv = cv.VersionData.toString()
                .replace('\r\n', '\n')
                .replace('\r', '\n');

            List<String> rows = csv.split('\n');
            if (rows.size() < 2) continue;

            Map<String, Integer> headerIndex = buildHeaderIndex(rows[0]);
            List<SObject> records = new List<SObject>();

            for (Integer i = 1; i < rows.size(); i++) {

                if (String.isBlank(rows[i])) continue;

                List<String> cols = parseCSVLine(rows[i]);

                String fileName = getValue(cols, headerIndex, 'file');
                String problem  = getValue(cols, headerIndex, 'problem');

                if (String.isBlank(fileName) || String.isBlank(problem)) continue;

                SObject v = sType.newSObject();
                v.put('Problem__c', problem);
                v.put('File__c', fileName);
                v.put('Severity__c', getValue(cols, headerIndex, 'severity'));
                v.put('Rule__c', getValue(cols, headerIndex, 'rule'));
                v.put('Category__c', getValue(cols, headerIndex, 'category'));
                v.put('Engine__c', getValue(cols, headerIndex, 'engine'));
                v.put('Commit__c', getValue(cols, headerIndex, 'commit'));
                v.put('Line__c', getValue(cols, headerIndex, 'line'));
                v.put('Column__c', getValue(cols, headerIndex, 'column'));
                v.put('ActualLine__c', getValue(cols, headerIndex, 'actualline'));
                v.put('TargetBranch__c', getValue(cols, headerIndex, 'targetbranch'));
                v.put('Repo__c', getValue(cols, headerIndex, 'repo'));
                v.put('Violation_Status__c', 'Open');

                records.add(v);
            }

            if (records.isEmpty()) {
                System.debug('⚠️ No records parsed from CSV');
                continue;
            }

            Database.SaveResult[] results = Database.insert(records, false);

            for (Database.SaveResult r : results) {
                if (!r.isSuccess()) {
                    for (Database.Error e : r.getErrors()) {
                        System.debug('❌ INSERT ERROR: ' + e.getMessage());
                    }
                }
            }

            System.debug('✅ Insert attempted: ' + records.size());
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

    // 🔥 FIXED METHOD (NO RESERVED WORDS)
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
