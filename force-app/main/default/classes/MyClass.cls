public class MyClass {
    public void myMethod() {
        // Hardcoding an Account ID (Violation)
        Account acc = [SELECT Id, Name FROM Account WHERE Id = '001XXXXXXXXXXXXXXX' LIMIT 1];
        System.debug(acc.Name);
    }
    public void method1() {
            System.debug('Hello World');
        }
}
