/**
 * Test Class: ManagerDashboardController
 * ========================================
 * Covers:
 *  1.  getDashboardStats — activeOrders count (New + In Progress)
 *  2.  getDashboardStats — tablesInUse distinct count
 *  3.  getDashboardStats — salesToday sum (Completed, today)
 *  4.  getDashboardStats — salesThisMonth sum (Completed, this month)
 *  5.  getDashboardStats — ordersByStatus map keys
 *  6.  getDashboardStats — managerName from current user
 *  7.  getDashboardStats — waiterNames list populated
 *  8.  getDashboardStats — salesToday returns 0 when no completed orders
 *  9.  getFilteredOrders — no filters (returns all completed)
 *  10. getFilteredOrders — filter by waiterName
 *  11. getFilteredOrders — filter by fromDate and toDate
 *  12. getFilteredOrders — waiterName = 'All' ignored (returns all)
 *  13. getFilteredOrders — recordLimit respected
 *  14. getFilteredOrders — returns empty list when no match
 */
@isTest
private class ManagerDashboardControllerTest {

    // ─────────────────────────────────────────────────────────────────
    // STEP 2: Shared test data
    // ─────────────────────────────────────────────────────────────────
    @TestSetup
    static void setupTestData() {

        // Active orders — 2 tables in use
        Order__c newOrder = new Order__c(
            Name               = 'MGR-ORD-001',
            Waiter_Name__c     = 'Alice',
            Table_Number__c    = 1,
            Status__c          = 'New',
            Order_Date_Time__c = System.now(),
            Order_Date__c      = System.today(),
            Total_Amount__c    = 100
        );

        Order__c ipOrder = new Order__c(
            Name               = 'MGR-ORD-002',
            Waiter_Name__c     = 'Bob',
            Table_Number__c    = 2,
            Status__c          = 'In Progress',
            Order_Date_Time__c = System.now(),
            Order_Date__c      = System.today(),
            Total_Amount__c    = 150
        );

        // Completed orders today — for salesToday
        Order__c comp1 = new Order__c(
            Name               = 'MGR-ORD-003',
            Waiter_Name__c     = 'Alice',
            Table_Number__c    = 3,
            Status__c          = 'Completed',
            Order_Date_Time__c = System.now(),
            Order_Date__c      = System.today(),
            Total_Amount__c    = 200
        );

        Order__c comp2 = new Order__c(
            Name               = 'MGR-ORD-004',
            Waiter_Name__c     = 'Bob',
            Table_Number__c    = 4,
            Status__c          = 'Completed',
            Order_Date_Time__c = System.now(),
            Order_Date__c      = System.today(),
            Total_Amount__c    = 300
        );

        // Served order — should NOT count in active or sales
        Order__c served = new Order__c(
            Name               = 'MGR-ORD-005',
            Waiter_Name__c     = 'Alice',
            Table_Number__c    = 5,
            Status__c          = 'Served',
            Order_Date_Time__c = System.now(),
            Order_Date__c      = System.today(),
            Total_Amount__c    = 80
        );

        insert new List<Order__c>{ newOrder, ipOrder, comp1, comp2, served };
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 1: activeOrders — counts only New + In Progress
    // TYPE: Happy Path (normal count calculation)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetDashboardStats_activeOrdersCount() {
        Test.startTest();
            Map<String, Object> stats = ManagerDashboardController.getDashboardStats();
        Test.stopTest();

        Integer activeOrders = (Integer) stats.get('activeOrders');
        System.assertEquals(2, activeOrders, 'Active orders should be 2 (New + In Progress)');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 2: tablesInUse — distinct table numbers for active orders
    // TYPE: Happy Path (distinct count)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetDashboardStats_tablesInUse() {
        Test.startTest();
            Map<String, Object> stats = ManagerDashboardController.getDashboardStats();
        Test.stopTest();

        Object tablesInUse = stats.get('tablesInUse');
        System.assertNotEquals(null, tablesInUse, 'tablesInUse should not be null');
        System.assertEquals(2, Integer.valueOf(String.valueOf(tablesInUse)), 'Tables in use should be 2 distinct tables');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 3: salesToday — sum of Completed orders today
    // TYPE: Happy Path (normal aggregation)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetDashboardStats_salesToday() {
        Test.startTest();
            Map<String, Object> stats = ManagerDashboardController.getDashboardStats();
        Test.stopTest();

        Object salesToday = stats.get('salesToday');
        System.assertNotEquals(null, salesToday, 'salesToday should not be null');

        Decimal total = Decimal.valueOf(String.valueOf(salesToday));
        System.assertEquals(500, total, 'Sales today should be 200 + 300 = 500');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 4: salesThisMonth — includes today's completed orders
    // TYPE: Happy Path (date range aggregation)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetDashboardStats_salesThisMonth() {
        Test.startTest();
            Map<String, Object> stats = ManagerDashboardController.getDashboardStats();
        Test.stopTest();

        Object salesThisMonth = stats.get('salesThisMonth');
        System.assertNotEquals(null, salesThisMonth, 'salesThisMonth should not be null');

        Decimal total = Decimal.valueOf(String.valueOf(salesThisMonth));
        System.assert(total >= 500, 'Sales this month should be at least 500 (today\'s orders)');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 5: ordersByStatus — map contains today's statuses
    // TYPE: Happy Path (status grouping)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetDashboardStats_ordersByStatus() {
        Test.startTest();
            Map<String, Object> stats = ManagerDashboardController.getDashboardStats();
        Test.stopTest();

        Map<String, Integer> statusMap = (Map<String, Integer>) stats.get('ordersByStatus');
        System.assertNotEquals(null, statusMap, 'ordersByStatus map should not be null');
        System.assert(statusMap.containsKey('New'),       'Should contain New status');
        System.assert(statusMap.containsKey('Completed'), 'Should contain Completed status');
        System.assertEquals(1, statusMap.get('New'),       'New count should be 1');
        System.assertEquals(2, statusMap.get('Completed'), 'Completed count should be 2');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 6: managerName — returns current running user's name
    // TYPE: Happy Path (user context retrieval)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetDashboardStats_managerName() {
        Test.startTest();
            Map<String, Object> stats = ManagerDashboardController.getDashboardStats();
        Test.stopTest();

        String managerName = (String) stats.get('managerName');
        System.assertNotEquals(null, managerName, 'managerName should not be null');
        System.assertNotEquals('', managerName, 'managerName should not be empty');

        // Verify it matches the actual running user
        User currentUser = [SELECT Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        System.assertEquals(currentUser.Name, managerName, 'managerName should match running user');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 7: waiterNames — distinct waiter names from orders
    // TYPE: Happy Path (distinct list retrieval)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetDashboardStats_waiterNames() {
        Test.startTest();
            Map<String, Object> stats = ManagerDashboardController.getDashboardStats();
        Test.stopTest();

        List<String> waiterNames = (List<String>) stats.get('waiterNames');
        System.assertNotEquals(null, waiterNames, 'waiterNames should not be null');
        System.assert(waiterNames.size() >= 2, 'Should have at least 2 distinct waiters (Alice, Bob)');
        System.assert(waiterNames.contains('Alice'), 'Alice should be in waiter list');
        System.assert(waiterNames.contains('Bob'),   'Bob should be in waiter list');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 8: salesToday returns 0 when no completed orders exist
    // TYPE: Boundary Testing (zero aggregate case)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetDashboardStats_salesToday_zeroWhenNoCompleted() {
        // Delete all completed orders first
        List<Order__c> completed = [SELECT Id FROM Order__c WHERE Status__c = 'Completed'];
        delete completed;

        Test.startTest();
            Map<String, Object> stats = ManagerDashboardController.getDashboardStats();
        Test.stopTest();

        Object salesToday = stats.get('salesToday');
        System.assertEquals(0, Integer.valueOf(String.valueOf(salesToday)),
            'salesToday should be 0 when no completed orders exist');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 9: getFilteredOrders — no filters returns all completed
    // TYPE: Happy Path (baseline query)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetFilteredOrders_noFilters_returnsAllCompleted() {
        Test.startTest();
            List<Order__c> orders = ManagerDashboardController.getFilteredOrders(
                null, null, null, null
            );
        Test.stopTest();

        System.assertEquals(2, orders.size(), 'Should return 2 completed orders with no filters');
        for (Order__c o : orders) {
            // All returned must be Completed — confirmed by query
            System.assertNotEquals(null, o.Id, 'Order Id should not be null');
        }
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 10: getFilteredOrders — filter by waiterName
    // TYPE: Happy Path (single filter criterion)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetFilteredOrders_filterByWaiter() {
        Test.startTest();
            List<Order__c> orders = ManagerDashboardController.getFilteredOrders(
                null, null, 'Alice', null
            );
        Test.stopTest();

        System.assertEquals(1, orders.size(), 'Should return only Alice\'s completed order');
        System.assertEquals('Alice', orders[0].Waiter_Name__c, 'Waiter should be Alice');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 11: getFilteredOrders — fromDate and toDate filter
    // TYPE: Happy Path (date range filtering)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetFilteredOrders_filterByDateRange() {
        String today    = String.valueOf(System.today());
        String tomorrow = String.valueOf(System.today().addDays(1));

        Test.startTest();
            List<Order__c> orders = ManagerDashboardController.getFilteredOrders(
                today, tomorrow, null, null
            );
        Test.stopTest();

        System.assertEquals(2, orders.size(), 'Both completed orders should be in today-tomorrow range');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 12: getFilteredOrders — waiterName = 'All' treated as no filter
    // TYPE: Boundary Testing (special case handling)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetFilteredOrders_waiterAll_returnsAll() {
        Test.startTest();
            List<Order__c> orders = ManagerDashboardController.getFilteredOrders(
                null, null, 'All', null
            );
        Test.stopTest();

        System.assertEquals(2, orders.size(), 'Waiter = All should return all completed orders');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 13: getFilteredOrders — recordLimit is respected
    // TYPE: Happy Path (pagination constraint)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetFilteredOrders_recordLimitRespected() {
        Test.startTest();
            List<Order__c> orders = ManagerDashboardController.getFilteredOrders(
                null, null, null, 1
            );
        Test.stopTest();

        System.assertEquals(1, orders.size(), 'Should return only 1 order when limit is 1');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 14: getFilteredOrders — no match returns empty list
    // TYPE: Boundary Testing (empty result set)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testGetFilteredOrders_noMatch_returnsEmpty() {
        Test.startTest();
            List<Order__c> orders = ManagerDashboardController.getFilteredOrders(
                null, null, 'NonExistentWaiter', null
            );
        Test.stopTest();

        System.assertEquals(0, orders.size(), 'Should return empty list for non-existent waiter');
    }
}