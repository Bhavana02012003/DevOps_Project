public with sharing class File {
    public static void processNewFiles(List<ContentVersion> newFiles) {
        for (ContentVersion file : newFiles) {
            // Only process files where Title starts with "Code Scanner"
            if (file.Title.startsWith('Code Scanner')) {
                System.debug('✅ New Code Scanner file detected: ' + file.Title);
                importVulnerabilityData(file.ContentDocumentId);
            }
        }
    }

    @AuraEnabled
    public static void importVulnerabilityData(Id fileId) {
        // // Fetch the file content
        // ContentVersion file = [
        //     SELECT VersionData
        //     FROM ContentVersion
        //     WHERE ContentDocumentId = :fileId
        //     LIMIT 1
        // ];
        // Check if the user has Read permission on ContentVersion
if (Schema.sObjectType.ContentVersion.isAccessible()) {
    // Fetch the file content
    ContentVersion file = [
        SELECT VersionData
        FROM ContentVersion
        WHERE ContentDocumentId = :fileId
        LIMIT 1
    ];
} else {
    System.debug('❌ User does not have read permission on ContentVersion.');
}


        if (file == null) {
            System.debug('❌ File not found.');
            return;
        }

        String csvContent = file.VersionData.toString();
        List<String> lines = csvContent.split('\\n');

        if (lines.isEmpty()) {
            System.debug('❌ CSV file empty.');
            return;
        }

        // Extract headers and normalize them (remove double quotes and trim spaces)
        List<String> headers = lines[0].split(',');
        Map<String, Integer> columnMap = new Map<String, Integer>();

        for (Integer i = 0; i < headers.size(); i++) {
            String normalizedHeader = headers[i].trim().replaceAll('^\"|\"$', '').toLowerCase();
            columnMap.put(normalizedHeader, i);
        }

        // Required fields
        List<String> requiredFields = new List<String>{
            'problem', 'severity', 'file', 'line', 'column', 'rule',
            'description', 'url', 'category', 'engine', 'commit'
        };

        // Validate headers exist
        for (String field : requiredFields) {
            if (!columnMap.containsKey(field)) {
                System.debug('❌ Missing required column: ' + field);
                return;
            }
        }

        // Parse CSV and create new Vulnerability__c records
        List<Vulnerability__c> newRecords = new List<Vulnerability__c>();

        for (Integer i = 1; i < lines.size(); i++) {
            List<String> columns = lines[i].split(',');

            if (columns.size() < headers.size()) {
                continue; // Skip malformed lines
            }

            Vulnerability__c vuln = new Vulnerability__c();
            vuln.Problem__c = columns[columnMap.get('problem')].trim().replaceAll('^\"|\"$', '');
            vuln.Severity__c = columns[columnMap.get('severity')].trim().replaceAll('^\"|\"$', '');
            vuln.File__c = columns[columnMap.get('file')].trim().replaceAll('^\"|\"$', '');
            vuln.Line__c = columns[columnMap.get('line')].trim().replaceAll('^\"|\"$', '');
            vuln.Column__c = columns[columnMap.get('column')].trim().replaceAll('^\"|\"$', '');
            vuln.Rule__c = columns[columnMap.get('rule')].trim().replaceAll('^\"|\"$', '');
            vuln.Description__c = columns[columnMap.get('description')].trim().replaceAll('^\"|\"$', '');
            vuln.URL__c = columns[columnMap.get('url')].trim().replaceAll('^\"|\"$', '');
            vuln.Category__c = columns[columnMap.get('category')].trim().replaceAll('^\"|\"$', '');
            vuln.Engine__c = columns[columnMap.get('engine')].trim().replaceAll('^\"|\"$', '');
            vuln.Commit__c = columns[columnMap.get('commit')].trim().replaceAll('^\"|\"$', '');

            newRecords.add(vuln);
        }

        // // Insert records in bulk
        // if (!newRecords.isEmpty()) {
        //     insert newRecords;
        //     System.debug(newRecords.size() + ' ✅ Vulnerability records created automatically.');
        // } else {
        //     System.debug('⚠️ No valid records found to insert.');
        // }
        // Check if the user has Create permission on the object
if (Schema.sObjectType.Vulnerability__c.isCreateable()) { 
    // Insert records in bulk
    if (!newRecords.isEmpty()) {
        insert newRecords;
        System.debug(newRecords.size() + ' ✅ Vulnerability records created automatically.');
    } else {
        System.debug('⚠️ No valid records found to insert.');
    }
} else {
    System.debug('❌ User does not have create permission on Vulnerability__c.');
}

    }
}
