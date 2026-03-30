import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getFoodItems    from '@salesforce/apex/FoodOrderController.getFoodItems';
import createOrder     from '@salesforce/apex/FoodOrderController.createOrder';
import getActiveOrders from '@salesforce/apex/FoodOrderController.getActiveOrders';
import addItemsToOrder from '@salesforce/apex/FoodOrderController.addItemsToOrder';
import userId          from '@salesforce/user/Id';
import NAME_FIELD      from '@salesforce/schema/User.Name';

export default class FoodOrderScreen extends LightningElement {

    // ── State ──────────────────────────────
    @track _items          = [];
    @track _qty            = {};
    @track _totalQty       = 0;
    @track _cat            = 'All';
    @track showModal       = false;
    @track showEditPopup   = false;
    @track isLoading       = false;
    @track activeOrders    = [];
    @track selectedEditOrder = null;

    // Modal fields
    @track waiterName     = '';
    @track tableNumber    = '';
    @track modalOrderName = '';
    @track modalDateTime  = '';

    // ── Get Logged In User Name ────────────
    @wire(getRecord, { recordId: userId, fields: [NAME_FIELD] })
    currentUser;

    get loggedInUserName() {
        return getFieldValue(this.currentUser.data, NAME_FIELD) || '';
    }

    // ── Edit Mode ──────────────────────────
    get isEditMode()      { return this.selectedEditOrder !== null; }
    get placeOrderLabel() { return this.isEditMode ? 'Update Order' : ' Place Order'; }
    get orderPanelTitle() { return this.isEditMode ? `Editing: ${this.selectedEditOrder.Name}` : 'Order Summary'; }
    get orderPanelSub()   { return this.isEditMode ? `Table ${this.selectedEditOrder.Table_Number__c} · Add new items below` : 'Current Selection'; }

    // ── Discount Check (9am - 3:20pm NPT) ──
    get isMealDiscountTime() {
        const now     = new Date();
        const nowMins = now.getHours() * 60 + now.getMinutes();
        return nowMins >= 540 && nowMins < 960;
    }

    // ── Wire Food Items ────────────────────
    @wire(getFoodItems)
    wired({ data, error }) {
        if (data) {
            this._items = data;
            const q = {};
            data.forEach(i => { q[i.Id] = 0; });
            this._qty = q;
        } else if (error) {
            this._toast('Error', 'Could not load menu items', 'error');
        }
    }

    // ── Open Edit Popup ────────────────────
    onOpenEditPopup() {
        this.isLoading = true;
        getActiveOrders()
            .then(data => {
                this.activeOrders = data.map(o => ({
                    ...o,
                    statusCls : this._statusCls(o.Status__c)
                }));
                this.showEditPopup = true;
            })
            .catch(err => {
                const msg = (err && err.body) ? err.body.message : 'Failed to load orders';
                this._toast('Error', msg, 'error');
            })
            .finally(() => { this.isLoading = false; });
    }

    onCloseEditPopup() { this.showEditPopup = false; }

    get hasActiveOrders() { return this.activeOrders.length > 0; }

    // ── Select Order from Popup ────────────
    onSelectEditOrder(e) {
        const id = e.currentTarget.dataset.id;
        this.selectedEditOrder = this.activeOrders.find(o => o.Id === id);
        this.showEditPopup = false;
        this.onClear();
    }

    onCancelEdit() {
        this.selectedEditOrder = null;
        this.onClear();
    }

    _statusCls(status) {
        if (status === 'New')         return 'sf-status sf-status-new';
        if (status === 'In Progress') return 'sf-status sf-status-progress';
        if (status === 'Served')      return 'sf-status sf-status-served';
        return 'sf-status';
    }

    // ── Categories ─────────────────────────
    get categories() {
        const raw    = this._items.map(i => i.Category__c).filter(Boolean);
        const unique = ['All', ...new Set(raw)];
        return unique.map(n => ({
            name : n,
            cls  : n === this._cat ? 'sf-cat sf-cat-on' : 'sf-cat'
        }));
    }

    onCat(e) { this._cat = e.currentTarget.dataset.cat; }

    // ── Visible Items ──────────────────────
    get visibleItems() {
        const src = this._cat === 'All'
            ? this._items
            : this._items.filter(i => i.Category__c === this._cat);

        const showDiscount = this.isMealDiscountTime;

        return src.map(i => {
            const q           = this._qty[i.Id] || 0;
            const avl         = i.Available__c;
            const isMeal      = i.Category__c === 'Meal';
            const hasDiscount = isMeal && showDiscount;
            const discountedPrice = hasDiscount ? (i.Price__c * 0.85).toFixed(2) : null;

            return {
                ...i,
                qty           : q,
                available     : avl,
                hasImg        : !!i.Food_Image__c,
                imgHtml       : i.Food_Image__c || '',
                hasDiscount,
                discountedPrice
            };
        });
    }

    get hasItems() { return this.visibleItems.length > 0; }

