public with sharing class File {

    // Change this only if your org uses a different label
    private static final String VULN_OBJECT_LABEL = 'Vulnerability';

    public static void processNewFiles(List<ContentVersion> contentVersions) {
        List<Id> contentDocIds = new List<Id>();
        for (ContentVersion cv : contentVersions) {
            if (cv.ContentDocumentId != null) contentDocIds.add(cv.ContentDocumentId);
        }
        if (!contentDocIds.isEmpty()) {
            importVulnerabilityData(contentDocIds);
        }
    }

    public static void importVulnerabilityData(List<Id> contentDocIds) {
        try {
            // 1) Resolve Vulnerability object API name dynamically (handles namespaces too)
            String vulnObjectApi = resolveVulnerabilityObjectApiName();
            if (String.isBlank(vulnObjectApi)) {
                System.debug('❌ Could not find Vulnerability object in this org.');
                return;
            }

            // 2) Validate required fields exist on that object
            Schema.SObjectType sType = Schema.getGlobalDescribe().get(vulnObjectApi);
            if (sType == null) {
                System.debug('❌ Resolved object api not found: ' + vulnObjectApi);
                return;
            }

            Map<String, Schema.SObjectField> fields = sType.getDescribe().fields.getMap();
            List<String> requiredFields = new List<String>{
                'Problem__c','Rule__c','File__c','Line__c','Engine__c','TargetBranch__c','Violation_Status__c'
            };
            for (String f : requiredFields) {
                if (!fields.containsKey(f)) {
                    System.debug('❌ Missing required field on ' + vulnObjectApi + ': ' + f);
                    return;
                }
            }

            // 3) Load incoming CSV files
            List<ContentVersion> fileList = [
                SELECT Id, VersionData
                FROM ContentVersion
                WHERE ContentDocumentId IN :contentDocIds
                ORDER BY CreatedDate DESC
            ];
            if (fileList.isEmpty()) return;

            // 4) MASTER: load all existing violations -> map by key
            // (If you want "Master" to be only for changed files, we can filter by file names from delta later)
            Map<String, SObject> masterMap = new Map<String, SObject>();
            {
                String soql =
                    'SELECT Id, Problem__c, Rule__c, File__c, Line__c, Engine__c, TargetBranch__c, Violation_Status__c ' +
                    'FROM ' + vulnObjectApi;
                for (SObject rec : Database.query(soql)) {
                    masterMap.put(buildKey(rec), rec);
                }
            }

            // 5) DELTA: parse CSV and build delta keys + insert/update lists
            Set<String> deltaKeys = new Set<String>();
            List<SObject> recordsToInsert = new List<SObject>();
            List<SObject> recordsToUpdate = new List<SObject>();

            for (ContentVersion cv : fileList) {
                if (cv.VersionData == null) continue;

                String csvContent = cv.VersionData.toString();
                List<String> lines = csvContent.split('\\n');
                if (lines.size() < 2) continue;

                List<String> headers = parseCSVLine(lines[0]);
                Map<String, Integer> columnMap = new Map<String, Integer>();
                for (Integer i = 0; i < headers.size(); i++) {
                    columnMap.put(headers[i].trim().toLowerCase(), i);
                }

                // Required CSV columns (based on your GitHub report)
                List<String> requiredCsv = new List<String>{
                    'problem','severity','file','templine','column','rule','description','url','category','engine','commit','actualline','targetbranch'
                };
                for (String c : requiredCsv) {
                    if (!columnMap.containsKey(c)) {
                        System.debug('❌ Missing required CSV column: ' + c);
                        return;
                    }
                }

                for (Integer r = 1; r < lines.size(); r++) {
                    List<String> cols = parseCSVLine(lines[r]);
                    if (cols.size() < headers.size()) continue;

                    // Create a dynamic sObject record
                    SObject delta = sType.newSObject();

                    // Populate fields (must exist on object, else ignore gracefully)
                    safePut(delta, 'Problem__c', cols[columnMap.get('problem')].trim());
                    safePut(delta, 'Severity__c', cols[columnMap.get('severity')].trim());
                    safePut(delta, 'File__c', cols[columnMap.get('file')].trim());
                    safePut(delta, 'Line__c', cols[columnMap.get('templine')].trim());
                    safePut(delta, 'Column__c', cols[columnMap.get('column')].trim());
                    safePut(delta, 'Rule__c', cols[columnMap.get('rule')].trim());
                    safePut(delta, 'Description__c', cols[columnMap.get('description')].trim());
                    safePut(delta, 'URL__c', cols[columnMap.get('url')].trim());
                    safePut(delta, 'Category__c', cols[columnMap.get('category')].trim());
                    safePut(delta, 'Engine__c', cols[columnMap.get('engine')].trim());
                    safePut(delta, 'Commit__c', cols[columnMap.get('commit')].trim());
                    safePut(delta, 'ActualLine__c', cols[columnMap.get('actualline')].trim());
                    safePut(delta, 'TargetBranch__c', cols[columnMap.get('targetbranch')].trim());

                    // Open for delta records
                    safePut(delta, 'Violation_Status__c', 'Open');

                    String key = buildKey(delta);
                    deltaKeys.add(key);

                    if (masterMap.containsKey(key)) {
                        SObject existing = masterMap.get(key);

                        String existingStatus = (String)existing.get('Violation_Status__c');
                        if (existingStatus != 'Open') {
                            existing.put('Violation_Status__c', 'Open');
                            recordsToUpdate.add(existing);
                        }
                    } else {
                        recordsToInsert.add(delta);
                    }
                }
            }

            // 6) CLOSED = Master - Delta
            for (String key : masterMap.keySet()) {
                if (!deltaKeys.contains(key)) {
                    SObject rec = masterMap.get(key);
                    String st = (String)rec.get('Violation_Status__c');
                    if (st == null || st == 'Open') {
                        rec.put('Violation_Status__c', 'Closed');
                        recordsToUpdate.add(rec);
                    }
                }
            }

            // 7) DML
            if (!recordsToInsert.isEmpty()) insert recordsToInsert;
            if (!recordsToUpdate.isEmpty()) update recordsToUpdate;

            System.debug('✅ Inserted: ' + recordsToInsert.size() + ', Updated: ' + recordsToUpdate.size());

        } catch (Exception e) {
            System.debug('❌ Error processing vulnerabilities: ' + e.getMessage());
            System.debug(e.getStackTraceString());
        }
    }

    // ----------------- Helpers -----------------

    // Finds Vulnerability object even if namespaced
    private static String resolveVulnerabilityObjectApiName() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();

        // 1) Direct hit: Vulnerability__c
        if (gd.containsKey('Vulnerability__c')) return 'Vulnerability__c';

        // 2) Namespaced: ns__Vulnerability__c
        for (String api : gd.keySet()) {
            if (api != null && api.endsWith('__Vulnerability__c')) return api;
        }

        // 3) Fallback by Label = "Vulnerability"
        for (String api : gd.keySet()) {
            Schema.SObjectType t = gd.get(api);
            if (t == null) continue;
            String lbl = t.getDescribe().getLabel();
            if (lbl == VULN_OBJECT_LABEL) return api;
        }

        return null;
    }

    // Build key from fields used for Master/Delta matching
    private static String buildKey(SObject rec) {
        return String.join(new List<String>{
            String.valueOf(rec.get('Problem__c')),
            String.valueOf(rec.get('Rule__c')),
            String.valueOf(rec.get('File__c')),
            String.valueOf(rec.get('Line__c')),
            String.valueOf(rec.get('Engine__c')),
            String.valueOf(rec.get('TargetBranch__c'))
        }, '|');
    }

    // Safe put if field exists on record
    private static void safePut(SObject rec, String fieldApi, Object val) {
        try {
            rec.put(fieldApi, val);
        } catch (Exception ignore) {
            // If field doesn't exist in this org, ignore silently
        }
    }

    // CSV Parsing Function (Handles Quoted Values)
    public static List<String> parseCSVLine(String csvLine) {
        List<String> columns = new List<String>();
        Boolean insideQuote = false;
        String currentValue = '';

        for (Integer i = 0; i < csvLine.length(); i++) {
            String c = csvLine.substring(i, i + 1);

            if (c == '"') {
                insideQuote = !insideQuote;
            } else if (c == ',' && !insideQuote) {
                columns.add(currentValue.trim());
                currentValue = '';
            } else {
                currentValue += c;
            }
        }

        columns.add(currentValue.trim());
        return columns;
    }
}
