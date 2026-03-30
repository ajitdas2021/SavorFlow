public with sharing class ManagerDashboardController {

    @AuraEnabled
    public static Map<String, Object> getDashboardStats() {
        Map<String, Object> stats = new Map<String, Object>();

        // Total Active Orders (New + In Progress)
        Integer activeOrders = [
            SELECT COUNT()
            FROM   Order__c
            WHERE  Status__c IN ('New', 'In Progress')
        ];
        stats.put('activeOrders', activeOrders);

        // Total Tables In Use
        List<AggregateResult> tables = [
            SELECT COUNT_DISTINCT(Table_Number__c) totalTables
            FROM   Order__c
            WHERE  Status__c IN ('New', 'In Progress')
        ];
        stats.put('tablesInUse', tables[0].get('totalTables'));

        // Total Sales Today
        AggregateResult todaySales = [
            SELECT SUM(Total_Amount__c) total
            FROM   Order__c
            WHERE  Status__c = 'Completed'
            AND    Order_Date__c = TODAY
        ];
        stats.put('salesToday', todaySales.get('total') != null ? todaySales.get('total') : 0);

        // Total Sales This Month
        AggregateResult monthSales = [
            SELECT SUM(Total_Amount__c) total
            FROM   Order__c
            WHERE  Status__c = 'Completed'
            AND    Order_Date__c = THIS_MONTH
        ];
        stats.put('salesThisMonth', monthSales.get('total') != null ? monthSales.get('total') : 0);

        // Orders by Status Today
        List<AggregateResult> byStatus = [
            SELECT Status__c status, COUNT(Id) total
            FROM   Order__c
            WHERE  Order_Date__c = TODAY
            GROUP BY Status__c
        ];
        Map<String, Integer> statusMap = new Map<String, Integer>();
        for (AggregateResult ar : byStatus) {
            statusMap.put((String) ar.get('status'), Integer.valueOf(ar.get('total')));
        }
        stats.put('ordersByStatus', statusMap);

        // Manager Name
        User manager = [SELECT Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        stats.put('managerName', manager.Name);

        // Waiter list for filter
        List<AggregateResult> waiters = [
            SELECT Waiter_Name__c name
            FROM   Order__c
            WHERE  Waiter_Name__c != null
            GROUP BY Waiter_Name__c
            ORDER BY Waiter_Name__c ASC
        ];
        List<String> waiterNames = new List<String>();
        for (AggregateResult ar : waiters) {
            waiterNames.add((String) ar.get('name'));
        }
        stats.put('waiterNames', waiterNames);

        return stats;
    }

    @AuraEnabled
    public static List<Order__c> getFilteredOrders(
        String  fromDate,
        String  toDate,
        String  waiterName,
        Integer recordLimit
    ) {
        String query = 'SELECT Id, Name, Table_Number__c, Waiter_Name__c, ' +
                       'Total_Amount__c, Order_Date_Time__c, Order_Date__c ' +
                       'FROM Order__c ' +
                       'WHERE Status__c = \'Completed\'';

        if (fromDate != null && fromDate != '') {
            query += ' AND Order_Date__c >= ' + fromDate;
        }
        if (toDate != null && toDate != '') {
            query += ' AND Order_Date__c <= ' + toDate;
        }
        if (waiterName != null && waiterName != '' && waiterName != 'All') {
            query += ' AND Waiter_Name__c = \'' + String.escapeSingleQuotes(waiterName) + '\'';
        }

        query += ' ORDER BY Order_Date_Time__c DESC';

        if (recordLimit != null && recordLimit > 0) {
            query += ' LIMIT ' + recordLimit;
        }

        return Database.query(query);
    }
}