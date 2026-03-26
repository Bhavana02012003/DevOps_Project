public with sharing class File {

    private static final String VULN_OBJECT_API = 'Vulnerability__c';

    public static void processNewContentDocuments(Set<Id> contentDocIds) {

        System.debug('🔥 ENTRY: processNewContentDocuments');
        System.debug('📂 Incoming Doc IDs: ' + contentDocIds);

        if(contentDocIds == null || contentDocIds.isEmpty()){
            System.debug('❌ No ContentDocumentIds received');
            return;
        }

        // STEP 1: Create Case
        ensureStandardCasesExist(contentDocIds);

        // STEP 2: Create Vulnerabilities
        importVulnerabilityData(new List<Id>(contentDocIds));
    }

    // ================= CASE CREATION =================
    private static void ensureStandardCasesExist(Set<Id> contentDocIds) {

        System.debug('🔥 STEP 1: Creating Cases');

        List<ContentDocument> docs = [
            SELECT Id, Title
            FROM ContentDocument
            WHERE Id IN :contentDocIds
        ];

        System.debug('📄 Documents Found: ' + docs.size());

        List<Case> casesToInsert = new List<Case>();
        Map<Id, ContentDocument> pendingDocs = new Map<Id, ContentDocument>();

        for (ContentDocument doc : docs) {

            System.debug('👉 Checking doc: ' + doc.Title);

            if (
                doc.Title != null &&
                doc.Title.toLowerCase().contains('code scanner')
            ) {
                System.debug('✅ MATCHED FILE: ' + doc.Title);

                Case c = new Case();
                c.Subject = 'Scanner Report - ' + doc.Title;
                c.Origin = 'Web';
                c.Status = 'New';
                c.File_Name__c = doc.Title;

                casesToInsert.add(c);
                pendingDocs.put(doc.Id, doc);
            }
        }

        System.debug('📌 Cases to Insert: ' + casesToInsert.size());

        if (!casesToInsert.isEmpty()) {

            try {
                insert casesToInsert;
                System.debug('✅ Cases Inserted Successfully');

            } catch (Exception e) {
                System.debug('❌ Case Insert FAILED: ' + e.getMessage());
                return;
            }

            List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
            Integer i = 0;
            List<Id> docIdList = new List<Id>(pendingDocs.keySet());

            for (Id docId : docIdList) {

                Case createdCase = casesToInsert[i];

                ContentDocumentLink link = new ContentDocumentLink();
                link.ContentDocumentId = docId;
                link.LinkedEntityId = createdCase.Id;
                link.ShareType = 'V';
                link.Visibility = 'AllUsers';

                linksToInsert.add(link);

                System.debug('🔗 Linking File → Case: ' + docId + ' → ' + createdCase.Id);

                i++;
            }

            try {
                insert linksToInsert;
                System.debug('✅ File linked to Cases');

            } catch (Exception e) {
                System.debug('❌ Link FAILED: ' + e.getMessage());
            }
        } else {
            System.debug('⚠️ No Cases created (file name mismatch)');
        }
    }

    // ================= MAP =================
    private static Map<Id, Id> getFileToCaseMap(Set<Id> contentDocIds) {

        System.debug('🔥 STEP 2: Mapping File → Case');

        Map<Id, Id> fileToCaseMap = new Map<Id, Id>();

        List<ContentDocumentLink> links = [
            SELECT LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :contentDocIds
        ];

        for (ContentDocumentLink link : links) {

            if(link.LinkedEntityId.getSObjectType() == Case.SObjectType){
                fileToCaseMap.put(link.ContentDocumentId, link.LinkedEntityId);
            }
        }

        System.debug('🧠 File → Case Map: ' + fileToCaseMap);

        return fileToCaseMap;
    }

    // ================= VULNERABILITY =================
    private static void importVulnerabilityData(List<Id> contentDocIds) {

        System.debug('🔥 STEP 3: Creating Vulnerabilities');

        Map<Id, Id> fileToCaseMap = getFileToCaseMap(new Set<Id>(contentDocIds));

        if (fileToCaseMap.isEmpty()) {
            System.debug('❌ NO CASE FOUND → STOP');
            return;
        }

        List<ContentVersion> versions = [
            SELECT Id, VersionData, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocIds
            AND IsLatest = true
        ];

        System.debug('📄 ContentVersions found: ' + versions.size());

        List<Vulnerability__c> recordsToInsert = new List<Vulnerability__c>();

        for (ContentVersion cv : versions) {

            Id caseId = fileToCaseMap.get(cv.ContentDocumentId);

            if (caseId == null) {
                System.debug('❌ No Case for doc: ' + cv.ContentDocumentId);
                continue;
            }

            if (cv.VersionData == null) {
                System.debug('❌ VersionData is NULL');
                continue;
            }

            String csv = cv.VersionData.toString();
            System.debug('📄 CSV Content: ' + csv.substring(0, Math.min(200, csv.length())));

            List<String> rows = csv.split('\n');

            System.debug('📊 Rows count: ' + rows.size());

            for (Integer i = 1; i < rows.size(); i++) {

                if (String.isBlank(rows[i])) continue;

                List<String> cols = rows[i].split(',');

                if (cols.size() < 5) continue;

                Vulnerability__c v = new Vulnerability__c();

                v.Case__c = caseId;
                v.Rule__c = cols[0];
                v.File__c = cols[1];
                v.Severity__c = cols[2];
                v.Description__c = rows[i];

                recordsToInsert.add(v);
            }
        }

        System.debug('📌 Vulnerabilities to insert: ' + recordsToInsert.size());

        if (!recordsToInsert.isEmpty()) {
            try {
                insert recordsToInsert;
                System.debug('✅ Vulnerabilities inserted');

            } catch (Exception e) {
                System.debug('❌ Vulnerability Insert FAILED: ' + e.getMessage());
            }
        } else {
            System.debug('⚠️ No vulnerabilities parsed');
        }
    }
}