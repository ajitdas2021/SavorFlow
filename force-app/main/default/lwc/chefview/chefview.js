import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveOrders   from '@salesforce/apex/ChefViewController.getActiveOrders';
import updateOrderStatus from '@salesforce/apex/ChefViewController.updateOrderStatus';

export default class ChefView extends LightningElement {

    @track orders    = [];
    @track isLoading = false;

    connectedCallback() {
        this.loadOrders();
    }

    loadOrders() {
        this.isLoading = true;
        getActiveOrders()
            .then(data => {
                this.orders = data.map(o => {
                    const rawItems = (o.Order_Items__r && o.Order_Items__r.records)
                        ? o.Order_Items__r.records
                        : (o.Order_Items__r ? o.Order_Items__r : []);

                    const newItems   = rawItems.filter(i => i.Is_New_Item__c === true);
                    const oldItems   = rawItems.filter(i => i.Is_New_Item__c === false);
                    const hasNewItems = newItems.length > 0;
                    const hasOldItems = oldItems.length > 0;

                    return {
                        ...o,
                        formattedTime : this._formatTime(o.Order_Date_Time__c),
                        newItems,
                        oldItems,
                        hasNewItems,
                        hasOldItems
                    };
                });
            })
            .catch(err => {
                const msg = (err && err.body) ? err.body.message : 'Failed to load orders';
                this._toast('Error', msg, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // New column — orders with status New
    
    get newOrders() {
    return this.orders
        .filter(o => o.Status__c === 'New')
        .map(o => ({
            ...o,
            
            //    Smart Logic to show new items in new if Previous_Status__c = 'In Progress'
           
            orderItems : (o.Previous_Status__c === 'In Progress' || o.Previous_Status__c === 'Served')
            ? o.newItems
            : [...o.newItems, ...o.oldItems]
        }));
}

    // In Progress column:
    // 1. Normal In Progress (Previous_Status__c != 'Served') — show all items
    // 2. Edited from Served (Previous_Status__c = 'Served') — show only new items
    // 3. Edited from In Progress (Status New, Previous = In Progress) — show old items
    get inProgressOrders() {
        const result = [];

        this.orders.forEach(o => {
            if (o.Status__c === 'In Progress') {
                // Edited from Served — show only new items (old ones already served)
                // Otherwise — show all items
                const itemsToShow = o.Previous_Status__c === 'Served'
                    ? o.newItems
                    : [...o.newItems, ...o.oldItems];
                result.push({ ...o, orderItems: itemsToShow });

            } else if (o.Status__c === 'New' &&
                       o.Previous_Status__c === 'In Progress' &&
                       o.hasOldItems) {
                // Edited order that was In Progress — show old items still cooking
                result.push({ ...o, orderItems: o.oldItems });
            }
            // Edited from Served — old items NOT shown in progress
        });

        return result;
    }

    get hasNewOrders()        { return this.newOrders.length > 0; }
    get hasInProgressOrders() { return this.inProgressOrders.length > 0; }
    get newCount()            { return this.newOrders.length; }
    get inProgressCount()     { return this.inProgressOrders.length; }

    markInProgress(e) {
        this._updateStatus(e.currentTarget.dataset.id, 'In Progress');
    }

    markReady(e) {
        this._updateStatus(e.currentTarget.dataset.id, 'Served');
    }

    _updateStatus(orderId, status) {
        this.isLoading = true;
        updateOrderStatus({ orderId, status })
            .then(() => {
                this._toast('Updated!', `Order marked as ${status}`, 'success');
                this.loadOrders();
            })
            .catch(err => {
                const msg = (err && err.body) ? err.body.message : 'Update failed';
                this._toast('Error', msg, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    _formatTime(dtStr) {
        if (!dtStr) return '';
        return new Date(dtStr).toLocaleString('en-GB', {
            day   : '2-digit',
            month : 'short',
            hour  : '2-digit',
            minute: '2-digit',
            hour12: false
        });
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}