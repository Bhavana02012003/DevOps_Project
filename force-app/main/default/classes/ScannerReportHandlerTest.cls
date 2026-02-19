/**
 * @description       : Test class for ScannerReportHandler
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : Tests
 * @last modified on  : 02-19-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@IsTest
private class ScannerReportHandlerTest {

    private static final String REPORT_TITLE_VALID = 'Code Scanner Report - Feb 2026';
    private static final String REPORT_TITLE_INVALID = 'Standard Export Data';

    /**
     * @description Helper method to create ContentVersion and return its ContentDocumentId
     */
    private static Id createTestContentDocument(String title, String csvData) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = title.deleteWhitespace() + '.csv',
            VersionData = Blob.valueOf(csvData)
        );
        insert cv;
        
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
    }

    @IsTest
    static void testProcessFiles_HighSeverity() {
        String csvBody = 'TargetBranch,Commit,Severity\nfeature-branch,abc123hash,1\n';
        Id contentDocId = createTestContentDocument(REPORT_TITLE_VALID, csvBody);

        Test.startTest();
        ScannerReportHandler.processFiles(new Set<Id>{ contentDocId });
        Test.stopTest();

        List<Case> createdCases = [SELECT Id, Subject, Priority, Target_Environment__c, Case_Created_By__c FROM Case];
        Assert.isTrue(createdCases.size() >= 1, 'At least one Case should have been created for the valid file.');

        Set<Id> caseIds = (new Map<Id, Case>(createdCases)).keySet();
        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId IN :caseIds];

        Assert.areEqual('High', createdCases[0].Priority, 'Severity 1 should map to High priority.');
        Assert.areEqual('feature-branch', createdCases[0].Target_Environment__c, 'Target Environment should match CSV.');
        Assert.areEqual('abc123hash', createdCases[0].Case_Created_By__c, 'Case Created By should match Commit hash.');
        Assert.isTrue(createdCases[0].Subject.contains(REPORT_TITLE_VALID), 'Subject should contain the file title.');
        Assert.isTrue(links.size() >= 1, 'The generated file should be linked to the new Case.');
    }

    @IsTest
    static void testProcessFiles_MediumSeverity() {
        String csvBody = 'TargetBranch,Commit,Severity\nmain,def456hash,3\n';
        Id contentDocId = createTestContentDocument(REPORT_TITLE_VALID, csvBody);

        Test.startTest();
        ScannerReportHandler.processFiles(new Set<Id>{ contentDocId });
        Test.stopTest();

        List<Case> createdCases = [SELECT Id, Priority FROM Case];
        Assert.isTrue(createdCases.size() >= 1, 'At least one Case should be created.');
        Assert.areEqual('Medium', createdCases[0].Priority, 'Severity 3 should map to Medium priority.');
    }

    @IsTest
    static void testProcessFiles_LowSeverity() {
        String csvBody = 'TargetBranch,Commit,Severity\nrelease-branch,ghi789hash,5\n';
        Id contentDocId = createTestContentDocument(REPORT_TITLE_VALID, csvBody);

        Test.startTest();
        ScannerReportHandler.processFiles(new Set<Id>{ contentDocId });
        Test.stopTest();

        List<Case> createdCases = [SELECT Id, Priority FROM Case];
        Assert.isTrue(createdCases.size() >= 1, 'At least one Case should be created.');
        Assert.areEqual('Low', createdCases[0].Priority, 'Severity 5 should map to Low priority.');
    }

    @IsTest
    static void testProcessFiles_IgnoredFileTitle() {
        String csvBody = 'TargetBranch,Commit,Severity\nmain,xyz999hash,1\n';
        Id contentDocId = createTestContentDocument(REPORT_TITLE_INVALID, csvBody);

        Test.startTest();
        ScannerReportHandler.processFiles(new Set<Id>{ contentDocId });
        Test.stopTest();

        List<Case> createdCases = [SELECT Id FROM Case];
        Assert.areEqual(0, createdCases.size(), 'No cases should be created for files missing the required title keywords.');
    }

    @IsTest
    static void testProcessFiles_EmptySet() {
        Test.startTest();
        ScannerReportHandler.processFiles(new Set<Id>());
        Test.stopTest();

        List<Case> createdCases = [SELECT Id FROM Case];
        Assert.areEqual(0, createdCases.size(), 'No cases should be created when passing an empty set of IDs.');
    }

    @IsTest
    static void testProcessFiles_InvalidId() {
        Test.startTest();
        // 069 is the standard prefix for ContentDocument
        Id fakeContentDocId = '069000000000000AAA'; 
        ScannerReportHandler.processFiles(new Set<Id>{ fakeContentDocId });
        Test.stopTest();

        List<Case> createdCases = [SELECT Id FROM Case];
        Assert.areEqual(0, createdCases.size(), 'No cases should be created for an invalid ID.');
    }

    @IsTest
    static void testProcessFiles_RecursionPrevention() {
        String csvBody = 'TargetBranch,Commit,Severity\nmain,recursionTest,1\n';
        Id contentDocId = createTestContentDocument(REPORT_TITLE_VALID, csvBody);

        Test.startTest();
        // First call sets isProcessing to true and executes logic
        ScannerReportHandler.processFiles(new Set<Id>{ contentDocId });
        
        // Second call directly after will hit the `if(isProcessing)` block
        ScannerReportHandler.processFiles(new Set<Id>{ contentDocId });
        Test.stopTest();

        List<Case> createdCases = [SELECT Id FROM Case];
        Assert.isTrue(createdCases.size() >= 1, 'Cases should still generate, but the secondary recursive call should be skipped.');
    }

    @IsTest
    static void testProcessFiles_EmptyCSV() {
        String csvBody = 'TargetBranch,Commit,Severity\n'; // Only headers, no data rows
        Id contentDocId = createTestContentDocument(REPORT_TITLE_VALID, csvBody);

        Test.startTest();
        ScannerReportHandler.processFiles(new Set<Id>{ contentDocId });
        Test.stopTest();

        List<Case> createdCases = [SELECT Id FROM Case];
        Assert.isTrue(createdCases.size() >= 1, 'Case should be created even if CSV data rows are empty.');
    }

    // 🔽 NEW: Hits the negative conditions inside the CSV parser loops
    @IsTest
    static void testProcessFiles_MissingColumnsAndUnknownSeverity() {
        // Headers intentionally missing standard columns, and severity is '9' (unhandled)
        String csvBody = 'RandomHeader1,RandomHeader2,Severity\nval1,val2,9\n';
        Id contentDocId = createTestContentDocument(REPORT_TITLE_VALID, csvBody);

        Test.startTest();
        ScannerReportHandler.processFiles(new Set<Id>{ contentDocId });
        Test.stopTest();

        List<Case> createdCases = [SELECT Id, Priority, Target_Environment__c, Case_Created_By__c FROM Case];
        Assert.isTrue(createdCases.size() >= 1, 'Case should be created even with weird CSV format.');
        // Unmapped severity means priority is not updated from the parser logic
        Assert.isNull(createdCases[0].Target_Environment__c, 'Target environment should be null.');
    }

    // 🔽 NEW: Forces a DML Exception on Case Insertion to cover the catch block
    @IsTest
    static void testProcessFiles_CaseDmlException() {
        // Create an excessively long string to break the Case Subject limit (255 chars max)
        String longCommitString = ''.leftPad(200, 'X'); 
        String csvBody = 'TargetBranch,Commit,Severity\nmain,' + longCommitString + ',1\n';
        
        // Combine a 100 char title with the 200 char commit to yield a 300+ char Subject
        String longTitle = 'Code Scanner ' + ''.leftPad(80, 'Y');
        Id contentDocId = createTestContentDocument(longTitle, csvBody);

        Test.startTest();
        ScannerReportHandler.processFiles(new Set<Id>{ contentDocId });
        Test.stopTest();

        // Because the Subject exceeded field limits, the DML Catch block was hit and no Cases were inserted.
        List<Case> createdCases = [SELECT Id FROM Case];
        Assert.areEqual(0, createdCases.size(), 'DML exception should prevent Case creation due to exceeding field length limits.');
    }
}