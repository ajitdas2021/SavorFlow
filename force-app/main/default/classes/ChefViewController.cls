public with sharing class ChefViewController {

    @AuraEnabled
    public static List<Order__c> getActiveOrders() {
        return [
            SELECT Id, Name, Table_Number__c, Waiter_Name__c,
                   Status__c, Previous_Status__c, Order_Date_Time__c,
                   (SELECT Id, Quantity__c, Is_New_Item__c,
                           Food_Item__r.Name, Food_Item__r.Category__c
                    FROM   Order_Items__r
                    ORDER BY CreatedDate ASC)
            FROM   Order__c
            WHERE  Status__c IN ('New', 'In Progress')
            ORDER BY Order_Date_Time__c ASC
        ];
    }

    // update order status
    @AuraEnabled
    public static void updateOrderStatus(String orderId, String status) {
        Order__c order = [SELECT Id, Status__c, Previous_Status__c, Waiter_Name__c, Name, Table_Number__c FROM Order__c WHERE Id = :orderId LIMIT 1];
        order.Status__c = status;
        update order;

        // When marking as Served — reset all Is_New_Item__c to false
        // and send notification to waiter
        if (status == 'Served') {

            // Reset new items flag
            List<Order_Item__c> items = [
                SELECT Id, Is_New_Item__c
                FROM   Order_Item__c
                WHERE  Order__c = :orderId
                AND    Is_New_Item__c = true
            ];
            for (Order_Item__c i : items) {
                i.Is_New_Item__c = false;
            }
            if (!items.isEmpty()) update items;

            // Send notification to waiter
            if (order.Waiter_Name__c != null) {
                List<User> waiters = [
                    SELECT Id
                    FROM   User
                    WHERE  Name = :order.Waiter_Name__c
                    AND    IsActive = true
                    LIMIT  1
                ];

                if (!waiters.isEmpty()) {
                    CustomNotificationType notifType = [
                        SELECT Id
                        FROM   CustomNotificationType
                        WHERE  DeveloperName = 'Order_Ready_Notification'
                        LIMIT  1
                    ];

                    Messaging.CustomNotification notification = new Messaging.CustomNotification();
                    notification.setTitle('🍽️ Order Ready!');
                    notification.setBody('Order ' + order.Name + ' for Table ' + order.Table_Number__c + ' is ready for pickup!');
                    notification.setNotificationTypeId(notifType.Id);
                    notification.setTargetId(orderId);
                    notification.send(new Set<String>{ waiters[0].Id });
                }
            }
        }
    }
}