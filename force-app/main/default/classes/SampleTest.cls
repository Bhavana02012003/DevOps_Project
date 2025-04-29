public with sharing class SampleTest {
    public void print(Integer num){
        System.debug('Hello');
        if(num > 5){
            System.debug('Num is great than 5');
        }
    }
}