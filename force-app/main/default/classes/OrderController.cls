
public with sharing class OrderController {
    
    @AuraEnabled(cacheable=true)
    public static List<Order__c> getOrders() {
        return [
            SELECT Id, 
                   Name,
                   Customer_Name__c,
                   Status__c,
                   Order_Date__c,
                   Delivered_Date__c
            FROM Order__c
            ORDER BY Order_Date__c DESC
        ];
    }
    
    @AuraEnabled
    public static void updateOrderStatus(Id orderId, String newStatus) {
        Order__c order = new Order__c();
        order.Id = orderId;
        order.Status__c = newStatus;
        update order;
    }
}
