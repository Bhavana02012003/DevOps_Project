@isTest
private class SEO_FileController_CreateVulnTest {
    private static Id testContentDocumentId;

    // =====================================================
    // TEST DATA SETUP
    // =====================================================
    @testSetup
    static void setupTestData() {
        System.debug('🔹 Setting up test data...');

        ContentVersion ver = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.csv',
            VersionData = Blob.valueOf('Sample file content'),
            FirstPublishLocationId = UserInfo.getUserId()
        );
        insert ver;

        testContentDocumentId = [
            SELECT ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :ver.Id 
            LIMIT 1
        ].ContentDocumentId;

        System.debug('✅ Test ContentDocument ID: ' + testContentDocumentId);
    }

    // =====================================================
    // TEST getAllFiles() - Standard Scenario
    // =====================================================
    @isTest
    static void testGetAllFiles() {
        Test.startTest();
        List<ContentDocument> files = SEO_FileController_CreateVulnerability.getAllFiles();
        Test.stopTest();

        System.assertNotEquals(null, files);
        System.assert(files.size() > 0);
    }

    // =====================================================
    // TEST getAllFiles() - No Files Scenario
    // =====================================================
    @isTest
    static void testGetAllFilesNoRecords() {
        delete [SELECT Id FROM ContentDocument];

        Test.startTest();
        List<ContentDocument> files = SEO_FileController_CreateVulnerability.getAllFiles();
        Test.stopTest();

        System.assertEquals(0, files.size());
    }

    // =====================================================
    // TEST getFileContent() - Valid File
    // =====================================================
    @isTest
    static void testGetFileContent() {
        Test.startTest();
        String fileContent = SEO_FileController_CreateVulnerability.getFileContent(testContentDocumentId);
        Test.stopTest();

        System.assertNotEquals(null, fileContent);
        System.assert(fileContent.length() > 0);
    }

    // =====================================================
    // TEST getFileContent() - Missing File (QueryException path)
    // =====================================================
    @isTest
    static void testGetFileContentNoFile() {
        Test.startTest();
        String fileContent = SEO_FileController_CreateVulnerability.getFileContent('000000000000000');
        Test.stopTest();

        System.assertEquals('NO_CONTENT', fileContent);
    }

    // =====================================================
    // TEST getFileContent() - Empty Version Data
    // =====================================================
    @isTest
    static void testGetFileContentNoVersionData() {

        ContentVersion emptyVer = new ContentVersion(
            Title = 'Empty File',
            PathOnClient = 'EmptyFile.csv',
            VersionData = Blob.valueOf(' '),
            FirstPublishLocationId = UserInfo.getUserId()
        );
        insert emptyVer;

        Id emptyDocId = [
            SELECT ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :emptyVer.Id 
            LIMIT 1
        ].ContentDocumentId;

        Test.startTest();
        String fileContent = SEO_FileController_CreateVulnerability.getFileContent(emptyDocId);
        Test.stopTest();

        System.assertEquals('IA==', fileContent); // Base64 of space
    }

    // =====================================================
    // ⭐ NEW TESTS FOR EXTRA COVERAGE
    // =====================================================

    // Test multiple versions → latest should be returned
    static void testGetFileContentMultipleVersions() {
        // Create initial version
        ContentVersion ver1 = new ContentVersion(
            Title = 'Multi File',
            PathOnClient = 'Multi1.csv',
            VersionData = Blob.valueOf('Version1'),
            FirstPublishLocationId = UserInfo.getUserId()
        );
        insert ver1;
        Id docId = [
            SELECT ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :ver1.Id
            LIMIT 1
        ].ContentDocumentId;
        // Create a newer version of the same document
        ContentVersion ver2 = new ContentVersion(
            Title = 'Multi File',
            PathOnClient = 'Multi2.csv',
            VersionData = Blob.valueOf('Version2'),
            ContentDocumentId = docId
        );
        insert ver2;
        Test.startTest();
        String result = SEO_FileController_CreateVulnerability.getFileContent(docId);
        Test.stopTest();
        // Assert we got Version2 (latest)
        String expected = EncodingUtil.base64Encode(Blob.valueOf('Version2'));
        System.assertEquals(expected, result, 'Should return the latest version content (Version2).');
    }
    
    // Test null fileId → exception branch
    @isTest
    static void testGetFileContentNullId() {
        Test.startTest();
        String result = SEO_FileController_CreateVulnerability.getFileContent(null);
        Test.stopTest();

        System.assertEquals('NO_CONTENT', result);
    }

    // Test invalid id → exception branch
    @isTest
    static void testGetFileContentExceptionPath() {
        Test.startTest();
        String result = SEO_FileController_CreateVulnerability.getFileContent('INVALID_ID');
        Test.stopTest();

        System.assertEquals('NO_CONTENT', result);
    }
}
