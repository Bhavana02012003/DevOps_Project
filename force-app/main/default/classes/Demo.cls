public with sharing class Demo {
    public static void insertAccount(List<Account> accList) {
          for (Account acc : accList) {
            if (Schema.sObjectType.Account.fields.Description.isUpdateable()) {
              System.debug('Debug1');
              acc.Description = 'Happy Welcome to';
              acc.Rating = 'Hotter';
              acc.Industry = 'Agriculture';
            }
          }
          insert accList;
        
      }
}