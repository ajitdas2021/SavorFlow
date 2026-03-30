public with sharing class FoodItemTriggerHandler {

    public static void handleBeforeUpdate(
        List<Food_Item__c> newItems,
        Map<Id, Food_Item__c> oldMap
    ) {
        for (Food_Item__c food : newItems) {
            Food_Item__c oldFood = oldMap.get(food.Id);
            syncAvailabilityOnStockChange(food, oldFood);
        }
    }

    // If stock was manually changed, sync the Available__c flag accordingly
    private static void syncAvailabilityOnStockChange(
        Food_Item__c food,
        Food_Item__c oldFood
    ) {
        if (food.Stock_Quantity__c != oldFood.Stock_Quantity__c) {
            food.Available__c = (food.Stock_Quantity__c > 0);
        }
    }
}