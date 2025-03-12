public with sharing class File {
    public static void importVulnerabilityData(Id contentDocId) {
        try {
            // ✅ Fetch ContentVersion using ContentDocumentId
            List<ContentVersion> fileList = [SELECT Id, VersionData 
                                             FROM ContentVersion 
                                             WHERE ContentDocumentId = :contentDocId 
                                             ORDER BY CreatedDate DESC 
                                             LIMIT 1];

            if (fileList.isEmpty()) {
                System.debug('❌ No ContentVersion found for ContentDocumentId: ' + contentDocId);
                return;
            }

            ContentVersion file = fileList[0];

            if (file.VersionData == null) {
                System.debug('❌ File content is empty.');
                return;
            }

            System.debug('✅ Processing file: ' + file.Id);

            String csvContent = file.VersionData.toString();
            List<String> lines = csvContent.split('\\n');

            if (lines.isEmpty()) {
                System.debug('❌ CSV file is empty.');
                return;
            }

            // ✅ Extract headers & normalize (trim & lowercase)
            List<String> headers = parseCSVLine(lines[0]);
            Map<String, Integer> columnMap = new Map<String, Integer>();

            for (Integer i = 0; i < headers.size(); i++) {
                String normalizedHeader = headers[i].trim().toLowerCase();
                columnMap.put(normalizedHeader, i);
            }

            System.debug('🔍 Available columns in CSV: ' + columnMap.keySet());

            // ✅ Required Fields Mapping (Ensure exact column names)
            Map<String, String> fieldMappings = new Map<String, String>{
                'problem' => 'problem', 
                'severity' => 'severity', 
                'file' => 'file', 
                'templine' => 'line', 
                'column' => 'column', 
                'rule' => 'rule',
                'description' => 'description', 
                'url' => 'url', 
                'category' => 'category', 
                'engine' => 'engine', 
                'commit' => 'commit', 
                'actualline' => 'actual line', 
                'targetbranch' => 'target branch'
            };

            // ✅ Ensure all required fields exist
            for (String field : fieldMappings.keySet()) {
                if (!columnMap.containsKey(field.toLowerCase())) { // Normalize case
                    System.debug('❌ Missing required column: ' + field);
                    return;
                }
            }

            // ✅ Parse CSV & create Vulnerability__c records
            List<Vulnerability__c> newRecords = new List<Vulnerability__c>();

            for (Integer i = 1; i < lines.size(); i++) {
                List<String> columns = parseCSVLine(lines[i]);

                if (columns.size() < headers.size()) {
                    System.debug('⚠️ Skipping malformed row: ' + lines[i]);
                    continue;
                }

                Vulnerability__c vuln = new Vulnerability__c();

                // ✅ Defensive check: Ensure column index exists before accessing it
                vuln.Problem__c = getColumnValue(columns, columnMap, fieldMappings, 'problem');
                vuln.Severity__c = getColumnValue(columns, columnMap, fieldMappings, 'severity');
                vuln.File__c = getColumnValue(columns, columnMap, fieldMappings, 'file');
                vuln.Line__c = getColumnValue(columns, columnMap, fieldMappings, 'templine'); // Using "TempLine" as "Line__c"
                vuln.Column__c = getColumnValue(columns, columnMap, fieldMappings, 'column');
                vuln.Rule__c = getColumnValue(columns, columnMap, fieldMappings, 'rule');
                vuln.Description__c = getColumnValue(columns, columnMap, fieldMappings, 'description');
                vuln.URL__c = getColumnValue(columns, columnMap, fieldMappings, 'url');
                vuln.Category__c = getColumnValue(columns, columnMap, fieldMappings, 'category');
                vuln.Engine__c = getColumnValue(columns, columnMap, fieldMappings, 'engine');
                vuln.Commit__c = getColumnValue(columns, columnMap, fieldMappings, 'commit');

                // ✅ Handle missing "ActualLine" values
                vuln.ActualLine__c = getColumnValue(columns, columnMap, fieldMappings, 'actualline');

                // ✅ Handle "TargetBranch"
                vuln.TargetBranch__c = getColumnValue(columns, columnMap, fieldMappings, 'targetbranch');

                System.debug('✅ Created Vulnerability Record: ' + vuln);

                newRecords.add(vuln);
            }

            // Insert records and capture errors
            if (!newRecords.isEmpty()) {
                try {
                    insert newRecords;
                    System.debug(newRecords.size() + ' ✅ Vulnerability records created.');
                } catch (DMLException e) {
                    System.debug('❌ Error inserting records: ' + e.getMessage());
                }
            } else {
                System.debug('⚠️ No valid records found.');
            }
        } catch (Exception e) {
            System.debug('❌ Error processing file: ' + e.getMessage());
        }
    }

    // ✅ Helper Method to Get Column Value Safely
    public static String getColumnValue(List<String> columns, Map<String, Integer> columnMap, Map<String, String> fieldMappings, String field) {
        Integer index = columnMap.get(fieldMappings.get(field).toLowerCase());
        if (index != null && index < columns.size()) {
            String value = columns[index].trim();
            return (value == null || value == '') ? 'N/A' : value; // Prevents null assignments
        }
        return 'N/A';
    }

    // ✅ CSV Parsing Function (Handles Quoted Values)
    public static List<String> parseCSVLine(String csvLine) {
        List<String> columns = new List<String>();
        Boolean insideQuote = false;
        String currentValue = '';

        for (Integer i = 0; i < csvLine.length(); i++) {
            String currentChar = csvLine.substring(i, i + 1);

            if (currentChar == '"') {
                insideQuote = !insideQuote;
            } else if (currentChar == ',' && !insideQuote) {
                columns.add(currentValue.trim());
                currentValue = '';
            } else {
                currentValue += currentChar;
            }
        }

        columns.add(currentValue.trim());
        return columns;
    }
}
