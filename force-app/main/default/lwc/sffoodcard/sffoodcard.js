import { LightningElement, api } from 'lwc';

export default class sffoodcardoodCard extends LightningElement {

    // ── Input from parent ──────────────────
    // Full enriched item object — qty, hasDiscount, discountedPrice,
    // cardCls, badgeCls, badgeTxt, qtyCls, isZero, notAvail, hasImg
    @api item;

    // ── Computed getters ───────────────────
    get cardCls()  { return this.item ? this.item.cardCls  : 'sf-card'; }
    get badgeCls() { return this.item ? this.item.badgeCls : ''; }
    get badgeTxt() { return this.item ? this.item.badgeTxt : ''; }
    get qtyCls()   { return this.item ? this.item.qtyCls   : 'sf-qty'; }
    get isZero()   { return this.item ? this.item.isZero   : true; }

    // ── Qty button handlers ────────────────
    // Fire events up to parent instead of mutating state directly
    handlePlus() {
        this.dispatchEvent(
            new CustomEvent('quantitychange', {
                bubbles    : true,
                composed   : true,
                detail     : { itemId: this.item.Id, delta: 1 }
            })
        );
    }

    handleMinus() {
        this.dispatchEvent(
            new CustomEvent('quantitychange', {
                bubbles    : true,
                composed   : true,
                detail     : { itemId: this.item.Id, delta: -1 }
            })
        );
    }

    // ── Image rendering ────────────────────
    // Child owns its own image injection —
    // parent no longer needs renderedCallback for cards
    renderedCallback() {
        if (!this.item || !this.item.hasImg) return;
        const el = this.template.querySelector(`[data-imgid="${this.item.Id}"]`);
        if (el && el.innerHTML === '') {
            el.innerHTML = this.item.Food_Image__c;
        }
    }
}