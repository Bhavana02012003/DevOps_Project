trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert) {

    Set<Id> docIds = new Set<Id>();

    for (ContentDocumentLink cdl : Trigger.new) {

        // Only process when linked to Case
        if (cdl.LinkedEntityId != null &&
            cdl.LinkedEntityId.getSObjectType() == Case.SObjectType) {

            docIds.add(cdl.ContentDocumentId);
        }
    }

    if (!docIds.isEmpty()) {
        File.processNewContentDocuments(docIds);
    }
}
