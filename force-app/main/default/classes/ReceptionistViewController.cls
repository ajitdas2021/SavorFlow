public with sharing class ReceptionistViewController {

    @AuraEnabled
    public static List<Order__c> getServedOrders() {
        return [
            SELECT  Id,
                    Name,
                    Table_Number__c,
                    Waiter_Name__c,
                    Status__c,
                    Order_Date_Time__c,
                    Total_Amount__c,
                    (
                        SELECT  Id,
                                Quantity__c,
                                Total_Price__c,
                                Discount_Amount__c,
                                Food_Item__r.Name,
                                Food_Item__r.Price__c,
                                Food_Item__r.Category__c
                        FROM    Order_Items__r
                        ORDER BY Food_Item__r.Name ASC
                    )
            FROM    Order__c
            WHERE   Status__c = 'Served'
            ORDER BY Order_Date_Time__c DESC
        ];
    }

    @AuraEnabled
    public static void markOrderCompleted(Id orderId) {
        Order__c order  = new Order__c();
        order.Id        = orderId;
        order.Status__c = 'Completed';
        update order;
    }
}