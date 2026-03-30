trigger FoodItemTrigger on Food_Item__c (before update) {
    FoodItemTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
}