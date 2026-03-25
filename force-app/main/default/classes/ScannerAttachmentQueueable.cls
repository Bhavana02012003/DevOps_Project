public class ScannerAttachmentQueueable implements Queueable {

    private Set<Id> docIds;

    public ScannerAttachmentQueueable(Set<Id> docIds) {
        this.docIds = docIds;
    }

    public void execute(QueueableContext context) {
        System.debug('🚀 Queueable → Processing AFTER Case creation');

        if (docIds != null && !docIds.isEmpty()) {
            File.processNewContentDocuments(docIds);
        }
    }
}