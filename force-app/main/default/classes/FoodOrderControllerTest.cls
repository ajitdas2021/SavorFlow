

@isTest
private class FoodOrderControllerTest {

    @TestSetup
    static void setupTestData() {

        // --- Meal food item (eligible for discount) ---
        Food_Item__c meal = new Food_Item__c(
            Name             = 'Test Burger',
            Price__c         = 100,
            Category__c      = 'Meal',
            Available__c     = true,
            Stock_Quantity__c = 50
        );

        // --- Drink food item (has stock validation) ---
        Food_Item__c drink = new Food_Item__c(
            Name             = 'Test Juice',
            Price__c         = 50,
            Category__c      = 'Drinks',
            Available__c     = true,
            Stock_Quantity__c = 10
        );

        insert new List<Food_Item__c>{ meal, drink };

        // --- An existing order to test addItemsToOrder ---
        Order__c order = new Order__c(
            Name               = 'ORD-001',
            Waiter_Name__c     = 'Test Waiter',
            Table_Number__c    = 5,
            Status__c          = 'In Progress',
            Order_Date_Time__c = System.now(),
            Order_Date__c      = System.today(),
            Total_Amount__c    = 200
        );
        insert order;
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 1: getFoodItems — should return all food items in the org
    // TYPE: Happy Path (normal retrieval)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetFoodItems_returnsItems() {
        Test.startTest();
            List<Food_Item__c> items = FoodOrderController.getFoodItems();
        Test.stopTest();

        System.assertNotEquals(0, items.size(), 'Should return at least the 2 food items created in setup');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 2: getActiveOrders — only New / In Progress / Served returned
    // TYPE: Happy Path (normal status filtering)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetActiveOrders_onlyActiveStatuses() {
        // Create a Completed order — should NOT appear
        Order__c completedOrder = new Order__c(
            Name               = 'ORD-DONE',
            Waiter_Name__c     = 'Waiter X',
            Table_Number__c    = 9,
            Status__c          = 'Completed',
            Order_Date_Time__c = System.now(),
            Order_Date__c      = System.today(),
            Total_Amount__c    = 0
        );
        insert completedOrder;

        Test.startTest();
            List<Order__c> active = FoodOrderController.getActiveOrders();
        Test.stopTest();

        for (Order__c o : active) {
            System.assert(
                o.Status__c == 'New' || o.Status__c == 'In Progress' || o.Status__c == 'Served',
                'Only active statuses should be returned, got: ' + o.Status__c
            );
        }
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 3: createOrder — happy path with a Meal item
    // TYPE: Happy Path (normal order creation)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testCreateOrder_successfullyCreatesOrderAndItems() {
        Food_Item__c meal = [SELECT Id, Price__c FROM Food_Item__c WHERE Name = 'Test Burger' LIMIT 1];

        List<Map<String, Object>> lines = new List<Map<String, Object>>{
            new Map<String, Object>{ 'foodItemId' => (String) meal.Id, 'quantity' => 2 }
        };
        String orderLinesJson = JSON.serialize(lines);

        Test.startTest();
            String orderId = FoodOrderController.createOrder('ORD-NEW', 'Ali', 3, orderLinesJson);
        Test.stopTest();

        System.assertNotEquals(null, orderId, 'Returned order Id should not be null');

        Order__c created = [SELECT Id, Status__c, Total_Amount__c FROM Order__c WHERE Id = :orderId];
        System.assertEquals('New', created.Status__c, 'Order status should be New');
        System.assert(created.Total_Amount__c > 0, 'Total amount should be greater than zero');

        List<Order_Item__c> items = [SELECT Id FROM Order_Item__c WHERE Order__c = :orderId];
        System.assertEquals(1, items.size(), 'One order item should be created');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 4: createOrder — drink exceeds stock → AuraHandledException
    // TYPE: Error/Exception Case (validation failure)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testCreateOrder_drinkExceedsStock_throwsException() {
        Food_Item__c drink = [SELECT Id FROM Food_Item__c WHERE Name = 'Test Juice' LIMIT 1];

        // Stock is 10, we order 99 — should fail
        List<Map<String, Object>> lines = new List<Map<String, Object>>{
            new Map<String, Object>{ 'foodItemId' => (String) drink.Id, 'quantity' => 99 }
        };
        String orderLinesJson = JSON.serialize(lines);

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            FoodOrderController.createOrder('ORD-FAIL', 'Sara', 2, orderLinesJson);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
           System.assert(e.getMessage().contains('Only'), 'Exception message should mention available stock');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown for over-stock drink order');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 5: addItemsToOrder — successfully adds items to an existing order
    // TYPE: Happy Path (item addition and total update)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testAddItemsToOrder_addsItemsAndUpdatesTotal() {
        Order__c order    = [SELECT Id, Total_Amount__c FROM Order__c WHERE Name = 'ORD-001' LIMIT 1];
        Food_Item__c meal = [SELECT Id FROM Food_Item__c WHERE Name = 'Test Burger' LIMIT 1];

        Decimal previousTotal = order.Total_Amount__c;

        List<Map<String, Object>> lines = new List<Map<String, Object>>{
            new Map<String, Object>{ 'foodItemId' => (String) meal.Id, 'quantity' => 1 }
        };
        String orderLinesJson = JSON.serialize(lines);

        Test.startTest();
            FoodOrderController.addItemsToOrder((String) order.Id, orderLinesJson);
        Test.stopTest();

        Order__c updated = [SELECT Total_Amount__c, Status__c FROM Order__c WHERE Id = :order.Id];
        System.assert(updated.Total_Amount__c > previousTotal, 'Total amount should increase after adding items');
        System.assertEquals('New', updated.Status__c, 'Status should be reset to New after adding items');

        List<Order_Item__c> items = [SELECT Id FROM Order_Item__c WHERE Order__c = :order.Id];
        System.assert(!items.isEmpty(), 'At least one order item should exist');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 6: addItemsToOrder — drink exceeds stock → AuraHandledException
    // TYPE: Error/Exception Case (validation failure on add)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testAddItemsToOrder_drinkExceedsStock_throwsException() {
        Order__c  order = [SELECT Id FROM Order__c WHERE Name = 'ORD-001' LIMIT 1];
        Food_Item__c drink = [SELECT Id FROM Food_Item__c WHERE Name = 'Test Juice' LIMIT 1];

        List<Map<String, Object>> lines = new List<Map<String, Object>>{
            new Map<String, Object>{ 'foodItemId' => (String) drink.Id, 'quantity' => 999 }
        };
        String orderLinesJson = JSON.serialize(lines);

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            FoodOrderController.addItemsToOrder((String) order.Id, orderLinesJson);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown when drink quantity exceeds stock');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 7: addItemsToOrder — resets Is_New_Item__c flag when order is New
    // TYPE: Happy Path (with side effects on existing items)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testAddItemsToOrder_resetsNewItemFlag_whenOrderIsNew() {
        Food_Item__c meal = [SELECT Id FROM Food_Item__c WHERE Name = 'Test Burger' LIMIT 1];

        // Create a NEW order with one item already flagged as Is_New_Item__c = true
        Order__c order = new Order__c(
            Name               = 'ORD-FLAG',
            Waiter_Name__c     = 'Waiter Y',
            Table_Number__c    = 7,
            Status__c          = 'New',
            Order_Date_Time__c = System.now(),
            Order_Date__c      = System.today(),
            Total_Amount__c    = 100
        );
        insert order;

        Order_Item__c existingItem = new Order_Item__c(
            Order__c       = order.Id,
            Food_Item__c   = meal.Id,
            Quantity__c    = 1,
            Total_Price__c = 100,
            Is_New_Item__c = true
        );
        insert existingItem;

        List<Map<String, Object>> lines = new List<Map<String, Object>>{
            new Map<String, Object>{ 'foodItemId' => (String) meal.Id, 'quantity' => 1 }
        };

        Test.startTest();
            FoodOrderController.addItemsToOrder((String) order.Id, JSON.serialize(lines));
        Test.stopTest();

        Order_Item__c refreshed = [SELECT Is_New_Item__c FROM Order_Item__c WHERE Id = :existingItem.Id];
        System.assertEquals(false, refreshed.Is_New_Item__c, 'Previous new item flag should be reset to false');
    }
}