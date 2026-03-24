/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 03-24-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
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
            processNewContentDocuments(contentDocIds);
        }
    }

    public static void processNewContentDocuments(Set<Id> contentDocIds) {
        // 1. Ensure Standard Cases exist for these files
        createScannerReportCases(contentDocIds);
        
        // 2. Parse CSV and create Vulnerabilities
        importVulnerabilityData(new List<Id>(contentDocIds));
    }

    /* =========================================================
       🆕 FILE → STANDARD CASE MAP 
       ========================================================= */
    private static Map<Id, Id> getFileToCaseMap(Set<Id> contentDocIds) {
        Map<Id, Id> fileToCaseMap = new Map<Id, Id>();

        List<ContentDocumentLink> links = [
            SELECT LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :contentDocIds
            AND LinkedEntityId IN (SELECT Id FROM Case)
        ];

        for (ContentDocumentLink link : links) {
            fileToCaseMap.put(link.ContentDocumentId, link.LinkedEntityId);
        }
        return fileToCaseMap;
    }

    /* ================= CORE ================= */

    private static void importVulnerabilityData(List<Id> contentDocIds) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(VULN_OBJECT_API)) {
            System.debug('❌ Object not found: ' + VULN_OBJECT_API);
            return;
        }

        Schema.SObjectType vulnType = gd.get(VULN_OBJECT_API);
        Set<Id> docIdSet = new Set<Id>(contentDocIds);
        Map<Id, Id> fileToCaseMap = getFileToCaseMap(docIdSet);

        List<ContentVersion> versions = [
            SELECT Id, VersionData, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocIds
            AND IsLatest = true
        ];

        List<SObject> recordsToInsert = new List<SObject>();

        for (ContentVersion cv : versions) {
            Id relatedCaseId = fileToCaseMap.get(cv.ContentDocumentId);
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

                String rule = getValue(cols, headerIndex, 'rule');
                String file = getValue(cols, headerIndex, 'file');

                if (String.isBlank(rule) || String.isBlank(file)) continue;

                SObject vuln = vulnType.newSObject();

                // Link to Standard Case
                if (relatedCaseId != null) {
                    vuln.put('Case__c', relatedCaseId);
                }

                vuln.put('Rule__c', rule);
                vuln.put('Engine__c', getValue(cols, headerIndex, 'engine'));
                vuln.put('Severity__c', getValue(cols, headerIndex, 'severity'));
                vuln.put('Category__c', getValue(cols, headerIndex, 'tags'));
                vuln.put('File__c', file);
                vuln.put('Line__c', getValue(cols, headerIndex, 'startline'));
                vuln.put('Column__c', getValue(cols, headerIndex, 'startcolumn'));
                vuln.put('Description__c', getValue(cols, headerIndex, 'message'));
                vuln.put('URL__c', getValue(cols, headerIndex, 'resources'));
                vuln.put('Commit__c', getValue(cols, headerIndex, 'commitauthor'));
                vuln.put('ActualLine__c', getValue(cols, headerIndex, 'actualline'));
                vuln.put('TargetBranch__c', getValue(cols, headerIndex, 'targetbranch'));
                vuln.put('Violation_Status__c', 'Open');

                recordsToInsert.add(vuln);
            }
        }

        if (!recordsToInsert.isEmpty()) {
            Set<String> newKeys = new Set<String>();
            for (SObject s : recordsToInsert) {
                Vulnerability__c v = (Vulnerability__c)s;
                String key = v.Rule__c + '|' + v.File__c + '|' + v.Line__c + '|' + v.Case__c;
                newKeys.add(key);
            }

            Set<String> existingKeys = new Set<String>();
            for (Vulnerability__c v : [
                SELECT Rule__c, File__c, Line__c, Case__c
                FROM Vulnerability__c
                WHERE Case__c IN :fileToCaseMap.values()
            ]) {
                String key = v.Rule__c + '|' + v.File__c + '|' + v.Line__c + '|' + v.Case__c;
                existingKeys.add(key);
            }

            List<SObject> finalInsert = new List<SObject>();
            for (SObject s : recordsToInsert) {
                Vulnerability__c v = (Vulnerability__c)s;
                String key = v.Rule__c + '|' + v.File__c + '|' + v.Line__c + '|' + v.Case__c;

                if (!existingKeys.contains(key)) {
                    finalInsert.add(v);
                }
            }

            // ONLY execute one insert block
            if (!finalInsert.isEmpty()) {
                Database.insert(finalInsert, false);
                System.debug('✅ Vulnerabilities inserted: ' + finalInsert.size());
            }
        }
    }

    /* ================= HELPERS (UNCHANGED) ================= */
    private static Map<String, Integer> buildHeaderIndex(String header) {
        Map<String, Integer> indexMap = new Map<String, Integer>();
        List<String> headers = parseCSVLine(header);
        for (Integer i = 0; i < headers.size(); i++) {
            indexMap.put(normalize(headers[i]), i);
        }
        return indexMap;
    }

    private static String getValue(List<String> row, Map<String, Integer> headerIndex, String key) {
        String normalizedKey = normalize(key);
        if (headerIndex.containsKey(normalizedKey) && headerIndex.get(normalizedKey) < row.size()) {
            return row[headerIndex.get(normalizedKey)];
        }
        return null;
    }

    private static String normalize(String s) {
        return s == null ? '' : s.toLowerCase().replace(' ', '').replace('_', '').replace('-', '');
    }

    private static List<String> parseCSVLine(String line) {
        List<String> cols = new List<String>();
        Boolean inQuotes = false;
        String cur = '';
        for (Integer i = 0; i < line.length(); i++) {
            String c = line.substring(i, i + 1);
            if (c == '"') inQuotes = !inQuotes;
            else if (c == ',' && !inQuotes) {
                cols.add(cur.trim());
                cur = '';
            } else cur += c;
        }
        cols.add(cur.trim());
        return cols;
    }

    /* ===== REWRITTEN TO CREATE STANDARD CASES AND AVOID GOVERNOR LIMITS ===== */
    private static void createScannerReportCases(Set<Id> contentDocIds) {
        List<ContentDocument> docs = [
            SELECT Id, Title
            FROM ContentDocument
            WHERE Id IN :contentDocIds
        ];

        // Bulk-safe query outside the loop
        Set<Id> existingCaseDocIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE ContentDocumentId IN :contentDocIds 
            AND LinkedEntityId IN (SELECT Id FROM Case)
        ]) {
            existingCaseDocIds.add(cdl.ContentDocumentId);
        }

        List<Case> casesToInsert = new List<Case>();
        Map<Id, ContentDocument> docMapForLinks = new Map<Id, ContentDocument>();

        for (ContentDocument doc : docs) {
            if (doc.Title != null && doc.Title.contains('Code_Scanner_Report')) {
                // If a case already exists for this file, skip
                if (existingCaseDocIds.contains(doc.Id)) continue;

                Case newCase = new Case();
                newCase.Subject = 'Scanner Report: ' + doc.Title;
                newCase.Status = 'New';
                newCase.OwnerId = UserInfo.getUserId();
                // Add your Commit_SHA_Key__c logic here if possible!
                
                casesToInsert.add(newCase);
                docMapForLinks.put(doc.Id, doc); 
            }
        }

        if (!casesToInsert.isEmpty()) {
            insert casesToInsert;

            // ⚠️ CRITICAL: We must link the newly created Case back to the file
            List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
            Integer index = 0;
            for (Id docId : docMapForLinks.keySet()) {
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = docId;
                cdl.LinkedEntityId = casesToInsert[index].Id; // Associate with the new case
                cdl.ShareType = 'V'; // View permission
                newLinks.add(cdl);
                index++;
            }
            if (!newLinks.isEmpty()) {
                insert newLinks;
            }
        }
    }
}