import { LightningElement, api } from 'lwc';

export default class OrderSummary extends LightningElement {

    @api orderLines;
    @api subtotal;
    @api grandTotal;
    @api hasOrder;
}