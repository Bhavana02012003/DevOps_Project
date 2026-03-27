/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 03-27-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
public class DummyActionTest {
    
    @isTest
    static void testSomething() {
        // Deliberate Violation: AvoidDebugStatements
        System.debug('Running the dummy test for GitHub Actions');
        
        Integer a = 1;
        Integer b = 2;
        Integer c = a + b;
        
        // Deliberate Violation: ApexUnitTestClassShouldHaveAsserts (no System.assert used)
    }
    @isTest
    static void testDeltaLogic() {
        try {
            Integer x = 5 / 0;
        } catch (Exception e) {
            // Deliberate Violation: EmptyCatchBlock
        }
    }
}