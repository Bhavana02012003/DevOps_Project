public with sharing class FileController {
    
    @AuraEnabled(cacheable=true)
    public static List<ContentDocument> getAllFiles() {
        return [SELECT Id, Title FROM ContentDocument ORDER BY Title ASC];
    }

    @AuraEnabled
    public static String getFileContent(String fileId) {
        try {
            ContentVersion fileVersion = [
                SELECT VersionData 
                FROM ContentVersion 
                WHERE ContentDocumentId = :fileId 
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];

            if(fileVersion.VersionData == null){
                return 'NO_CONTENT';
            }

            return EncodingUtil.base64Encode(fileVersion.VersionData);

        } catch (Exception e) {
            System.debug('File not found: ' + e.getMessage());
            return 'NO_CONTENT';
        }
    }
}
