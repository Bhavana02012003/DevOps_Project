public class myClass {  // Violates Class Naming Conventions (Class names should start with an uppercase letter)
    
    public void myMethod() {  // Violates Method Naming Conventions (Method names should start with a lowercase letter)
        
        // Violates AvoidHardcodingIds (Hardcoding ID in the code)
        Account acc = [SELECT Id, Name FROM Account WHERE Id = '0012w00000e1example'];  
        System.debug('Account Name: ' + acc.Name);
        
    }
    
    public static void main() {  // Violates Method Naming Conventions (Method names should start with a lowercase letter)
        // Violates AvoidHardcodingIds (Hardcoding ID in the code)
        Account acc2 = [SELECT Id, Name FROM Account WHERE Id = '0012w00000e1anotherexample'];  
        System.debug('Account Name: ' + acc2.Name);
    }
}
