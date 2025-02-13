public with sharing class FileController {
    @AuraEnabled(cacheable=true)
    public static List<ContentDocument> getAllFiles() {
        return [SELECT Id, Title FROM ContentDocument ORDER BY Title ASC];
    }

    @AuraEnabled
    public static String getFileContent(String fileId) {
        ContentVersion fileVersion = [
            SELECT VersionData 
            FROM ContentVersion 
            WHERE ContentDocumentId = :fileId 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        
        // Convert Blob to Base64 String and return
        return EncodingUtil.base64Encode(fileVersion.VersionData);
    }
}
