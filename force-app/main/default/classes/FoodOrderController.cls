public with sharing class FoodOrderController {

    @AuraEnabled(cacheable=true)
    public static List<Food_Item__c> getFoodItems() {
        return [
            SELECT  Id,
                    Name,
                    Price__c,
                    Category__c,
                    Available__c,
                    Food_Image__c
            FROM    Food_Item__c
            ORDER BY Category__c ASC, Name ASC
        ];
    }

    // Fetch active orders for Edit Order popup
    @AuraEnabled
    public static List<Order__c> getActiveOrders() {
        return [
            SELECT Id, Name, Table_Number__c, Waiter_Name__c,
                   Status__c, Order_Date_Time__c, Total_Amount__c,
                   (SELECT Id, Quantity__c, Total_Price__c, Discount_Amount__c,
                           Is_New_Item__c,
                           Food_Item__r.Name, Food_Item__r.Price__c,
                           Food_Item__r.Category__c
                    FROM Order_Items__r ORDER BY CreatedDate ASC)
            FROM Order__c
            WHERE Status__c IN ('New', 'In Progress', 'Served')
            ORDER BY Order_Date_Time__c DESC
        ];
    }

    // Helper — validate that no active order already exists for this table
    private static void validateTableAvailability(Integer tableNumber) {
        List<Order__c> existingOrders = [
            SELECT Id, Name, Status__c
            FROM   Order__c
            WHERE  Table_Number__c = :tableNumber
            AND    Status__c IN ('New', 'In Progress', 'Served')
            LIMIT  1
        ];

        if (!existingOrders.isEmpty()) {
            Order__c existing = existingOrders[0];
            throw new AuraHandledException(
                'Table ' + tableNumber + ' already has an active order ('
                + existing.Name + ' — ' + existing.Status__c
                + '). Please wait until the receptionist completes the current bill.'
            );
        }
    }

    // Helper — send notification to all active Chef users
    private static void notifyChefs(String orderName, Integer tableNumber, String orderId) {
        try {
            List<User> chefs = [
                SELECT Id
                FROM   User
                WHERE  Id IN (
                    SELECT AssigneeId
                    FROM   PermissionSetAssignment
                    WHERE  PermissionSet.Name = 'Chef_Permission'
                )
                AND IsActive = true
            ];

            if (chefs.isEmpty()) return;

            CustomNotificationType notifType = [
                SELECT Id
                FROM   CustomNotificationType
                WHERE  DeveloperName = 'New_Order_Notification'
                LIMIT  1
            ];

            Set<String> chefIds = new Set<String>();
            for (User chef : chefs) {
                chefIds.add(chef.Id);
            }

            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('🍽️ New Order!');
            notification.setBody('Order ' + orderName + ' for Table ' + tableNumber + ' has been placed.');
            notification.setNotificationTypeId(notifType.Id);
            notification.setTargetId(orderId);
            notification.send(chefIds);
        } catch (Exception e) {
            System.debug('Chef notification error: ' + e.getMessage());
        }
    }

    // Add new items to existing order
    @AuraEnabled
    public static void addItemsToOrder(String orderId, String orderLines) {
        List<Object> lines = (List<Object>) JSON.deserializeUntyped(orderLines);

        Set<Id> foodIds = new Set<Id>();
        for (Object line : lines) {
            Map<String, Object> m = (Map<String, Object>) line;
            foodIds.add((Id)(String) m.get('foodItemId'));
        }

        Map<Id, Food_Item__c> foodMap = new Map<Id, Food_Item__c>([
            SELECT Id, Price__c, Category__c, Stock_Quantity__c, Name
            FROM   Food_Item__c
            WHERE  Id IN :foodIds
        ]);

        // Validate stock for Drinks
        for (Object line : lines) {
            Map<String, Object> m  = (Map<String, Object>) line;
            Id      foodId = (Id)(String) m.get('foodItemId');
            Integer qty    = Integer.valueOf(m.get('quantity'));

            Food_Item__c food = foodMap.get(foodId);
            if (food != null && food.Category__c == 'Drinks') {
                Decimal stock = food.Stock_Quantity__c != null ? food.Stock_Quantity__c : 0;
                if (qty > stock) {
                    throw new AuraHandledException(
                        'Sorry! Only ' + stock.intValue() + ' units of ' + food.Name + ' available in stock.'
                    );
                }
            }
        }

        // Check discount time
        DateTime nowUTC    = DateTime.now();
        Integer  totalMins = nowUTC.hour() * 60 + nowUTC.minute() + 345;
        totalMins          = Math.mod(totalMins, 1440);
        Boolean isDiscountTime = (totalMins >= 540 && totalMins < 720);

        // Build new Order Items
        List<Order_Item__c> itemsToInsert = new List<Order_Item__c>();
        Decimal addedTotal = 0;

        for (Object line : lines) {
            Map<String, Object> m = (Map<String, Object>) line;
            Id      foodId  = (Id)(String) m.get('foodItemId');
            Integer qty     = Integer.valueOf(m.get('quantity'));

            Food_Item__c food      = foodMap.get(foodId);
            Decimal      price     = (food != null && food.Price__c != null) ? food.Price__c : 0;
            Boolean      isMeal    = (food != null && food.Category__c == 'Meal');
            Boolean      applyDisc = isMeal && isDiscountTime;

            Decimal original   = (price * qty).setScale(2);
            Decimal totalPrice = applyDisc ? (price * 0.85 * qty).setScale(2) : original;
            Decimal discount   = (original - totalPrice).setScale(2);

            Order_Item__c oi      = new Order_Item__c();
            oi.Order__c           = (Id) orderId;
            oi.Food_Item__c       = foodId;
            oi.Quantity__c        = qty;
            oi.Total_Price__c     = totalPrice;
            oi.Discount_Amount__c = discount;
            oi.Is_New_Item__c     = true;

            itemsToInsert.add(oi);
            addedTotal += totalPrice;
        }

        insert itemsToInsert;

        Order__c order = [SELECT Id, Status__c, Total_Amount__c, Previous_Status__c, Name, Table_Number__c FROM Order__c WHERE Id = :orderId LIMIT 1];

        // If order is still New — reset previous new items to false
        if (order.Status__c == 'New') {
            List<Order_Item__c> prevNewItems = [
                SELECT Id, Is_New_Item__c
                FROM   Order_Item__c
                WHERE  Order__c = :orderId
                AND    Is_New_Item__c = true
            ];
            for (Order_Item__c i : prevNewItems) {
                i.Is_New_Item__c = false;
            }
            if (!prevNewItems.isEmpty()) update prevNewItems;
        }

        order.Previous_Status__c  = order.Status__c;
        order.Total_Amount__c     = ((order.Total_Amount__c != null ? order.Total_Amount__c : 0) + addedTotal).setScale(2);
        order.Status__c           = 'New';
        update order;

        // Notify chefs about updated order
        notifyChefs(order.Name, Integer.valueOf(order.Table_Number__c), orderId);
    }

    @AuraEnabled
    public static String createOrder(
        String  orderName,
        String  waiterName,
        Integer tableNumber,
        String  orderLines
    ) {
        // ── Gate 1: Block if table already has an active or served order ──
        validateTableAvailability(tableNumber);

        // ── Gate 2: Validate stock for Drinks ─────────────────────────────
        List<Object> lines = (List<Object>) JSON.deserializeUntyped(orderLines);

        Set<Id> foodIds = new Set<Id>();
        for (Object line : lines) {
            Map<String, Object> m = (Map<String, Object>) line;
            foodIds.add((Id)(String) m.get('foodItemId'));
        }

        Map<Id, Food_Item__c> foodMap = new Map<Id, Food_Item__c>([
            SELECT Id, Price__c, Category__c, Stock_Quantity__c, Name
            FROM   Food_Item__c
            WHERE  Id IN :foodIds
        ]);

        for (Object line : lines) {
            Map<String, Object> m  = (Map<String, Object>) line;
            Id      foodId = (Id)(String) m.get('foodItemId');
            Integer qty    = Integer.valueOf(m.get('quantity'));

            Food_Item__c food = foodMap.get(foodId);
            if (food != null && food.Category__c == 'Drinks') {
                Decimal stock = food.Stock_Quantity__c != null ? food.Stock_Quantity__c : 0;
                if (qty > stock) {
                    throw new AuraHandledException(
                        'Sorry! Only ' + stock.intValue() + ' units of ' + food.Name + ' available in stock.'
                    );
                }
            }
        }

        // ── Check discount time ────────────────────────────────────────────
        DateTime nowUTC    = DateTime.now();
        Integer  totalMins = nowUTC.hour() * 60 + nowUTC.minute() + 345;
        totalMins          = Math.mod(totalMins, 1440);
        Boolean isDiscountTime = (totalMins >= 540 && totalMins < 720);

        // ── Insert Order ───────────────────────────────────────────────────
        Order__c order           = new Order__c();
        order.Name               = orderName;
        order.Waiter_Name__c     = waiterName;
        order.Table_Number__c    = tableNumber;
        order.Status__c          = 'New';
        order.Previous_Status__c = null;
        order.Order_Date_Time__c = System.now();
        order.Order_Date__c      = System.today();
        order.Total_Amount__c    = 0;
        insert order;

        // ── Build and Insert Order Items ───────────────────────────────────
        List<Order_Item__c> itemsToInsert = new List<Order_Item__c>();
        Decimal orderTotal = 0;

        for (Object line : lines) {
            Map<String, Object> m = (Map<String, Object>) line;
            Id      foodId  = (Id)(String) m.get('foodItemId');
            Integer qty     = Integer.valueOf(m.get('quantity'));

            Food_Item__c food      = foodMap.get(foodId);
            Decimal      price     = (food != null && food.Price__c != null) ? food.Price__c : 0;
            Boolean      isMeal    = (food != null && food.Category__c == 'Meal');
            Boolean      applyDisc = isMeal && isDiscountTime;

            Decimal original   = (price * qty).setScale(2);
            Decimal totalPrice = applyDisc ? (price * 0.85 * qty).setScale(2) : original;
            Decimal discount   = (original - totalPrice).setScale(2);

            Order_Item__c oi      = new Order_Item__c();
            oi.Order__c           = order.Id;
            oi.Food_Item__c       = foodId;
            oi.Quantity__c        = qty;
            oi.Total_Price__c     = totalPrice;
            oi.Discount_Amount__c = discount;
            oi.Is_New_Item__c     = false;

            itemsToInsert.add(oi);
            orderTotal += totalPrice;
        }

        insert itemsToInsert;

        order.Total_Amount__c = orderTotal.setScale(2);
        update order;

        // ── Notify Chefs ───────────────────────────────────────────────────
        notifyChefs(orderName, tableNumber, order.Id);

        return order.Id;
    }
}