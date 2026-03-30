/**
 * Test Class: ReceptionistViewController
 * ========================================
 * Covers:
 *  1. getServedOrders — only Served orders returned
 *  2. markOrderCompleted — updates status to Completed
 */
@isTest
private class ReceptionistViewControllerTest {

    @TestSetup
    static void setupTestData() {

        Food_Item__c food = new Food_Item__c(
            Name             = 'Reception Test Meal',
            Price__c         = 120,
            Category__c      = 'Meal',
            Available__c     = true,
            Stock_Quantity__c = 20
        );
        insert food;

        // Served order — should appear in receptionist view
        Order__c servedOrder = new Order__c(
            Name               = 'REC-ORD-001',
            Waiter_Name__c     = 'Rec Waiter',
            Table_Number__c    = 1,
            Status__c          = 'Served',
            Order_Date_Time__c = System.now(),
            Order_Date__c      = System.today(),
            Total_Amount__c    = 240
        );

        // New order — should NOT appear in receptionist view
        Order__c newOrder = new Order__c(
            Name               = 'REC-ORD-002',
            Waiter_Name__c     = 'Rec Waiter',
            Table_Number__c    = 2,
            Status__c          = 'New',
            Order_Date_Time__c = System.now(),
            Order_Date__c      = System.today(),
            Total_Amount__c    = 0
        );

        insert new List<Order__c>{ servedOrder, newOrder };

        // Add an order item to the served order
        Order_Item__c item = new Order_Item__c(
            Order__c        = servedOrder.Id,
            Food_Item__c    = food.Id,
            Quantity__c     = 2,
            Total_Price__c  = 240,
            Discount_Amount__c = 0,
            Is_New_Item__c  = false
        );
        insert item;
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 1: getServedOrders — returns only Served orders
    // TYPE: Happy Path (normal filtering)
    // ─────────────────────────────────────────────────────────────────

    @isTest
    static void testGetServedOrders_returnsOnlyServedOrders() {
        Test.startTest();
            List<Order__c> served = ReceptionistViewController.getServedOrders();
        Test.stopTest();

        System.assert(!served.isEmpty(), 'Should return at least one served order');

        for (Order__c o : served) {
            System.assertEquals('Served', o.Status__c, 'Only Served orders should be returned');
        }
    }



    // TEST 2: getServedOrders — returns order with its related items

    @isTest
    static void testGetServedOrders_includesOrderItems() {
        Test.startTest();
            List<Order__c> served = ReceptionistViewController.getServedOrders();
        Test.stopTest();

        Order__c target = null;
        for (Order__c o : served) {
            if (o.Name == 'REC-ORD-001') {
                target = o;
                break;
            }
        }

        System.assertNotEquals(null, target, 'REC-ORD-001 should be in the served list');
        System.assert(!target.Order_Items__r.isEmpty(), 'Order should include its related order items');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 3: markOrderCompleted — changes status from Served to Completed
    // TYPE: Happy Path (status transition)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testMarkOrderCompleted_updatesStatusToCompleted() {
        Order__c order = [SELECT Id FROM Order__c WHERE Name = 'REC-ORD-001' LIMIT 1];

        Test.startTest();
            ReceptionistViewController.markOrderCompleted(order.Id);
        Test.stopTest();

        Order__c updated = [SELECT Status__c FROM Order__c WHERE Id = :order.Id];
        System.assertEquals('Completed', updated.Status__c, 'Order status should be Completed after marking');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 4: getServedOrders — Completed order should NOT appear
    // TYPE: Happy Path (filter verification after state change)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetServedOrders_completedOrderNotReturned() {
        Order__c order = [SELECT Id FROM Order__c WHERE Name = 'REC-ORD-001' LIMIT 1];
        ReceptionistViewController.markOrderCompleted(order.Id);

        Test.startTest();
            List<Order__c> served = ReceptionistViewController.getServedOrders();
        Test.stopTest();

        for (Order__c o : served) {
            System.assertNotEquals(order.Id, o.Id, 'Completed order should not appear in served list');
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 5: getServedOrders — empty when no served orders exist
    // TYPE: Boundary Testing (empty result set)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetServedOrders_emptyWhenNoneServed() {
        // Mark the only served order as completed
        Order__c served = [SELECT Id FROM Order__c WHERE Status__c = 'Served' LIMIT 1];
        ReceptionistViewController.markOrderCompleted(served.Id);

        Test.startTest();
            List<Order__c> servedOrders = ReceptionistViewController.getServedOrders();
        Test.stopTest();

        System.assertEquals(0, servedOrders.size(), 'Should return empty list when no served orders exist');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 6: markOrderCompleted — bulk update multiple orders
    // TYPE: Happy Path (bulk operation)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testMarkOrderCompleted_bulkUpdate() {
        Food_Item__c food = [SELECT Id FROM Food_Item__c LIMIT 1];

        // Create additional served orders
        List<Order__c> servedOrders = new List<Order__c>();
        for (Integer i = 0; i < 3; i++) {
            Order__c order = new Order__c(
                Name               = 'REC-BULK-' + i,
                Waiter_Name__c     = 'Bulk Waiter',
                Table_Number__c    = 10 + i,
                Status__c          = 'Served',
                Order_Date_Time__c = System.now(),
                Order_Date__c      = System.today(),
                Total_Amount__c    = 100 * (i + 1)
            );
            servedOrders.add(order);
        }
        insert servedOrders;

        Test.startTest();
            for (Order__c o : servedOrders) {
                ReceptionistViewController.markOrderCompleted(o.Id);
            }
        Test.stopTest();

        List<Order__c> completed = [SELECT Status__c FROM Order__c WHERE Id IN :servedOrders];
        for (Order__c o : completed) {
            System.assertEquals('Completed', o.Status__c, 'All orders should be marked as Completed');
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 7: getServedOrders — verifies correct order items included
    // TYPE: Happy Path (data accuracy verification)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetServedOrders_correctOrderItemsQtyAndPrice() {
        Test.startTest();
            List<Order__c> served = ReceptionistViewController.getServedOrders();
        Test.stopTest();

        Order__c target = null;
        for (Order__c o : served) {
            if (o.Name == 'REC-ORD-001') {
                target = o;
                break;
            }
        }

        System.assertNotEquals(null, target, 'Should find the test order');
        System.assertEquals(1, target.Order_Items__r.size(), 'Should have 1 order item');
        
        Order_Item__c item = target.Order_Items__r[0];
        System.assertEquals(2, item.Quantity__c, 'Item quantity should be 2');
        System.assertEquals(240, item.Total_Price__c, 'Item total price should be 240');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 8: markOrderCompleted — order status field updated correctly
    // TYPE: Happy Path (field-level verification)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testMarkOrderCompleted_statusFieldVerification() {
        Order__c order = [SELECT Id, Status__c FROM Order__c WHERE Name = 'REC-ORD-001' LIMIT 1];
        System.assertEquals('Served', order.Status__c, 'Pre-condition: order should be Served');

        Test.startTest();
            ReceptionistViewController.markOrderCompleted(order.Id);
        Test.stopTest();

        Order__c updated = [SELECT Status__c FROM Order__c WHERE Id = :order.Id];
        System.assertEquals('Completed', updated.Status__c, 'Status should be Completed');
        
        List<Order_Item__c> items = [SELECT Id FROM Order_Item__c WHERE Order__c = :order.Id];
        System.assertEquals(1, items.size(), 'Order items should still be associated');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 9: markOrderCompleted — operates independently on multiple orders
    // TYPE: Happy Path (independent operation isolation)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testMarkOrderCompleted_independentOperations() {
        Order__c order1 = [SELECT Id FROM Order__c WHERE Status__c = 'Served' LIMIT 1];
        Order__c order2 = new Order__c(
            Name               = 'REC-INDEP',
            Waiter_Name__c     = 'Indep Waiter',
            Table_Number__c    = 99,
            Status__c          = 'Served',
            Order_Date_Time__c = System.now(),
            Order_Date__c      = System.today(),
            Total_Amount__c    = 150
        );
        insert order2;

        Test.startTest();
            ReceptionistViewController.markOrderCompleted(order1.Id);
        Test.stopTest();

        Order__c check1 = [SELECT Status__c FROM Order__c WHERE Id = :order1.Id];
        Order__c check2 = [SELECT Status__c FROM Order__c WHERE Id = :order2.Id];

        System.assertEquals('Completed', check1.Status__c, 'Order 1 should be Completed');
        System.assertEquals('Served', check2.Status__c, 'Order 2 should still be Served');
    }
}