    // ── Qty Controls ───────────────────────
    onPlus(e) {
        const id = e.detail ? e.detail.id : e.currentTarget.dataset.id;
        const item = this._items.find(i => i.Id === id);
        if (!item || !item.Available__c) return;
        const updated  = Object.assign({}, this._qty);
        updated[id]    = (updated[id] || 0) + 1;
        this._qty      = updated;
        this._totalQty = this._totalQty + 1;
    }

    onMinus(e) {
        const id = e.detail ? e.detail.id : e.currentTarget.dataset.id;
        const cur = this._qty[id] || 0;
        if (cur === 0) return;
        const updated  = Object.assign({}, this._qty);
        updated[id]    = cur - 1;
        this._qty      = updated;
        this._totalQty = this._totalQty - 1;
    }

    // ── Order Summary ──────────────────────
    get orderLines() {
        const showDiscount = this.isMealDiscountTime;
        return this._items
            .filter(i => (this._qty[i.Id] || 0) > 0)
            .map(i => {
                const isMeal      = i.Category__c === 'Meal';
                const hasDiscount = isMeal && showDiscount;
                const qty         = this._qty[i.Id];
                const unitPrice   = hasDiscount ? i.Price__c * 0.85 : i.Price__c;
                const originalAmt = (i.Price__c * qty).toFixed(2);
                return {
                    ...i,
                    qty,
                    hasDiscount,
                    originalAmt,
                    amt : (unitPrice * qty).toFixed(2)
                };
            });
    }

    get hasOrder()  { return this._totalQty > 0; }
    get noOrder()   { return this._totalQty === 0; }
    get totalQty()  { return this._totalQty; }

    get subtotal() {
        return this.orderLines.reduce((s, l) => s + parseFloat(l.amt), 0).toFixed(2);
    }

    get grandTotal()   { return this.subtotal; }

    get totalSavings() {
        return this.orderLines
            .filter(l => l.hasDiscount)
            .reduce((s, l) => s + (parseFloat(l.originalAmt) - parseFloat(l.amt)), 0)
            .toFixed(2);
    }

    get hasSavings() { return parseFloat(this.totalSavings) > 0; }

    // ── Place Order (New or Edit) ──────────
    onPlaceOrder() {
        if (!this.hasOrder) return;
        if (this.isEditMode) {
            this.isLoading = true;
            const lines = this.orderLines.map(l => ({
                foodItemId : l.Id,
                quantity   : l.qty
            }));
            addItemsToOrder({
                orderId    : this.selectedEditOrder.Id,
                orderLines : JSON.stringify(lines)
            })
            .then(() => {
                this._toast('Success!', 'Items added to order successfully!', 'success');
                this.selectedEditOrder = null;
                this.onClear();
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Something went wrong';
                this._toast('Error', msg, 'error');
            })
            .finally(() => { this.isLoading = false; });
        } else {
            const now = new Date();
            const pad = n => String(n).padStart(2, '0');
            this.modalDateTime  = now.toLocaleString('en-GB', {
                day: '2-digit', month: 'short', year: 'numeric',
                hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false
            });
            const datePart      = `${now.getFullYear()}${pad(now.getMonth()+1)}${pad(now.getDate())}`;
            const timePart      = `${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
            this.modalOrderName = `ORD-${datePart}-${timePart}`;
            // Auto fill waiter name from logged in user
            this.waiterName     = this.loggedInUserName;
            this.tableNumber    = '';
            this.showModal      = true;
        }
    }

    // ── Modal Handlers ─────────────────────
    onCloseModal()   { this.showModal = false; }
    onOverlayClick() { this.showModal = false; }
    onModalClick(e)  { e.stopPropagation(); }
    onTable(e)       { this.tableNumber = e.target.value; }

    // ── Confirm & Save New Order ───────────
    onConfirm() {
        if (!this.waiterName.trim()) {
            this._toast('Required', 'Please enter Waiter Name', 'error');
            return;
        }
        if (!this.tableNumber) {
            this._toast('Required', 'Please enter Table Number', 'error');
            return;
        }
        this.isLoading = true;
        const lines = this.orderLines.map(l => ({
            foodItemId : l.Id,
            quantity   : l.qty
        }));
        createOrder({
            orderName   : this.modalOrderName,
            waiterName  : this.waiterName.trim(),
            tableNumber : parseInt(this.tableNumber, 10),
            orderLines  : JSON.stringify(lines)
        })
        .then(() => {
            this._toast('Success!', `Order ${this.modalOrderName} placed successfully!`, 'success');
            this.showModal = false;
            this.onClear();
        })
        .catch(err => {
            const msg = (err && err.body && err.body.message) ? err.body.message : 'Something went wrong';
            this._toast('Error', msg, 'error');
        })
        .finally(() => { this.isLoading = false; });
    }

    // ── Clear ──────────────────────────────
    onClear() {
        const q = {};
        this._items.forEach(i => { q[i.Id] = 0; });
        this._qty      = q;
        this._totalQty = 0;
    }

    // ── Toast ──────────────────────────────
    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}