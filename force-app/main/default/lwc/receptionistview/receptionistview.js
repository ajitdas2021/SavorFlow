import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getServedOrders from '@salesforce/apex/ReceptionistViewController.getServedOrders';
import markOrderCompleted from '@salesforce/apex/ReceptionistViewController.markOrderCompleted';

export default class ReceptionistView extends LightningElement {

    @track orders        = [];
    @track billedOrders  = [];
    @track selectedOrder = null;
    @track isLoading     = false;

    connectedCallback() {
        this.loadOrders();
    }

    loadOrders() {
        this.isLoading     = true;
        this.selectedOrder = null;

        getServedOrders()
            .then(data => {
                this.orders = data.map(o => this._buildOrder(o));
            })
            .catch(err => {
                const msg = (err && err.body) ? err.body.message : 'Failed to load orders';
                this._toast('Error', msg, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    _buildOrder(o) {
        const rawItems = (o.Order_Items__r && o.Order_Items__r.records)
            ? o.Order_Items__r.records
            : (o.Order_Items__r ? o.Order_Items__r : []);

        const orderItems = rawItems.map(item => {
            const unitPrice     = (item.Food_Item__r && item.Food_Item__r.Price__c != null)
                                   ? parseFloat(item.Food_Item__r.Price__c) : 0;
            const qty           = parseFloat(item.Quantity__c) || 1;
            const category      = (item.Food_Item__r && item.Food_Item__r.Category__c)
                                   ? item.Food_Item__r.Category__c : '';
            const originalTotal = parseFloat((unitPrice * qty).toFixed(2));

            
                
            
            
                const now      = new Date();
                const nowMins  = now.getHours() * 60 + now.getMinutes();
                const inWindow = (nowMins >= 540 && nowMins < 720);
            const hasDiscount = (category === 'Meal' && inWindow);
            const finalTotal    = hasDiscount
                                   ? parseFloat((originalTotal * 0.85).toFixed(2))
                                   : originalTotal;


            
            // const savedDiscount = parseFloat(item.Discount_Amount__c || 0);
            //     const hasDiscount   = savedDiscount > 0;
            //     const finalTotal    = hasDiscount
            //            ? parseFloat((originalTotal - savedDiscount).toFixed(2))
            //            : originalTotal;
            
            
                return {
                ...item,
                originalTotal : originalTotal.toFixed(2),
                finalTotal    : finalTotal.toFixed(2),
                hasDiscount
            };
        });

        // Total savings
        const totalSavings = orderItems.reduce((sum, item) => {
            return sum + (parseFloat(item.originalTotal) - parseFloat(item.finalTotal));
        }, 0).toFixed(2);

        // grand total
            const grandTotal = orderItems
            .reduce((sum, item) => sum + parseFloat(item.finalTotal), 0)
            .toFixed(2);

        return {
            ...o,
            formattedTime : this._formatTime(o.Order_Date_Time__c),
            orderItems,
            totalSavings,
            hasSavings    : parseFloat(totalSavings) > 0,
            grandTotal,
            cardCls       : 'rc-list-card'
        };
    }

    get hasOrders()       { return this.orders.length > 0; }
    get servedCount()     { return this.orders.length; }
    get hasBilledOrders() { return this.billedOrders.length > 0; }

    onSelectOrder(e) {
        const id = e.currentTarget.dataset.id;
        this.orders = this.orders.map(o => ({
            ...o,
            cardCls: o.Id === id ? 'rc-list-card rc-list-card-sel' : 'rc-list-card'
        }));
        this.selectedOrder = this.orders.find(o => o.Id === id);
    }

    onDone(e) {
        const id = e.currentTarget.dataset.id;
        this.isLoading = true;
        markOrderCompleted({ orderId: id })
            .then(() => {
                const done = this.orders.find(o => o.Id === id);
                if (done) {
                    this.billedOrders = [
                        { ...done, cardCls: 'rc-list-card rc-list-card-billed' },
                        ...this.billedOrders
                    ];
                    this.orders = this.orders.filter(o => o.Id !== id);
                }
                this.selectedOrder = null;
                this._toast('Done!', 'Order marked as completed', 'success');
            })
            .catch(err => {
                const msg = (err && err.body) ? err.body.message : 'Update failed';
                this._toast('Error', msg, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    

onPrint() {
    window.print();
}




    _formatTime(dtStr) {
        if (!dtStr) return '';
        return new Date(dtStr).toLocaleString('en-GB', {
            day: '2-digit', month: 'short', year: 'numeric',
            hour: '2-digit', minute: '2-digit', hour12: false
        });
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}