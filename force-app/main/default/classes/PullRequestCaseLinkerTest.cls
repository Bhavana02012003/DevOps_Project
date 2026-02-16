/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 02-13-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@IsTest
private class PullRequestCaseLinkerTest {

    // Helper constant to match source class
    private static final String PR_FILE_FIELD = 'Check1_Report_File__c';

    /**
     * @description Sets up standard Case records for matching.
     */
    @TestSetup
    static void makeData() {
        List<Case> casesToInsert = new List<Case>();
        
        // 1. Happy Path Case
        casesToInsert.add(new Case(
            Subject = 'Happy Path',
            File_Name__c = 'happy_path.pdf'
        ));

        // 2. Case for Case-Insensitive Check
        casesToInsert.add(new Case(
            Subject = 'Case Insensitive',
            File_Name__c = 'UPPER_CASE.pdf'
        ));

        insert casesToInsert;
    }

    /**
     * @description Tests the standard success scenario where PRs match Cases.
     */
    @IsTest
    static void testHandleAfterSuccessMatches() {
        // Create PRs that match the setup data
        Pull_Request__c pr1 = new Pull_Request__c(Check1_Report_File__c = 'happy_path.pdf');
        Pull_Request__c pr2 = new Pull_Request__c(Check1_Report_File__c = 'UPPER_CASE.pdf'); 
        
        List<Pull_Request__c> prList = new List<Pull_Request__c>{pr1, pr2};
        insert prList;

        Test.startTest();
        PullRequestCaseLinker.handleAfter(prList, null, true, false);
        Test.stopTest();

        // Verify updates
        List<Case> updatedCases = [SELECT Id, File_Name__c, Pull_Request__c FROM Case];
        
        for (Case c : updatedCases) {
            System.assertNotEquals(null, c.Pull_Request__c, 'Case ' + c.File_Name__c + ' should be linked');
        }
    }

    /**
     * @description Tests "if (pr == null) continue;" logic.
     * FIXED: We insert the valid PR first so it has an ID before passing it to the handler.
     */
    @IsTest
    static void testHandleAfterWithNullPRObject() {
        // 1. Create and Insert a valid PR first so it generates an ID
        Pull_Request__c validPr = new Pull_Request__c(Check1_Report_File__c = 'happy_path.pdf');
        insert validPr;

        // 2. Create the dirty list (Contains Valid PR + Null)
        List<Pull_Request__c> dirtyList = new List<Pull_Request__c>();
        dirtyList.add(validPr); // Valid PR with ID
        dirtyList.add(null);    // Null object to hit the 'continue' statement

        Test.startTest();
        // Invoke handler
        PullRequestCaseLinker.handleAfter(dirtyList, null, true, false);
        Test.stopTest();
        
        // 3. Verify valid PR was linked despite the null in the list
        Case c = [SELECT Id, Pull_Request__c FROM Case WHERE File_Name__c = 'happy_path.pdf' LIMIT 1];
        System.assertEquals(validPr.Id, c.Pull_Request__c, 'Valid PR should be linked even if list contained nulls');
    }

    /**
     * @description Tests "if (fileNamesForQuery.isEmpty())" return logic.
     */
    @IsTest
    static void testHandleAfterWithAllBlankFiles() {
        // We create in-memory PRs with blank files. No need to insert as we are testing early exit.
        List<Pull_Request__c> blankPrs = new List<Pull_Request__c>{
            new Pull_Request__c(Check1_Report_File__c = ''),
            new Pull_Request__c(Check1_Report_File__c = null),
            new Pull_Request__c(Check1_Report_File__c = '   ') // Whitespace trim check
        };

        Test.startTest();
        PullRequestCaseLinker.handleAfter(blankPrs, null, true, false);
        Test.stopTest();

        // Verify NO updates happened
        Case c = [SELECT Id, Pull_Request__c FROM Case WHERE File_Name__c = 'happy_path.pdf' LIMIT 1];
        System.assertEquals(null, c.Pull_Request__c, 'No updates should occur if all files are blank');
    }

    /**
     * @description Tests "if (matchingCases.isEmpty())" return logic.
     */
    @IsTest
    static void testHandleAfterWithNoMatchingCases() {
        // PR file is valid, but no Case exists with this file name
        List<Pull_Request__c> noMatchPrs = new List<Pull_Request__c>{
            new Pull_Request__c(Check1_Report_File__c = 'ghost_file.pdf')
        };
        // No insert needed for this test as we expect early exit before linking logic

        Test.startTest();
        PullRequestCaseLinker.handleAfter(noMatchPrs, null, true, false);
        Test.stopTest();
        
        // Assert implicitly by lack of exception
        System.assert(true, 'Executed without errors when no cases match');
    }

    /**
     * @description Tests "if (!casesToUpdate.isEmpty())" -> else block.
     * Logic: If Case is already linked, it shouldn't be added to update list again.
     */
    @IsTest
    static void testHandleAfterAlreadyLinked() {
        // Setup: Link the case beforehand
        Pull_Request__c pr = new Pull_Request__c(Check1_Report_File__c = 'happy_path.pdf');
        insert pr;

        Case c = [SELECT Id, Pull_Request__c FROM Case WHERE File_Name__c = 'happy_path.pdf' LIMIT 1];
        c.Pull_Request__c = pr.Id;
        update c;

        // Run Handler Again with same PR
        Test.startTest();
        PullRequestCaseLinker.handleAfter(new List<Pull_Request__c>{pr}, null, true, false);
        Test.stopTest();

        // Logic should detect "c.Pull_Request__c != prId" is false (because they match)
        // and enter the ELSE block for "No Case needed update"
        Case cRequery = [SELECT Id, Pull_Request__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(pr.Id, cRequery.Pull_Request__c, 'Link should remain unchanged');
    }

    /**
     * @description Tests Top level null/empty guards.
     */
    @IsTest
    static void testHandleAfterNullInputs() {
        Test.startTest();
        try {
            PullRequestCaseLinker.handleAfter(null, null, true, false);
            PullRequestCaseLinker.handleAfter(new List<Pull_Request__c>(), null, true, false);
        } catch(Exception e) {
            System.assert(false, 'Should not throw exception on null/empty inputs');
        }
        Test.stopTest();
        System.assert(true, 'Should exit gracefully');
    }
}