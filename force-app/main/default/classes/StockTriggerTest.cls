/**
 * Test Class: StockTrigger
 * =========================
 * Trigger fires on Order_Item__c AFTER INSERT.
 * Logic:
 *  - For Drink food items: reduce Stock_Quantity__c by ordered quantity
 *  - If new stock == 0 → Available__c = false
 *  - If new stock < 20 → send low-stock email to SavorFlow Manager profile user
 *  - Non-Drink items are ignored
 *
 * Covers:
 *  1. Drink ordered → stock reduced correctly
 *  2. Drink ordered → stock hits 0 → Available = false
 *  3. Meal ordered  → stock NOT touched (trigger ignores non-Drinks)
 *  4. Drink ordered → stock drops below 20 → email attempted (no error)
 *  5. Bulk insert   → all drink items updated in one DML
 */
@isTest
private class StockTriggerTest {

    // ─────────────────────────────────────────────────────────────────
    // HELPER — create a drink food item with given stock
    // ─────────────────────────────────────────────────────────────────
    private static Food_Item__c createDrink(String name, Decimal stock) {
        Food_Item__c f = new Food_Item__c(
            Name              = name,
            Price__c          = 40,
            Category__c       = 'Drinks',
            Available__c      = (stock > 0),
            Stock_Quantity__c = stock
        );
        insert f;
        return f;
    }

    private static Food_Item__c createMeal(String name) {
        Food_Item__c f = new Food_Item__c(
            Name              = name,
            Price__c          = 100,
            Category__c       = 'Meal',
            Available__c      = true,
            Stock_Quantity__c = 0  // meals don't track stock via this trigger
        );
        insert f;
        return f;
    }

    private static Order__c createOrder() {
        Order__c o = new Order__c(
            Name               = 'STOCK-TEST-ORD',
            Waiter_Name__c     = 'Stock Waiter',
            Table_Number__c    = 6,
            Status__c          = 'New',
            Order_Date_Time__c = System.now(),
            Order_Date__c      = System.today(),
            Total_Amount__c    = 0
        );
        insert o;
        return o;
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 1: Ordering a drink reduces Stock_Quantity__c correctly
    // TYPE: Happy Path (normal stock reduction)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testDrinkOrdered_stockReducedCorrectly() {
        Food_Item__c drink = createDrink('Stock Juice', 30);
        Order__c order     = createOrder();

        Test.startTest();
            Order_Item__c oi = new Order_Item__c(
                Order__c       = order.Id,
                Food_Item__c   = drink.Id,
                Quantity__c    = 5,
                Total_Price__c = 200,
                Is_New_Item__c = false
            );
            insert oi;
        Test.stopTest();

        Food_Item__c updated = [SELECT Stock_Quantity__c, Available__c FROM Food_Item__c WHERE Id = :drink.Id];
        System.assertEquals(25, updated.Stock_Quantity__c, 'Stock should be reduced from 30 to 25');
        System.assertEquals(true, updated.Available__c, 'Available should remain true when stock > 0');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 2: Ordering full stock → Stock hits 0 → Available = false
    // TYPE: Boundary Testing (zero boundary)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testDrinkOrdered_stockHitsZero_availableFalse() {
        Food_Item__c drink = createDrink('Empty Drink', 5);
        Order__c order     = createOrder();

        Test.startTest();
            Order_Item__c oi = new Order_Item__c(
                Order__c       = order.Id,
                Food_Item__c   = drink.Id,
                Quantity__c    = 5,   // exactly clears the stock
                Total_Price__c = 200,
                Is_New_Item__c = false
            );
            insert oi;
        Test.stopTest();

        Food_Item__c updated = [SELECT Stock_Quantity__c, Available__c FROM Food_Item__c WHERE Id = :drink.Id];
        System.assertEquals(0, updated.Stock_Quantity__c, 'Stock should be 0');
        System.assertEquals(false, updated.Available__c, 'Available should be false when stock is 0');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 3: Stock never goes below 0 (order qty > stock)
    // TYPE: Boundary Testing (floor at zero)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testDrinkOrdered_stockCannotGoBelowZero() {
        Food_Item__c drink = createDrink('Tiny Stock Drink', 3);
        Order__c order     = createOrder();

        Test.startTest();
            Order_Item__c oi = new Order_Item__c(
                Order__c       = order.Id,
                Food_Item__c   = drink.Id,
                Quantity__c    = 10,  // more than stock
                Total_Price__c = 400,
                Is_New_Item__c = false
            );
            insert oi;
        Test.stopTest();

        Food_Item__c updated = [SELECT Stock_Quantity__c FROM Food_Item__c WHERE Id = :drink.Id];
        System.assertEquals(0, updated.Stock_Quantity__c, 'Stock should floor at 0, not go negative');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 4: Meal item ordered → trigger ignores it (stock untouched)
    // TYPE: Edge Case (non-drink items excluded)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testMealOrdered_stockNotTouched() {
        Food_Item__c meal = createMeal('Test Pasta');
        Order__c order    = createOrder();

        Test.startTest();
            Order_Item__c oi = new Order_Item__c(
                Order__c       = order.Id,
                Food_Item__c   = meal.Id,
                Quantity__c    = 3,
                Total_Price__c = 300,
                Is_New_Item__c = false
            );
            insert oi;
        Test.stopTest();

        Food_Item__c updated = [SELECT Stock_Quantity__c FROM Food_Item__c WHERE Id = :meal.Id];
        System.assertEquals(0, updated.Stock_Quantity__c, 'Meal stock should not be modified by StockTrigger');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 5: Low-stock scenario (< 20 remaining) — no exception thrown
    // TYPE: Edge Case (low-stock alert handling)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testDrinkOrdered_lowStockAlert_noException() {
        Food_Item__c drink = createDrink('Low Stock Cola', 22);
        Order__c order     = createOrder();

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            Order_Item__c oi = new Order_Item__c(
                Order__c       = order.Id,
                Food_Item__c   = drink.Id,
                Quantity__c    = 5,  // 22 - 5 = 17, which is < 20 → low stock
                Total_Price__c = 200,
                Is_New_Item__c = false
            );
            insert oi;
        } catch (Exception e) {
            exceptionThrown = true;
            System.debug('Unexpected exception: ' + e.getMessage());
        }
        Test.stopTest();

