import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDashboardStats  from '@salesforce/apex/ManagerDashboardController.getDashboardStats';
import getFilteredOrders  from '@salesforce/apex/ManagerDashboardController.getFilteredOrders';

export default class ManagerDashboard extends LightningElement {

    @track stats        = null;
    @track recentOrders = [];
    @track isLoading    = false;

    // Filter state
    @track fromDate    = '';
    @track toDate      = '';
    @track waiterName  = 'All';
    @track recordLimit = 5;

    connectedCallback() {
        this.loadStats();
        this.loadOrders();
    }

    loadStats() {
        this.isLoading = true;
        getDashboardStats()
            .then(data => { this.stats = data; })
            .catch(err => {
                const msg = (err && err.body) ? err.body.message : 'Failed to load dashboard';
                this._toast('Error', msg, 'error');
            })
            .finally(() => { this.isLoading = false; });
    }

    loadOrders() {
        this.isLoading = true;
        getFilteredOrders({
            fromDate    : this.fromDate    || null,
            toDate      : this.toDate      || null,
            waiterName  : this.waiterName  || 'All',
            recordLimit : this.recordLimit
        })
        .then(data => {
            this.recentOrders = data.map((o, index) => ({
                ...o,
                rowNum        : index + 1,
                formattedDate : this._formatDate(o.Order_Date_Time__c),
                formattedTime : this._formatTime(o.Order_Date_Time__c)
            }));
        })
        .catch(err => {
            const msg = (err && err.body) ? err.body.message : 'Failed to load orders';
            this._toast('Error', msg, 'error');
        })
        .finally(() => { this.isLoading = false; });
    }

    // ── Filter Handlers ────────────────────
    onFromDate(e)     { this.fromDate   = e.target.value; }
    onToDate(e)       { this.toDate     = e.target.value; }
    onWaiterFilter(e) { this.waiterName = e.target.value; }
    onLimitChange(e)  { this.recordLimit = parseInt(e.target.value, 10); }

    applyFilters() { this.loadOrders(); }

    resetFilters() {
        this.fromDate    = '';
        this.toDate      = '';
        this.waiterName  = 'All';
        this.recordLimit = 5;
        this.loadOrders();
    }

    // // ── Export CSV ─────────────────────────
    // exportCSV() {
    //     if (!this.recentOrders.length) {
    //         this._toast('No Data', 'No orders to export', 'warning');
    //         return;
    //     }

    //     const headers = ['#', 'Order Name', 'Table', 'Waiter', 'Gross Amount', 'Date', 'Time'];
    //     const rows    = this.recentOrders.map(o => [
    //         o.rowNum,
    //         o.Name,
    //         'Table ' + o.Table_Number__c,
    //         o.Waiter_Name__c,
    //         'Rs.' + o.Total_Amount__c,
    //         o.formattedDate,
    //         o.formattedTime
    //     ]);

    //     const csvContent = [headers, ...rows]
    //         .map(row => row.map(val => `"${val}"`).join(','))
    //         .join('\n');

    //     const blob = new Blob([csvContent], { type: 'text/csv' });
    //     const url  = URL.createObjectURL(blob);
    //     const a    = document.createElement('a');
    //     a.href     = url;
    //     a.download = `SavorFlow_Orders_${new Date().toISOString().slice(0,10)}.csv`;
    //     a.click();
    //     URL.revokeObjectURL(url);
    //     this._toast('Success!', 'CSV exported successfully', 'success');
    // }


    // // ── Export PDF ─────────────────────────
    // exportPDF() {
    //     if (!this.recentOrders.length) {
    //         this._toast('No Data', 'No orders to export', 'warning');
    //         return;
    //     }

    //     const rows = this.recentOrders.map(o => `
    //         <tr>
    //             <td>${o.rowNum}</td>
    //             <td>${o.Name}</td>
    //             <td>Table ${o.Table_Number__c}</td>
    //             <td>${o.Waiter_Name__c}</td>
    //             <td>Rs.${o.Total_Amount__c}</td>
    //             <td>${o.formattedDate}</td>
    //             <td>${o.formattedTime}</td>
    //         </tr>`).join('');

    //     const html = `<!DOCTYPE html>
    //     <html>
    //     <head>
    //         <style>
    //             body { font-family: Arial, sans-serif; padding: 24px; }
    //             h1   { font-size: 24px; font-weight: 800; margin-bottom: 4px; }
    //             .savor { color: #e67e00; } .flow { color: #0176d3; }
    //             .sub { font-size: 13px; color: #6b7280; margin-bottom: 20px; }
    //             table { width: 100%; border-collapse: collapse; font-size: 13px; }
    //             th { background: #f3f4f6; padding: 10px 8px; text-align: left; font-size: 11px; text-transform: uppercase; border-bottom: 2px solid #e5e7eb; }
    //             td { padding: 9px 8px; border-bottom: 1px solid #f3f4f6; }
    //             .amt { font-weight: 700; color: #2e844a; }
    //             .footer { margin-top: 20px; font-size: 12px; color: #6b7280; text-align: center; }
    //         </style>
    //     </head>
    //     <body>
    //         <h1><span class="savor">Savor</span><span class="flow">Flow</span></h1>
    //         <div class="sub">Completed Orders Report — Generated on ${new Date().toLocaleString('en-GB')}</div>
    //         <table>
    //             <thead>
    //                 <tr>
    //                     <th>#</th><th>Order</th><th>Table</th>
    //                     <th>Waiter</th><th>Gross Amount</th><th>Date</th><th>Time</th>
    //                 </tr>
    //             </thead>
    //             <tbody>${rows}</tbody>
    //         </table>
    //         <div class="footer">Total Records: ${this.recentOrders.length}</div>
    //     </body>
    //     </html>`;

    //     const w = window.open('', '_blank', 'width=900,height=700');
    //     w.document.write(html);
    //     w.document.close();
    //     setTimeout(() => { w.focus(); w.print(); }, 500);
    //     this._toast('Success!', 'PDF report opened for printing', 'success');
    // }



    exportPDF() {
    window.print();
    }



    // ── Getters ────────────────────────────
    get todayDate() {
        return new Date().toLocaleDateString('en-GB', {
            weekday: 'long', day: '2-digit', month: 'long', year: 'numeric'
        });
    }

    get newCount()        { return (this.stats && this.stats.ordersByStatus && this.stats.ordersByStatus.New) || 0; }
    get inProgressCount() { return (this.stats && this.stats.ordersByStatus && this.stats.ordersByStatus['In Progress']) || 0; }
    get servedCount()     { return (this.stats && this.stats.ordersByStatus && this.stats.ordersByStatus.Served) || 0; }
    get completedCount()  { return (this.stats && this.stats.ordersByStatus && this.stats.ordersByStatus.Completed) || 0; }
    get cancelledCount()  { return (this.stats && this.stats.ordersByStatus && this.stats.ordersByStatus.Cancelled) || 0; }
    get hasRecentOrders() { return this.recentOrders.length > 0; }

    // ── Helpers ────────────────────────────
    _formatDate(dtStr) {
        if (!dtStr) return '';
        return new Date(dtStr).toLocaleDateString('en-GB', {
            day: '2-digit', month: 'short', year: 'numeric'
        });
    }

    _formatTime(dtStr) {
        if (!dtStr) return '';
        return new Date(dtStr).toLocaleTimeString('en-GB', {
            hour: '2-digit', minute: '2-digit', hour12: false
        });
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}