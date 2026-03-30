/**
 * Test Class: ChefViewController
 * ================================
 * Covers:
 *  1. getActiveOrders — only New / In Progress returned
 *  2. updateOrderStatus — generic status change (e.g. In Progress)
 *  3. updateOrderStatus to Served — resets Is_New_Item__c flags
 *  4. updateOrderStatus to Served — sends notification when waiter user exists
 */
@isTest
private class ChefViewControllerTest {

    @TestSetup
    static void setupTestData() {

        // A food item for order items
        Food_Item__c food = new Food_Item__c(
            Name             = 'Chef Test Meal',
            Price__c         = 80,
            Category__c      = 'Meal',
            Available__c     = true,
            Stock_Quantity__c = 30
        );
        insert food;

        // Order in New status
        Order__c newOrder = new Order__c(
            Name               = 'CHEF-ORD-001',
            Waiter_Name__c     = 'Test Waiter Chef',
            Table_Number__c    = 2,
            Status__c          = 'New',
            Order_Date_Time__c = System.now(),
            Order_Date__c      = System.today(),
            Total_Amount__c    = 160
        );

        // Order in In Progress status
        Order__c ipOrder = new Order__c(
            Name               = 'CHEF-ORD-002',
            Waiter_Name__c     = 'Test Waiter Chef',
            Table_Number__c    = 3,
            Status__c          = 'In Progress',
            Order_Date_Time__c = System.now(),
            Order_Date__c      = System.today(),
            Total_Amount__c    = 80
        );

        // Completed order — should NOT show in chef view
        Order__c doneOrder = new Order__c(
            Name               = 'CHEF-ORD-003',
            Waiter_Name__c     = 'Test Waiter Chef',
            Table_Number__c    = 4,
            Status__c          = 'Completed',
            Order_Date_Time__c = System.now(),
            Order_Date__c      = System.today(),
            Total_Amount__c    = 0
        );

        insert new List<Order__c>{ newOrder, ipOrder, doneOrder };

        // Add items to newOrder with Is_New_Item__c = true
        Order_Item__c item = new Order_Item__c(
            Order__c       = newOrder.Id,
            Food_Item__c   = food.Id,
            Quantity__c    = 2,
            Total_Price__c = 160,
            Is_New_Item__c = true
        );
        insert item;
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 1: getActiveOrders — returns only New and In Progress orders
    // TYPE: Happy Path (normal filtering behavior)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetActiveOrders_returnsOnlyNewAndInProgress() {
        Test.startTest();
            List<Order__c> orders = ChefViewController.getActiveOrders();
        Test.stopTest();

        System.assert(!orders.isEmpty(), 'Should return at least some active orders');

        for (Order__c o : orders) {
            System.assert(
                o.Status__c == 'New' || o.Status__c == 'In Progress',
                'Only New or In Progress orders expected, got: ' + o.Status__c
            );
        }
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 2: updateOrderStatus — change to In Progress
    // TYPE: Happy Path (normal status update)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testUpdateOrderStatus_setsStatusToInProgress() {
        Order__c order = [SELECT Id FROM Order__c WHERE Name = 'CHEF-ORD-001' LIMIT 1];

        Test.startTest();
            ChefViewController.updateOrderStatus((String) order.Id, 'In Progress');
        Test.stopTest();

        Order__c updated = [SELECT Status__c FROM Order__c WHERE Id = :order.Id];
        System.assertEquals('In Progress', updated.Status__c, 'Status should be updated to In Progress');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 3: updateOrderStatus to Served — Is_New_Item__c reset to false
    // TYPE: Happy Path (normal behavior with side effects)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testUpdateOrderStatus_toServed_resetsNewItemFlags() {
        Order__c order   = [SELECT Id FROM Order__c WHERE Name = 'CHEF-ORD-001' LIMIT 1];
        Order_Item__c oi = [SELECT Id, Is_New_Item__c FROM Order_Item__c WHERE Order__c = :order.Id LIMIT 1];

        System.assertEquals(true, oi.Is_New_Item__c, 'Pre-condition: item should be flagged as new');

        Test.startTest();
            ChefViewController.updateOrderStatus((String) order.Id, 'Served');
        Test.stopTest();

        Order__c updatedOrder = [SELECT Status__c FROM Order__c WHERE Id = :order.Id];
        System.assertEquals('Served', updatedOrder.Status__c, 'Order status should be Served');

        Order_Item__c updatedItem = [SELECT Is_New_Item__c FROM Order_Item__c WHERE Id = :oi.Id];
        System.assertEquals(false, updatedItem.Is_New_Item__c, 'Is_New_Item__c should be reset to false after Served');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 4: updateOrderStatus to Served — runs without error even when
    //         no matching waiter user exists (no notification crash)
    // TYPE: Edge Case (missing related record - graceful handling)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testUpdateOrderStatus_toServed_noWaiterUser_noException() {
        // This order has Waiter_Name__c = 'Test Waiter Chef' but no matching User record
        Order__c order = [SELECT Id FROM Order__c WHERE Name = 'CHEF-ORD-002' LIMIT 1];

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ChefViewController.updateOrderStatus((String) order.Id, 'Served');
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(false, exceptionThrown, 'No exception should be thrown when waiter user is not found');

        Order__c updated = [SELECT Status__c FROM Order__c WHERE Id = :order.Id];
        System.assertEquals('Served', updated.Status__c, 'Order status should still be set to Served');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 5: getActiveOrders with multiple items — verifies all items returned
    // TYPE: Happy Path (normal behavior with multiple child records)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetActiveOrders_withMultipleItems() {
        Food_Item__c food2 = new Food_Item__c(
            Name             = 'Chef Test Appetizer',
            Price__c         = 50,
            Category__c      = 'Appetizer',
            Available__c     = true,
            Stock_Quantity__c = 20
        );
        insert food2;

        Order__c order = [SELECT Id FROM Order__c WHERE Name = 'CHEF-ORD-001' LIMIT 1];
        Order_Item__c item2 = new Order_Item__c(
            Order__c       = order.Id,
            Food_Item__c   = food2.Id,
            Quantity__c    = 1,
            Total_Price__c = 50,
            Is_New_Item__c = true
        );
        insert item2;

        Test.startTest();
            List<Order__c> orders = ChefViewController.getActiveOrders();
        Test.stopTest();

        Order__c targetOrder = null;
        for (Order__c o : orders) {
            if (o.Id == order.Id) {
                targetOrder = o;
                break;
            }
        }

        System.assertNotEquals(null, targetOrder, 'Order should be in active list');
        System.assertEquals(2, targetOrder.Order_Items__r.size(), 'Order should have 2 items');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 6: updateOrderStatus — multiple status changes in sequence
    // TYPE: Happy Path (sequential operation flow)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testUpdateOrderStatus_multipleStatusChanges() {
        Order__c order = [SELECT Id, Status__c FROM Order__c WHERE Name = 'CHEF-ORD-001' LIMIT 1];
        System.assertEquals('New', order.Status__c, 'Initial status should be New');

        Test.startTest();
            ChefViewController.updateOrderStatus((String) order.Id, 'In Progress');
            ChefViewController.updateOrderStatus((String) order.Id, 'Served');
        Test.stopTest();

        Order__c final_order = [SELECT Status__c FROM Order__c WHERE Id = :order.Id];
        System.assertEquals('Served', final_order.Status__c, 'Final status should be Served');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 7: getActiveOrders — empty result when all orders completed
    // TYPE: Boundary Testing (empty result set when no matching records)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetActiveOrders_emptyWhenAllCompleted() {
        // Update all orders to Completed
        List<Order__c> allOrders = [SELECT Id FROM Order__c];
        for (Order__c o : allOrders) {
            o.Status__c = 'Completed';
        }
        update allOrders;

        Test.startTest();
            List<Order__c> activeOrders = ChefViewController.getActiveOrders();
        Test.stopTest();

        System.assertEquals(0, activeOrders.size(), 'Should return empty list when no active orders exist');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 8: updateOrderStatus — with multiple new items all reset
    // TYPE: Happy Path (normal behavior with multiple affected records)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testUpdateOrderStatus_resetsMultipleNewItems() {
        Food_Item__c food2 = new Food_Item__c(
            Name             = 'Chef Test Dessert',
            Price__c         = 40,
            Category__c      = 'Dessert',
            Available__c     = true,
            Stock_Quantity__c = 15
        );
        insert food2;

        Order__c order = [SELECT Id FROM Order__c WHERE Name = 'CHEF-ORD-001' LIMIT 1];
        Order_Item__c item2 = new Order_Item__c(
            Order__c       = order.Id,
            Food_Item__c   = food2.Id,
            Quantity__c    = 1,
            Total_Price__c = 40,
            Is_New_Item__c = true
        );
        insert item2;

        Test.startTest();
            ChefViewController.updateOrderStatus((String) order.Id, 'Served');
        Test.stopTest();

        List<Order_Item__c> items = [SELECT Is_New_Item__c FROM Order_Item__c WHERE Order__c = :order.Id];
        System.assertEquals(2, items.size(), 'Order should have 2 items');
        for (Order_Item__c item : items) {
            System.assertEquals(false, item.Is_New_Item__c, 'All items should have Is_New_Item__c = false');
        }
    }
}