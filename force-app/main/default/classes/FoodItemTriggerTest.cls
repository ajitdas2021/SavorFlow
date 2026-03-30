/**
 * Test Class: FoodItemTrigger
 * ============================
 * Trigger fires on Food_Item__c BEFORE UPDATE.
 * Logic: If Stock_Quantity__c changes →
 *   - stock > 0  → Available__c = true
 *   - stock == 0 → Available__c = false
 *
 * Covers:
 *  1. Stock set to positive → Available becomes true
 *  2. Stock set to zero     → Available becomes false
 *  3. Stock unchanged       → Available not touched by trigger
 */
@isTest
private class FoodItemTriggerTest {

    // ─────────────────────────────────────────────────────────────────
    // TEST 1: Increasing stock from 0 → sets Available__c = true
    // TYPE: Happy Path (normal trigger logic)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testStockIncrease_setsAvailableTrue() {
        // Start as unavailable with zero stock
        Food_Item__c food = new Food_Item__c(
            Name              = 'TriggerTest Item A',
            Price__c          = 50,
            Category__c       = 'Meal',
            Available__c      = false,
            Stock_Quantity__c = 0
        );
        insert food;

        Test.startTest();
            food.Stock_Quantity__c = 15;
            update food;
        Test.stopTest();

        Food_Item__c result = [SELECT Available__c FROM Food_Item__c WHERE Id = :food.Id];
        System.assertEquals(true, result.Available__c, 'Available should be true when stock is increased above 0');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 2: Reducing stock to 0 → sets Available__c = false
    // TYPE: Happy Path (normal status transition)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testStockReducedToZero_setsAvailableFalse() {
        Food_Item__c food = new Food_Item__c(
            Name              = 'TriggerTest Item B',
            Price__c          = 70,
            Category__c       = 'Drinks',
            Available__c      = true,
            Stock_Quantity__c = 10
        );
        insert food;

        Test.startTest();
            food.Stock_Quantity__c = 0;
            update food;
        Test.stopTest();

        Food_Item__c result = [SELECT Available__c FROM Food_Item__c WHERE Id = :food.Id];
        System.assertEquals(false, result.Available__c, 'Available should be false when stock reaches 0');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 3: Stock unchanged → Available__c NOT modified by trigger
    // TYPE: Boundary Testing (no change scenario)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testStockUnchanged_availableNotAffected() {
        Food_Item__c food = new Food_Item__c(
            Name              = 'TriggerTest Item C',
            Price__c          = 40,
            Category__c       = 'Meal',
            Available__c      = false,   // manually set false even with stock
            Stock_Quantity__c = 5
        );
        insert food;

        Test.startTest();
            // Change only the price — stock stays the same
            food.Price__c = 60;
            update food;
        Test.stopTest();

