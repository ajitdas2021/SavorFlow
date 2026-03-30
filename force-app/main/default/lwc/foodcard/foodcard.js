import { LightningElement, api } from 'lwc';

export default class FoodCard extends LightningElement {

    // ── @api Props (passed from parent) ───
    @api itemId;
    @api name;
    @api category;
    @api price;
    @api qty = 0;
    @api available = false;
    @api hasImg = false;
    @api imgHtml = '';
    @api hasDiscount = false;
    @api discountedPrice = null;

    // ── Derived getters ───────────────────
    get isZero() { return this.qty === 0; }
    get notAvail() { return !this.available; }

    get cardCls() {
        if (this.qty > 0) return 'sf-card sf-card-sel';
        if (this.available) return 'sf-card';
        return 'sf-card sf-card-off';
    }

    get badgeCls() { return this.available ? 'sf-badge-avl' : 'sf-badge-off'; }
    get badgeTxt() { return this.available ? 'Available' : 'Unavailable'; }
    get qtyCls() { return this.qty > 0 ? 'sf-qty sf-qty-on' : 'sf-qty'; }

    // ── Render image HTML (lwc:dom="manual") ──
    renderedCallback() {
        if (!this.hasImg || !this.imgHtml) return;
        const el = this.template.querySelector(`[data-imgid="${this.itemId}"]`);
        if (el && el.innerHTML === '') {
            el.innerHTML = this.imgHtml;
        }
    }

    // ── Fire custom events to parent ──────
    handlePlus() {
        this.dispatchEvent(new CustomEvent('plus', {
            detail: { id: this.itemId }
        }));
    }

    handleMinus() {
        this.dispatchEvent(new CustomEvent('minus', {
            detail: { id: this.itemId }
        }));
    }
}