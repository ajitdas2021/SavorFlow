trigger StockTrigger on Order_Item__c (after insert) {
    StockTriggerHandler.handleAfterInsert(Trigger.new);
}