        Food_Item__c result = [SELECT Available__c FROM Food_Item__c WHERE Id = :food.Id];
        // Trigger should NOT fire its logic since stock didn't change
        System.assertEquals(false, result.Available__c, 'Available should remain unchanged when stock is not modified');
    }


    // ─────────────────────────────────────────────────────────────────
    // TEST 4: Bulk update — trigger correctly handles multiple records
    // TYPE: Happy Path (bulk operation)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testBulkUpdate_handlesMultipleRecords() {
        List<Food_Item__c> foods = new List<Food_Item__c>();
        for (Integer i = 0; i < 10; i++) {
            foods.add(new Food_Item__c(
                Name              = 'Bulk Item ' + i,
                Price__c          = 30,
                Category__c       = 'Drinks',
                Available__c      = true,
                Stock_Quantity__c = 20
            ));
        }
        insert foods;

        // Set all stocks to 0
        for (Food_Item__c f : foods) {
            f.Stock_Quantity__c = 0;
        }

        Test.startTest();
            update foods;
        Test.stopTest();

        List<Food_Item__c> results = [SELECT Available__c FROM Food_Item__c WHERE Id IN :foods];
        for (Food_Item__c r : results) {
            System.assertEquals(false, r.Available__c, 'All items with 0 stock should have Available = false');
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 5: Stock transitions from positive to positive → Available stays true
    // TYPE: Boundary Testing (transition between positive values)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testStockPositiveToPositive_availableStaysTrue() {
        Food_Item__c food = new Food_Item__c(
            Name              = 'Transition Item',
            Price__c          = 50,
            Category__c       = 'Meal',
            Available__c      = true,
            Stock_Quantity__c = 10
        );
        insert food;

        Test.startTest();
            food.Stock_Quantity__c = 5;  // still > 0
            update food;
        Test.stopTest();

        Food_Item__c result = [SELECT Available__c FROM Food_Item__c WHERE Id = :food.Id];
        System.assertEquals(true, result.Available__c, 'Available should remain true when stock stays above 0');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 6: Stock increases from zero to large value → Available becomes true
    // TYPE: Happy Path (large value transition)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testStockZeroToLargeValue_setsAvailableTrue() {
        Food_Item__c food = new Food_Item__c(
            Name              = 'Large Stock Item',
            Price__c          = 100,
            Category__c       = 'Drinks',
            Available__c      = false,
            Stock_Quantity__c = 0
        );
        insert food;

        Test.startTest();
            food.Stock_Quantity__c = 1000;
            update food;
        Test.stopTest();

        Food_Item__c result = [SELECT Available__c FROM Food_Item__c WHERE Id = :food.Id];
        System.assertEquals(true, result.Available__c, 'Available should be true with large stock quantity');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 7: Stock decreases from positive but not to zero → Available stays true
    // TYPE: Happy Path (partial decrease)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testStockPartialDecrease_availableStaysTrue() {
        Food_Item__c food = new Food_Item__c(
            Name              = 'Partial Decrease Item',
            Price__c          = 75,
            Category__c       = 'Meal',
            Available__c      = true,
            Stock_Quantity__c = 100
        );
        insert food;

        Test.startTest();
            food.Stock_Quantity__c = 50;  // still > 0
            update food;
        Test.stopTest();

        Food_Item__c result = [SELECT Available__c FROM Food_Item__c WHERE Id = :food.Id];
        System.assertEquals(true, result.Available__c, 'Available should stay true when stock remains > 0');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 8: Multiple fields updated including stock — only stock change triggers logic
    // TYPE: Happy Path (multi-field update, selective logic)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testMultipleFieldUpdate_onlyStockTriggers() {
        Food_Item__c food = new Food_Item__c(
            Name              = 'Multi Field Item',
            Price__c          = 50,
            Category__c       = 'Appetizer',
            Available__c      = true,
            Stock_Quantity__c = 10
        );
        insert food;

        Test.startTest();
            food.Price__c = 75;
            food.Stock_Quantity__c = 0;
            food.Name = 'Updated Name';
            update food;
        Test.stopTest();

        Food_Item__c result = [SELECT Available__c, Price__c, Name FROM Food_Item__c WHERE Id = :food.Id];
        System.assertEquals(false, result.Available__c, 'Available should become false due to stock change');
        System.assertEquals(75, result.Price__c, 'Price should be updated');
        System.assertEquals('Updated Name', result.Name, 'Name should be updated');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 9: Stock set to 1 (minimum positive) → Available becomes true
    // TYPE: Boundary Testing (minimum positive value)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testStockSetToOne_availableTrue() {
        Food_Item__c food = new Food_Item__c(
            Name              = 'Single Unit Item',
            Price__c          = 30,
            Category__c       = 'Drinks',
            Available__c      = false,
            Stock_Quantity__c = 0
        );
        insert food;

        Test.startTest();
            food.Stock_Quantity__c = 1;
            update food;
        Test.stopTest();

        Food_Item__c result = [SELECT Available__c FROM Food_Item__c WHERE Id = :food.Id];
        System.assertEquals(true, result.Available__c, 'Available should be true with stock = 1');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 10: Bulk with mixed transitions — some to 0, some from 0
    // TYPE: Happy Path (bulk with mixed transitions)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testBulkMixedTransitions() {
        List<Food_Item__c> foods = new List<Food_Item__c>();
        for (Integer i = 0; i < 5; i++) {
            foods.add(new Food_Item__c(
                Name              = 'Mix Item ' + i,
                Price__c          = 50,
                Category__c       = 'Meal',
                Available__c      = true,
                Stock_Quantity__c = 10
            ));
        }
        insert foods;

        // Transition: half to 0, half to larger values
        for (Integer i = 0; i < foods.size(); i++) {
            if (Math.mod(i, 2) == 0) {
                foods[i].Stock_Quantity__c = 0;
            } else {
                foods[i].Stock_Quantity__c = 50;
            }
        }

        Test.startTest();
            update foods;
        Test.stopTest();

        List<Food_Item__c> results = [SELECT Available__c FROM Food_Item__c WHERE Id IN :foods ORDER BY Name];
        for (Integer i = 0; i < results.size(); i++) {
            if (Math.mod(i, 2) == 0) {
                System.assertEquals(false, results[i].Available__c, 'Even-indexed items should be unavailable');
            } else {
                System.assertEquals(true, results[i].Available__c, 'Odd-indexed items should be available');
            }
        }
    }
}