public with sharing class StockTriggerHandler {

    private static final Integer LOW_STOCK_THRESHOLD = 20;

    public static void handleAfterInsert(List<Order_Item__c> newItems) {

        // Step 1: Collect food item IDs from the inserted order items
        Set<Id> foodItemIds = collectFoodItemIds(newItems);
        if (foodItemIds.isEmpty()) return;

        // Step 2: Fetch only Drinks food items (stock is only tracked for Drinks)
        Map<Id, Food_Item__c> foodItemMap = fetchDrinkFoodItems(foodItemIds);
        if (foodItemMap.isEmpty()) return;

        // Step 3: Aggregate total quantity ordered per food item
        Map<Id, Decimal> qtyOrdered = aggregateOrderedQuantities(newItems, foodItemMap);

        // Step 4: Deduct stock and collect low stock items for alert
        List<Food_Item__c> itemsToUpdate = new List<Food_Item__c>();
        List<String>       lowStockNames = new List<String>();

        deductStockAndFlagLow(qtyOrdered, foodItemMap, itemsToUpdate, lowStockNames);

        // Step 5: Persist stock updates
        if (!itemsToUpdate.isEmpty()) {
            update itemsToUpdate;
        }

        // Step 6: Send low stock email alert to manager if needed
        if (!lowStockNames.isEmpty()) {
            sendLowStockAlert(lowStockNames);
        }
    }

    // ── Private Helpers ────────────────────────────────────────────────────────

    private static Set<Id> collectFoodItemIds(List<Order_Item__c> items) {
        Set<Id> ids = new Set<Id>();
        for (Order_Item__c item : items) {
            if (item.Food_Item__c != null) {
                ids.add(item.Food_Item__c);
            }
        }
        return ids;
    }

    private static Map<Id, Food_Item__c> fetchDrinkFoodItems(Set<Id> foodItemIds) {
        return new Map<Id, Food_Item__c>([
            SELECT Id, Name, Category__c, Stock_Quantity__c, Available__c
            FROM   Food_Item__c
            WHERE  Id IN :foodItemIds
            AND    Category__c = 'Drinks'
        ]);
    }

    private static Map<Id, Decimal> aggregateOrderedQuantities(
        List<Order_Item__c> items,
        Map<Id, Food_Item__c> foodItemMap
    ) {
        Map<Id, Decimal> qtyOrdered = new Map<Id, Decimal>();
        for (Order_Item__c item : items) {
            if (!foodItemMap.containsKey(item.Food_Item__c)) continue;
            Decimal current = qtyOrdered.containsKey(item.Food_Item__c)
                ? qtyOrdered.get(item.Food_Item__c)
                : 0;
            qtyOrdered.put(
                item.Food_Item__c,
                current + (item.Quantity__c != null ? item.Quantity__c : 0)
            );
        }
        return qtyOrdered;
    }

    private static void deductStockAndFlagLow(
        Map<Id, Decimal>      qtyOrdered,
        Map<Id, Food_Item__c> foodItemMap,
        List<Food_Item__c>    itemsToUpdate,
        List<String>          lowStockNames
    ) {
        for (Id foodId : qtyOrdered.keySet()) {
            Food_Item__c food    = foodItemMap.get(foodId);
            Decimal      current = food.Stock_Quantity__c != null ? food.Stock_Quantity__c : 0;
            Decimal      newQty  = current - qtyOrdered.get(foodId);

            if (newQty < 0) newQty = 0;

            Food_Item__c toUpdate      = new Food_Item__c();
            toUpdate.Id                = foodId;
            toUpdate.Stock_Quantity__c = newQty;
            toUpdate.Available__c      = (newQty > 0);
            itemsToUpdate.add(toUpdate);

            if (newQty < LOW_STOCK_THRESHOLD) {
                lowStockNames.add(food.Name + ' (Remaining: ' + newQty.intValue() + ')');
            }
        }
    }

    private static void sendLowStockAlert(List<String> lowStockNames) {
        List<User> managers = [
            SELECT Id, Email
            FROM   User
            WHERE  Profile.Name = 'SavorFlow Manager'
            AND    IsActive = true
            LIMIT  1
        ];

        if (managers.isEmpty()) return;

        String body = 'Dear Manager,\n\n';
        body += 'The following drinks are running low on stock:\n\n';
        for (String item : lowStockNames) {
            body += '• ' + item + '\n';
        }
        body += '\nPlease restock as soon as possible.\n\n';
        body += 'Regards,\nSavorFlow System';

        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ managers[0].Email });
            mail.setSubject('⚠️ SavorFlow — Low Stock Alert');
            mail.setPlainTextBody(body);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            System.debug('Low stock email failed: ' + e.getMessage());
        }
    }
}