        System.assertEquals(false, exceptionThrown, 'Trigger should not throw an exception for low-stock alert');

        Food_Item__c updated = [SELECT Stock_Quantity__c FROM Food_Item__c WHERE Id = :drink.Id];
        System.assertEquals(17, updated.Stock_Quantity__c, 'Stock should be 17 after ordering 5 from 22');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 6: Bulk insert — multiple drink items updated in one go
    // TYPE: Happy Path (bulk operation)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testBulkInsert_multipleDrinkItemsUpdated() {
        Food_Item__c drinkA = createDrink('Bulk Drink A', 50);
        Food_Item__c drinkB = createDrink('Bulk Drink B', 40);
        Order__c order      = createOrder();

        Test.startTest();
            List<Order_Item__c> items = new List<Order_Item__c>{
                new Order_Item__c(
                    Order__c = order.Id, Food_Item__c = drinkA.Id,
                    Quantity__c = 10, Total_Price__c = 400, Is_New_Item__c = false
                ),
                new Order_Item__c(
                    Order__c = order.Id, Food_Item__c = drinkB.Id,
                    Quantity__c = 8, Total_Price__c = 320, Is_New_Item__c = false
                )
            };
            insert items;
        Test.stopTest();

        Food_Item__c updatedA = [SELECT Stock_Quantity__c FROM Food_Item__c WHERE Id = :drinkA.Id];
        Food_Item__c updatedB = [SELECT Stock_Quantity__c FROM Food_Item__c WHERE Id = :drinkB.Id];

        System.assertEquals(40, updatedA.Stock_Quantity__c, 'Drink A stock: 50 - 10 = 40');
        System.assertEquals(32, updatedB.Stock_Quantity__c, 'Drink B stock: 40 - 8 = 32');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 7: Single unit order reducing stock
    // TYPE: Happy Path (single unit reduction)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testDrinkOrdered_singleUnitReduction() {
        Food_Item__c drink = createDrink('Single Unit Drink', 50);
        Order__c order     = createOrder();

        Test.startTest();
            Order_Item__c oi = new Order_Item__c(
                Order__c       = order.Id,
                Food_Item__c   = drink.Id,
                Quantity__c    = 1,
                Total_Price__c = 40,
                Is_New_Item__c = false
            );
            insert oi;
        Test.stopTest();

        Food_Item__c updated = [SELECT Stock_Quantity__c, Available__c FROM Food_Item__c WHERE Id = :drink.Id];
        System.assertEquals(49, updated.Stock_Quantity__c, 'Stock should reduce from 50 to 49');
        System.assertEquals(true, updated.Available__c, 'Should still be available with 49 units');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 8: Order with large quantity reducing stock across trigger
    // TYPE: Happy Path (large quantity order)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testDrinkOrdered_largeQuantity() {
        Food_Item__c drink = createDrink('Large Order Drink', 100);
        Order__c order     = createOrder();

        Test.startTest();
            Order_Item__c oi = new Order_Item__c(
                Order__c       = order.Id,
                Food_Item__c   = drink.Id,
                Quantity__c    = 75,
                Total_Price__c = 3000,
                Is_New_Item__c = false
            );
            insert oi;
        Test.stopTest();

        Food_Item__c updated = [SELECT Stock_Quantity__c, Available__c FROM Food_Item__c WHERE Id = :drink.Id];
        System.assertEquals(25, updated.Stock_Quantity__c, 'Stock should be 25 after ordering 75 from 100');
        System.assertEquals(true, updated.Available__c, 'Should be available with 25 remaining');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 9: Multiple meals ordered (trigger should ignore)
    // TYPE: Edge Case (multiple non-drinks excluded)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testMultipleMealsOrdered_stockUnchanged() {
        Food_Item__c meal1 = createMeal('Meal 1');
        Food_Item__c meal2 = createMeal('Meal 2');
        Order__c order     = createOrder();

