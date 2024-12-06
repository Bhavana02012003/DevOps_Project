public with sharing class Demo {
    public static void insertAccount(List<Account> accList) {
          for (Account acc : accList) {
            if (Schema.sObjectType.Account.fields.Description.isUpdateable()) {
              System.debug('Debug');
              acc.Description = 'Happy Welcome';
              acc.Rating = 'Hotter';
              acc.Industry = 'Agriculture';
            }
          }
          insert accList;
        
      }
}