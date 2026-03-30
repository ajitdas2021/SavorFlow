import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getOrders from '@salesforce/apex/OrderController.getOrders';
import updateOrderStatus from '@salesforce/apex/OrderController.updateOrderStatus';

const COLUMNS = [
    { label: 'Order Name', fieldName: 'Name' },
    { label: 'Customer Name', fieldName: 'Customer_Name__c' },
    { label: 'Status', fieldName: 'Status__c' },
    { label: 'Order Date', fieldName: 'Order_Date__c', type: 'date' },
    { label: 'Delivered Date', fieldName: 'Delivered_Date__c', type: 'date' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Confirm', name: 'confirm' },
                { label: 'Preparing', name: 'preparing' },
                { label: 'Delivered', name: 'delivered' },
                { label: 'Cancel', name: 'cancelled' }
            ]
        }
    }
];

export default class OrderDashboard extends LightningElement {
    @track orders;
    @track error;
    columns = COLUMNS;
    wiredOrdersResult;

    @wire(getOrders)
    wiredOrders(result) {
        this.wiredOrdersResult = result;
        if (result.data) {
            this.orders = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.orders = undefined;
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        let newStatus;
        if (actionName === 'confirm') newStatus = 'Confirmed';
        else if (actionName === 'preparing') newStatus = 'Preparing';
        else if (actionName === 'delivered') newStatus = 'Delivered';
        else if (actionName === 'cancelled') newStatus = 'Cancelled';

        updateOrderStatus({ orderId: row.Id, newStatus: newStatus })
            .then(() => {
                refreshApex(this.wiredOrdersResult);
            })
            .catch(error => {
                console.error(error);
            });
    }
}