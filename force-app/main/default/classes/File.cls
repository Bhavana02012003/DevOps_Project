public with sharing class File {

    private static final String VULN_OBJECT_API = 'Vulnerability__c';

    public static void processNewContentDocuments(Set<Id> contentDocIds) {

        System.debug('🔥 ENTRY: processNewContentDocuments');
        System.debug('📂 Incoming Doc IDs: ' + contentDocIds);

        if (contentDocIds == null || contentDocIds.isEmpty()) {
            System.debug('❌ No ContentDocumentIds received');
            return;
        }

        // STEP 1: Create or Reuse Case
        ensureStandardCasesExist(contentDocIds);

        // STEP 2: Create / Upsert Vulnerabilities
        importVulnerabilityData(new List<Id>(contentDocIds));
    }

    // ================= CASE CREATION / REUSE =================
    private static void ensureStandardCasesExist(Set<Id> contentDocIds) {

        System.debug('🔥 STEP 1: Creating / Reusing Cases by Pull Request + Commit SHA');

        List<ContentDocument> docs = [
            SELECT Id, Title
            FROM ContentDocument
            WHERE Id IN :contentDocIds
        ];

        if (docs.isEmpty()) {
            System.debug('⚠️ No ContentDocuments found');
            return;
        }

        Map<Id, Id> docToCaseMap = new Map<Id, Id>();
        List<Case> casesToInsert = new List<Case>();
        List<Case> casesToUpdate = new List<Case>();

        // temp maps to connect inserted cases back to docs
        Map<Id, Integer> docIdToInsertIndex = new Map<Id, Integer>();

        for (ContentDocument doc : docs) {

            if (doc.Title == null || !doc.Title.toLowerCase().contains('code scanner')) {
                continue;
            }

            System.debug('📄 Processing Doc: ' + doc.Id + ' | Title: ' + doc.Title);

            // Extract current commit SHA from file title
            String commitSha = extractCommitShaFromTitle(doc.Title);
            System.debug('🔑 Extracted Commit SHA: ' + commitSha);

            // Get latest content version for CSV parsing
            ContentVersion cv = [
                SELECT Id, VersionData
                FROM ContentVersion
                WHERE ContentDocumentId = :doc.Id
                ORDER BY VersionNumber DESC
                LIMIT 1
            ];

            String targetEnvironment;
            String priorityValue = 'Low';

            if (cv != null && cv.VersionData != null) {
                String csv = cv.VersionData.toString();
                List<String> rows = csv.split('\n');

                if (rows.size() > 1) {
                    Map<String, Integer> headerIndex = buildHeaderIndex(rows[0]);
                    List<String> cols = parseCSVLine(rows[1]);

                    targetEnvironment = getValue(cols, headerIndex, 'targetbranch');

                    String severity = getValue(cols, headerIndex, 'severity');
                    if (severity == '1' || severity == '2') {
                        priorityValue = 'High';
                    } else if (severity == '3') {
                        priorityValue = 'Medium';
                    } else {
                        priorityValue = 'Low';
                    }
                }
            }

            Pull_Request__c matchedPr = findPullRequestByCommitSha(commitSha);

            Case existingCase;
            if (matchedPr != null) {
                existingCase = findExistingCaseForPullRequest(matchedPr.Id);
            }

            if (existingCase != null) {
                System.debug('♻️ Reusing existing Case: ' + existingCase.Id);

                existingCase.Subject = 'Scanner Report - ' + doc.Title;
                existingCase.Origin = 'Web';
                existingCase.Status = 'New';
                existingCase.File_Name__c = doc.Title;
                existingCase.pk__c = 'new';
                existingCase.Target_Environment__c = targetEnvironment;
                existingCase.Priority = priorityValue;
                existingCase.Pull_Request__c = matchedPr != null ? matchedPr.Id : null;
                existingCase.Scanner_Report_File_ID__c = String.valueOf(doc.Id);
                existingCase.ContentDocumentId__c = String.valueOf(doc.Id);

                casesToUpdate.add(existingCase);
                docToCaseMap.put(doc.Id, existingCase.Id);

            } else {
                System.debug('🆕 Creating new Case');

                Case c = new Case();
                c.Subject = 'Scanner Report - ' + doc.Title;
                c.Origin = 'Web';
                c.Status = 'New';
                c.File_Name__c = doc.Title;
                c.pk__c = 'new';
                c.Target_Environment__c = targetEnvironment;
                c.Priority = priorityValue;
                c.Pull_Request__c = matchedPr != null ? matchedPr.Id : null;
                c.Scanner_Report_File_ID__c = String.valueOf(doc.Id);
                c.ContentDocumentId__c = String.valueOf(doc.Id);

                docIdToInsertIndex.put(doc.Id, casesToInsert.size());
                casesToInsert.add(c);
            }
        }

        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }

        if (!casesToInsert.isEmpty()) {
            insert casesToInsert;

            for (Id docId : docIdToInsertIndex.keySet()) {
                Integer idx = docIdToInsertIndex.get(docId);
                docToCaseMap.put(docId, casesToInsert[idx].Id);
            }
        }

        if (docToCaseMap.isEmpty()) {
            System.debug('⚠️ No Case mappings were created');
            return;
        }

        // prevent duplicate ContentDocumentLink creation
        Set<String> existingLinkKeys = new Set<String>();

        for (ContentDocumentLink existingLink : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :docToCaseMap.keySet()
        ]) {
            existingLinkKeys.add(
                String.valueOf(existingLink.ContentDocumentId) + '|' +
                String.valueOf(existingLink.LinkedEntityId)
            );
        }

        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();

        for (Id docId : docToCaseMap.keySet()) {
            Id caseId = docToCaseMap.get(docId);
            String linkKey = String.valueOf(docId) + '|' + String.valueOf(caseId);

            if (existingLinkKeys.contains(linkKey)) {
                System.debug('⚠️ Link already exists, skipping: ' + linkKey);
                continue;
            }

            ContentDocumentLink link = new ContentDocumentLink();
            link.ContentDocumentId = docId;
            link.LinkedEntityId = caseId;
            link.ShareType = 'V';
            link.Visibility = 'AllUsers';
            linksToInsert.add(link);
        }

        if (!linksToInsert.isEmpty()) {
            insert linksToInsert;
        }

        System.debug('✅ Case create/reuse flow completed');
    }

    // ================= VULNERABILITY UPSERT =================
    private static void importVulnerabilityData(List<Id> contentDocIds) {

        System.debug('🔥 STEP 2: Creating / Updating Vulnerabilities');

        Map<Id, Id> fileToCaseMap = getFileToCaseMap(new Set<Id>(contentDocIds));

        if (fileToCaseMap.isEmpty()) {
            System.debug('⚠️ No File → Case mappings found');
            return;
        }

        List<ContentVersion> versions = [
            SELECT Id, VersionData, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocIds
            AND IsLatest = true
        ];

        if (versions.isEmpty()) {
            System.debug('⚠️ No ContentVersions found');
            return;
        }

        List<Vulnerability__c> recordsToUpsert = new List<Vulnerability__c>();
        Set<String> batchKeys = new Set<String>();

        for (ContentVersion cv : versions) {

            Id caseId = fileToCaseMap.get(cv.ContentDocumentId);
            if (caseId == null || cv.VersionData == null) {
                continue;
            }

            String csv = cv.VersionData.toString();
            List<String> rows = csv.split('\n');

            if (rows.isEmpty()) {
                continue;
            }

            Map<String, Integer> headerIndex = buildHeaderIndex(rows[0]);

            for (Integer i = 1; i < rows.size(); i++) {

                if (String.isBlank(rows[i])) {
                    continue;
                }

                List<String> cols = parseCSVLine(rows[i]);

                String rule = getValue(cols, headerIndex, 'rule');
                String filePath = getValue(cols, headerIndex, 'file');
                String line = getValue(cols, headerIndex, 'startline');

                if (String.isBlank(rule) || String.isBlank(filePath) || String.isBlank(line)) {
                    continue;
                }

                String violationKey = buildViolationKey(caseId, rule, filePath, line);

                if (batchKeys.contains(violationKey)) {
                    System.debug('⚠️ Duplicate in same batch, skipping: ' + violationKey);
                    continue;
                }

                batchKeys.add(violationKey);

                Vulnerability__c v = new Vulnerability__c();
                v.Violation_Key__c = violationKey;   // assuming this is External ID / Unique
                v.Case__c = caseId;
                v.Rule__c = rule;
                v.Engine__c = getValue(cols, headerIndex, 'engine');
                v.Severity__c = getValue(cols, headerIndex, 'severity');
                v.Category__c = getValue(cols, headerIndex, 'tags');
                v.File__c = filePath;
                v.Line__c = line;
                v.Column__c = getValue(cols, headerIndex, 'startcolumn');
                v.Description__c = getValue(cols, headerIndex, 'message');
                v.URL__c = getValue(cols, headerIndex, 'resources');
                v.Commit__c = getValue(cols, headerIndex, 'commitauthor');
                v.TargetBranch__c = getValue(cols, headerIndex, 'targetbranch');
                v.ActualLine__c = getValue(cols, headerIndex, 'actualline');
                v.Violation_Status__c = 'Open';

                recordsToUpsert.add(v);
            }
        }

        System.debug('📌 FINAL UPSERT COUNT: ' + recordsToUpsert.size());

        if (!recordsToUpsert.isEmpty()) {
            upsert recordsToUpsert Violation_Key__c;
        }
    }

    // ================= PULL REQUEST HELPERS =================
    private static Pull_Request__c findPullRequestByCommitSha(String commitSha) {

        if (String.isBlank(commitSha)) {
            return null;
        }

        List<Pull_Request__c> openPrs = [
            SELECT Id, Name, Commit_SHA_Key__c, PR_Status__c
            FROM Pull_Request__c
            WHERE Commit_SHA_Key__c = :commitSha
            AND PR_Status__c = 'Open'
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        if (!openPrs.isEmpty()) {
            System.debug('✅ Matched OPEN Pull Request: ' + openPrs[0].Id);
            return openPrs[0];
        }

        List<Pull_Request__c> anyPrs = [
            SELECT Id, Name, Commit_SHA_Key__c, PR_Status__c
            FROM Pull_Request__c
            WHERE Commit_SHA_Key__c = :commitSha
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        if (!anyPrs.isEmpty()) {
            System.debug('✅ Matched Pull Request: ' + anyPrs[0].Id);
            return anyPrs[0];
        }

        System.debug('⚠️ No Pull Request matched for SHA: ' + commitSha);
        return null;
    }

    private static Case findExistingCaseForPullRequest(Id pullRequestId) {

        if (pullRequestId == null) {
            return null;
        }

        List<Case> cases = [
            SELECT Id,
                   Subject,
                   Status,
                   Origin,
                   File_Name__c,
                   pk__c,
                   Target_Environment__c,
                   Priority,
                   Pull_Request__c,
                   Scanner_Report_File_ID__c,
                   ContentDocumentId__c
            FROM Case
            WHERE Pull_Request__c = :pullRequestId
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        return cases.isEmpty() ? null : cases[0];
    }

    private static String extractCommitShaFromTitle(String title) {

        if (String.isBlank(title)) {
            return null;
        }

        Pattern p = Pattern.compile('([a-fA-F0-9]{40})');
        Matcher m = p.matcher(title);

        if (m.find()) {
            return m.group(1);
        }

        return null;
    }

    // ================= GENERIC HELPERS =================
    private static Map<Id, Id> getFileToCaseMap(Set<Id> contentDocIds) {

        Map<Id, Id> fileToCaseMap = new Map<Id, Id>();

        for (ContentDocumentLink link : [
            SELECT LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :contentDocIds
        ]) {
            if (link.LinkedEntityId != null &&
                link.LinkedEntityId.getSObjectType() == Case.SObjectType) {
                fileToCaseMap.put(link.ContentDocumentId, link.LinkedEntityId);
            }
        }

        return fileToCaseMap;
    }

    private static String buildViolationKey(Id caseId, String rule, String filePath, String line) {
        return String.valueOf(caseId) + '|' +
               String.valueOf(rule) + '|' +
               String.valueOf(filePath) + '|' +
               String.valueOf(line);
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

    private static Map<String, Integer> buildHeaderIndex(String header) {
        Map<String, Integer> mapIndex = new Map<String, Integer>();
        List<String> headers = parseCSVLine(header);

        for (Integer i = 0; i < headers.size(); i++) {
            mapIndex.put(normalize(headers[i]), i);
        }
        return mapIndex;
    }

    private static String getValue(List<String> cols, Map<String, Integer> index, String key) {
        String k = normalize(key);
        if (index.containsKey(k) && index.get(k) < cols.size()) {
            return cols[index.get(k)];
        }
        return null;
    }

    private static String normalize(String s) {
        return s == null ? '' : s.toLowerCase().replace(' ', '').replace('_', '');
    }
}