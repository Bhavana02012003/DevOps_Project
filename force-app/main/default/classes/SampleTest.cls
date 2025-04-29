public with sharing class SampleTest {
    public void print(Integer num){
        System.debug('Hello');
        if(num > 5){
            System.debug('Num is greater than 5');
        }else{
            System.debug('Num is less than 5');
        }
    }
}