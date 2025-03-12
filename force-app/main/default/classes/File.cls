public with sharing class File {
    public static void processNewFiles(List<Id> contentDocIds) {
        for (Id contentDocId : contentDocIds) {
            importVulnerabilityData(contentDocId);
        }
    }

    @AuraEnabled
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

            // ✅ Extract headers & normalize
            List<String> headers = parseCSVLine(lines[0]);
            Map<String, Integer> columnMap = new Map<String, Integer>();

            for (Integer i = 0; i < headers.size(); i++) {
                String normalizedHeader = headers[i].trim().toLowerCase();
                columnMap.put(normalizedHeader, i);
            }

            System.debug('🔍 Available columns in CSV: ' + columnMap.keySet());

            // ✅ Required Fields (Fix "ActualLine" and Map "TempLine" to "Line__c")
            Map<String, String> fieldMappings = new Map<String, String>{
                'problem' => 'problem', 
                'severity' => 'severity', 
                'file' => 'file', 
                'templine' => 'line', // Map `TempLine` from CSV to `Line__c` in Salesforce
                'column' => 'column', 
                'rule' => 'rule',
                'description' => 'description', 
                'url' => 'url', 
                'category' => 'category', 
                'engine' => 'engine', 
                'commit' => 'commit', 
                'actualline' => 'actual line' // Map `ActualLine` from CSV to `Actual_Line__c`
                'targetbranch' => 'target branch' // New mapping for TargetBranch
            };

            // ✅ Ensure all required fields exist
            for (String field : fieldMappings.keySet()) {
                if (!columnMap.containsKey(field)) {
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
                    continue; // Skip malformed lines
                }

                Vulnerability__c vuln = new Vulnerability__c();

                // ✅ Defensive check: Ensure column index exists before accessing it
                vuln.Problem__c = columnMap.containsKey(fieldMappings.get('problem')) ? columns[columnMap.get(fieldMappings.get('problem'))].trim() : 'N/A';
                vuln.Severity__c = columnMap.containsKey(fieldMappings.get('severity')) ? columns[columnMap.get(fieldMappings.get('severity'))].trim() : 'N/A';
                vuln.File__c = columnMap.containsKey(fieldMappings.get('file')) ? columns[columnMap.get(fieldMappings.get('file'))].trim() : 'N/A';
                vuln.Line__c = columnMap.containsKey(fieldMappings.get('templine')) ? columns[columnMap.get(fieldMappings.get('templine'))].trim() : 'N/A'; // Using "TempLine" as "Line__c"
                vuln.Column__c = columnMap.containsKey(fieldMappings.get('column')) ? columns[columnMap.get(fieldMappings.get('column'))].trim() : 'N/A';
                vuln.Rule__c = columnMap.containsKey(fieldMappings.get('rule')) ? columns[columnMap.get(fieldMappings.get('rule'))].trim() : 'N/A';
                vuln.Description__c = columnMap.containsKey(fieldMappings.get('description')) ? columns[columnMap.get(fieldMappings.get('description'))].trim() : 'N/A';
                vuln.URL__c = columnMap.containsKey(fieldMappings.get('url')) ? columns[columnMap.get(fieldMappings.get('url'))].trim() : 'N/A';
                vuln.Category__c = columnMap.containsKey(fieldMappings.get('category')) ? columns[columnMap.get(fieldMappings.get('category'))].trim() : 'N/A';
                vuln.Engine__c = columnMap.containsKey(fieldMappings.get('engine')) ? columns[columnMap.get(fieldMappings.get('engine'))].trim() : 'N/A';
                vuln.Commit__c = columnMap.containsKey(fieldMappings.get('commit')) ? columns[columnMap.get(fieldMappings.get('commit'))].trim() : 'N/A';

                // ✅ Handle missing "ActualLine" values → Default to "NA"
                String actualLineValue = columnMap.containsKey(fieldMappings.get('actualline')) ? columns[columnMap.get(fieldMappings.get('actualline'))].trim() : 'NA';
                vuln.ActualLine__c = (actualLineValue == null || actualLineValue == '') ? 'NA' : actualLineValue;

                // ✅ Handle the new "TargetBranch" field
                vuln.TargetBranch__c = columnMap.containsKey(fieldMappings.get('targetbranch')) ? columns[columnMap.get(fieldMappings.get('targetbranch'))].trim() : 'N/A';

                newRecords.add(vuln);
            }

            // ✅ Insert records in bulk
            if (!newRecords.isEmpty()) {
                insert newRecords;
                System.debug(newRecords.size() + ' ✅ Vulnerability records created.');
            } else {
                System.debug('⚠️ No valid records found.');
            }
        } catch (Exception e) {
            System.debug('❌ Error processing file: ' + e.getMessage());
        }
    }

    // ✅ CSV Parsing Function (Handles Quoted Values)
    public static List<String> parseCSVLine(String csvLine) {
        List<String> columns = new List<String>();
        Boolean insideQuote = false;
        String currentValue = '';

        for (Integer i = 0; i < csvLine.length(); i++) {
            String currentChar = csvLine.substring(i, i + 1);

            if (currentChar == '"') {
                insideQuote = !insideQuote; // Toggle inside/outside quote state
            } else if (currentChar == ',' && !insideQuote) {
                columns.add(currentValue.trim());
                currentValue = ''; // Reset for next value
            } else {
                currentValue += currentChar;
            }
        }

        // Add the last value
        columns.add(currentValue.trim());
        return columns;
    }
}