        Test.startTest();
            List<Order_Item__c> items = new List<Order_Item__c>{
                new Order_Item__c(
                    Order__c = order.Id, Food_Item__c = meal1.Id,
                    Quantity__c = 5, Total_Price__c = 500, Is_New_Item__c = false
                ),
                new Order_Item__c(
                    Order__c = order.Id, Food_Item__c = meal2.Id,
                    Quantity__c = 3, Total_Price__c = 300, Is_New_Item__c = false
                )
            };
            insert items;
        Test.stopTest();

        Food_Item__c updated1 = [SELECT Stock_Quantity__c FROM Food_Item__c WHERE Id = :meal1.Id];
        Food_Item__c updated2 = [SELECT Stock_Quantity__c FROM Food_Item__c WHERE Id = :meal2.Id];

        System.assertEquals(0, updated1.Stock_Quantity__c, 'Meal 1 stock should remain 0');
        System.assertEquals(0, updated2.Stock_Quantity__c, 'Meal 2 stock should remain 0');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 10: Mixed drinks and meals in single order
    // TYPE: Happy Path (selective filtering)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testMixedDrinksAndMeals_onlyDrinkAffected() {
        Food_Item__c drink = createDrink('Mixed Drink', 30);
        Food_Item__c meal  = createMeal('Mixed Meal');
        Order__c order     = createOrder();

        Test.startTest();
            List<Order_Item__c> items = new List<Order_Item__c>{
                new Order_Item__c(
                    Order__c = order.Id, Food_Item__c = drink.Id,
                    Quantity__c = 10, Total_Price__c = 400, Is_New_Item__c = false
                ),
                new Order_Item__c(
                    Order__c = order.Id, Food_Item__c = meal.Id,
                    Quantity__c = 5, Total_Price__c = 500, Is_New_Item__c = false
                )
            };
            insert items;
        Test.stopTest();

        Food_Item__c updatedDrink = [SELECT Stock_Quantity__c FROM Food_Item__c WHERE Id = :drink.Id];
        Food_Item__c updatedMeal  = [SELECT Stock_Quantity__c FROM Food_Item__c WHERE Id = :meal.Id];

        System.assertEquals(20, updatedDrink.Stock_Quantity__c, 'Drink stock should reduce: 30 - 10 = 20');
        System.assertEquals(0, updatedMeal.Stock_Quantity__c, 'Meal stock should remain unchanged at 0');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 11: Drink stock exactly at boundary transitions
    // TYPE: Boundary Testing (boundary value transitions)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testDrinkStock_boundaryTransitions() {
        Food_Item__c drink = createDrink('Boundary Drink', 20);
        Order__c order     = createOrder();

        Test.startTest();
            Order_Item__c oi = new Order_Item__c(
                Order__c       = order.Id,
                Food_Item__c   = drink.Id,
                Quantity__c    = 1,  // 20 - 1 = 19, which is < 20
                Total_Price__c = 40,
                Is_New_Item__c = false
            );
            insert oi;
        Test.stopTest();

        Food_Item__c updated = [SELECT Stock_Quantity__c, Available__c FROM Food_Item__c WHERE Id = :drink.Id];
        System.assertEquals(19, updated.Stock_Quantity__c, 'Stock should be 19');
        // Low-stock alert would be triggered (< 20), but no exception
        System.assertEquals(true, updated.Available__c, 'Still available even when below 20');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 12: Multiple order items for same drink in different orders
    // TYPE: Happy Path (multi-order scenario)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testSameDrinkMultipleOrders() {
        Food_Item__c drink = createDrink('Popular Drink', 60);
        Order__c order1    = createOrder();
        Order__c order2    = new Order__c(
            Name               = 'STOCK-TEST-ORD-2',
            Waiter_Name__c     = 'Second Waiter',
            Table_Number__c    = 7,
            Status__c          = 'New',
            Order_Date_Time__c = System.now(),
            Order_Date__c      = System.today(),
            Total_Amount__c    = 0
        );
        insert order2;

        Test.startTest();
            Order_Item__c oi1 = new Order_Item__c(
                Order__c = order1.Id, Food_Item__c = drink.Id,
                Quantity__c = 20, Total_Price__c = 800, Is_New_Item__c = false
            );
            Order_Item__c oi2 = new Order_Item__c(
                Order__c = order2.Id, Food_Item__c = drink.Id,
                Quantity__c = 30, Total_Price__c = 1200, Is_New_Item__c = false
            );
            insert new List<Order_Item__c>{ oi1, oi2 };
        Test.stopTest();

        Food_Item__c updated = [SELECT Stock_Quantity__c, Available__c FROM Food_Item__c WHERE Id = :drink.Id];
        System.assertEquals(10, updated.Stock_Quantity__c, 'Stock should be 10 after both orders: 60 - 20 - 30');
        System.assertEquals(true, updated.Available__c, 'Should still be available');
    }
}