public class ScannerAttachmentQueueable implements Queueable {

    private List<Id> caseIds;

    public ScannerAttachmentQueueable(List<Id> caseIds) {
        this.caseIds = caseIds;
    }

    public void execute(QueueableContext context) {

        for (Id caseId : caseIds) {
            AttachmentHandler.createAttachmentForCase(caseId);
        }
    }
}
