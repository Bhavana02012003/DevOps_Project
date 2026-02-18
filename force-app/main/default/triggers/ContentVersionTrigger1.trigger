trigger ContentVersionTrigger1 on ContentVersion (after insert) {
    Set<Id> contentDocumentIds = new Set<Id>();

    System.debug('🔹 Trigger started: Processing ' + Trigger.new.size() + ' ContentVersion records.');

    // Collect ContentDocumentIds for files containing 'Code Scanner' or 'Code Scanner Delta'
    for (ContentVersion cv : Trigger.new) {
        System.debug('📂 Checking File: ' + cv.Title + ' | ContentDocumentId: ' + cv.ContentDocumentId);
        if (cv.Title.contains('Code Scanner') || cv.Title.contains('Code Scanner Delta')) {
            System.debug('✅ File Matches Condition: ' + cv.Title);
            contentDocumentIds.add(cv.ContentDocumentId);
        }
    }

    // Prevent recursive calls
    if (!contentDocumentIds.isEmpty()) {
        System.debug('🚀 Calling Future Method to Process Files...');
        ScannerReportHandler.processFiles(contentDocumentIds);
    } else {
        System.debug('⚠️ No matching files found. Trigger exiting.');
    }
}