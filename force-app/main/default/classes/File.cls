public with sharing class File {
    @AuraEnabled
    public static void importLatestVulnerabilityData() {
        // Step 1: Get the latest CSV file where the title starts with 'Code Scanner'
        ContentVersion file = [
            SELECT ContentDocumentId, VersionData
            FROM ContentVersion
            WHERE Title LIKE 'Code Scanner%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        if (file == null) {
            System.debug('❌ No Code Scanner report file found.');
            return;
        }
        
        Id fileId = file.ContentDocumentId;
        String csvContent = file.VersionData.toString();
        List<String> lines = csvContent.split('\\n');

        if (lines.isEmpty()) {
            System.debug('❌ CSV file is empty.');
            return;
        }

        // Step 2: Extract headers and normalize them (remove double quotes and trim spaces)
        List<String> headers = lines[0].split(',');
        Map<String, Integer> columnMap = new Map<String, Integer>();

        for (Integer i = 0; i < headers.size(); i++) {
            String normalizedHeader = headers[i].trim().replaceAll('^\"|\"$', '').toLowerCase(); // Remove leading/trailing quotes
            columnMap.put(normalizedHeader, i);
        }

        // Required fields (normalized)
        List<String> requiredFields = new List<String>{
            'problem', 'severity', 'file', 'line', 'column', 'rule',
            'description', 'url', 'category', 'engine'
        };

        // Validate headers exist
        for (String field : requiredFields) {
            if (!columnMap.containsKey(field)) {
                System.debug('❌ Missing required column: ' + field);
                return;
            }
        }

        // Step 3: Parse CSV and create new Vulnerability__c records
        List<Vulnerability__c> newRecords = new List<Vulnerability__c>();

        for (Integer i = 1; i < lines.size(); i++) {
            List<String> columns = lines[i].split(',');

            if (columns.size() < headers.size()) {
                continue; // Skip malformed lines
            }

            Vulnerability__c vuln = new Vulnerability__c();
            vuln.Problem__c = columns[columnMap.get('problem')].trim().replaceAll('^\"|\"$', ''); // Remove quotes
            vuln.Severity__c = columns[columnMap.get('severity')].trim().replaceAll('^\"|\"$', '');
            vuln.File__c = columns[columnMap.get('file')].trim().replaceAll('^\"|\"$', '');
            vuln.Line__c = columns[columnMap.get('line')].trim().replaceAll('^\"|\"$', '');
            vuln.Column__c = columns[columnMap.get('column')].trim().replaceAll('^\"|\"$', '');
            vuln.Rule__c = columns[columnMap.get('rule')].trim().replaceAll('^\"|\"$', '');
            vuln.Description__c = columns[columnMap.get('description')].trim().replaceAll('^\"|\"$', '');
            vuln.URL__c = columns[columnMap.get('url')].trim().replaceAll('^\"|\"$', '');
            vuln.Category__c = columns[columnMap.get('category')].trim().replaceAll('^\"|\"$', '');
            vuln.Engine__c = columns[columnMap.get('engine')].trim().replaceAll('^\"|\"$', '');

            newRecords.add(vuln);
        }

        // Step 4: Insert records in bulk
        if (!newRecords.isEmpty()) {
            insert newRecords;
            System.debug(newRecords.size() + ' ✅ Vulnerability records created from the latest Code Scanner file.');
        } else {
            System.debug('⚠️ No valid records found to insert.');
        }
    }
}
