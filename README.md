# 🍽️ SavorFlow

> *Where Hunger meets the Taste...*

A full-stack **Salesforce** restaurant management application built with **Apex**, **Lightning Web Components (LWC)**, and **Salesforce Flows**. SavorFlow digitizes the entire restaurant order lifecycle — from a waiter placing an order to the chef preparing it, the receptionist billing the customer, and the manager tracking daily sales.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Custom Objects](#custom-objects)
- [User Roles](#user-roles)
- [Order Lifecycle](#order-lifecycle)
- [Business Rules](#business-rules)
- [LWC Components](#lwc-components)
- [Apex Classes](#apex-classes)
- [Triggers](#triggers)
- [Installation](#installation)
- [Deployment](#deployment)

---

## Overview

SavorFlow is a Salesforce-native restaurant POS (Point of Sale) system that manages the full order workflow across four roles — Waiter, Chef, Receptionist, and Manager. Each role has a dedicated Lightning App Page with a custom LWC interface tailored to their specific responsibilities.

---

## Features

### Waiter Portal
- Browse food menu with live availability status
- Filter items by category (Meal, Drinks, etc.)
- Add items to order with quantity controls
- Automatic 15% meal discount between 9:00 AM and 4:00 PM (NPT)
- Edit existing active orders by adding new items
- Stock validation for Drinks before placing order
- Table duplicate validation — prevents placing a new order on a table that already has an active order
- Auto-filled waiter name from logged-in Salesforce user
- Custom notifications sent to all chefs on new or updated orders

### Chef View
- Real-time list of all active orders (New and In Progress)
- New item highlights on updated orders via `Is_New_Item__c` flag
- One-click status update — mark orders In Progress or Served
- Custom push notification sent to the waiter when order is marked Served

### Receptionist Billing View
- List of all Served orders ready for billing
- Itemized bill card with discount breakdown and grand total
- Print bill functionality
- Mark order as Completed to close the table

### Manager Dashboard
- Live stats — active orders, tables in use, sales today, sales this month
- Today's order status breakdown (New, In Progress, Served, Completed, Cancelled)
- Completed orders table with date, waiter, and amount
- Filter by date range, waiter, and record limit
- Export PDF report via browser print

---

## Architecture

```
Waiter (LWC: foodorderscreen)
    → FoodOrderController.cls
        → Order__c (insert)
        → Order_Item__c (insert)
        → StockTrigger → StockTriggerHandler
        → Custom Notification → Chefs

Chef (LWC: chefview)
    → ChefViewController.cls
        → Order__c (status update)
        → Custom Notification → Waiter (on Served)

Receptionist (LWC: receptionistview)
    → ReceptionistViewController.cls
        → Order__c (status → Completed)

Manager (LWC: managerdashboard)
    → ManagerDashboardController.cls
        → Aggregated queries (stats + filtered orders)

Food_Item__c
    → FoodItemTrigger → FoodItemTriggerHandler
        → Syncs Available__c when Stock_Quantity__c changes
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Platform | Salesforce Lightning Platform |
| Backend | Apex (with sharing) |
| Frontend | Lightning Web Components (LWC) |
| Styling | Custom CSS with CSS variables |
| Automation | Salesforce Flows |
| Notifications | Salesforce Custom Notifications (Push) |
| Email Alerts | Apex Messaging API |
| CLI | Salesforce CLI (sf) |
| API Version | 65.0 |

---

## Project Structure

```
force-app/main/default/
├── classes/
│   ├── FoodOrderController.cls
│   ├── ChefViewController.cls
│   ├── ReceptionistViewController.cls
│   ├── ManagerDashboardController.cls
│   ├── FoodItemTriggerHandler.cls
│   └── StockTriggerHandler.cls
├── triggers/
│   ├── FoodItemTrigger.trigger
│   └── StockTrigger.trigger
└── lwc/
    ├── foodorderscreen/        ← Waiter Portal
    ├── foodcard/               ← Child: Food item card
    ├── chefview/               ← Chef View
    ├── receptionistview/       ← Receptionist Billing
    └── managerdashboard/       ← Manager Dashboard
```

---

## Custom Objects

### `Food_Item__c`
| Field | Type | Description |
|---|---|---|
| `Name` | Text | Food item name |
| `Price__c` | Currency | Base price |
| `Category__c` | Picklist | Meal, Drinks |
| `Available__c` | Checkbox | Availability flag |
| `Stock_Quantity__c` | Number | Current stock (Drinks only) |
| `Food_Image__c` | Rich Text | Item image (SVG/HTML) |

### `Order__c`
| Field | Type | Description |
|---|---|---|
| `Name` | Text | Auto-generated order ID |
| `Table_Number__c` | Number | Restaurant table number |
| `Waiter_Name__c` | Text | Name of waiter who placed order |
| `Status__c` | Picklist | New, In Progress, Served, Completed |
| `Previous_Status__c` | Text | Previous status before update |
| `Total_Amount__c` | Currency | Total order value |
| `Order_Date_Time__c` | DateTime | Order placement timestamp |
| `Order_Date__c` | Date | Order date (for reporting) |

### `Order_Item__c`
| Field | Type | Description |
|---|---|---|
| `Order__c` | Lookup | Parent order |
| `Food_Item__c` | Lookup | Food item ordered |
| `Quantity__c` | Number | Quantity ordered |
| `Total_Price__c` | Currency | Line total after discount |
| `Discount_Amount__c` | Currency | Discount applied |
| `Is_New_Item__c` | Checkbox | Flags newly added items for chef |

---

## User Roles

| Role | App Page | Permission Set |
|---|---|---|
| Waiter | SavorFlow Home | `Waiter_Permission` |
| Chef | SavorFlow Chef | `Chef_Permission` |
| Receptionist | SavorFlow Receptionist | `Receptionist_Permission` |
| Manager | SavorFlow Manager | `Manager_Permission`|

---

## Order Lifecycle

```
[Waiter places order] → Status: New
        ↓
[Chef picks up]       → Status: In Progress
        ↓
[Chef marks done]     → Status: Served
        ↓              (Push notification sent to Waiter)
[Receptionist bills]  → Status: Completed
```

**Edit flow:** Waiter can add items to any New, In Progress, or Served order. Adding items resets status back to New and notifies chefs again with new items highlighted.

---

## Business Rules

### Meal Discount
- 15% discount automatically applied to all Meal category items
- Active window: **9:00 AM to 4:00 PM (NPT)**
- Discount calculated and saved in `Discount_Amount__c` at order time
- Shown to waiter on menu cards and order summary

### Stock Management
- Stock tracking applies to **Drinks category only**
- `StockTrigger` deducts stock on every `Order_Item__c` insert
- If remaining stock drops below **20 units**, an email alert is sent to the manager
- Item is automatically marked `Available__c = false` when stock reaches 0
- Stock validation runs before order is placed — waiter sees a friendly error if stock is insufficient

### Table Validation
- A new order cannot be placed on a table that already has a **New**, **In Progress**, or **Served** order
- The table becomes available again only after the receptionist marks the order **Completed**

### Chef Notifications
- All users with `Chef_Permission` permission set receive a push notification when a new order is placed or updated
- Notification links directly to the order record

### Waiter Notifications
- The waiter assigned to an order receives a push notification when the chef marks the order **Served**

---

## LWC Components

### `foodorderscreen` (Parent)
The main Waiter Portal. Manages all order state — selected quantities, discount logic, order summary totals. Communicates with child `foodcard` via `@api` props down and `quantitychange` events up.

### `foodcard` (Child of foodorderscreen)
Renders a single food item card. Receives enriched item data via `@api item`. Fires `quantitychange` CustomEvent with `{ itemId, delta }` when + or − is clicked. Owns its own image rendering via `renderedCallback`.

### `receptionistview`
Receptionist billing interface. Two-panel layout — order list on the left, itemized bill card on the right. Supports print bill and mark as completed.

### `managerdashboard`
Manager analytics dashboard. Stat cards, status breakdown, filterable completed orders table, and PDF export via browser print.

---

## Apex Classes

| Class | Purpose |
|---|---|
| `FoodOrderController` | Waiter operations — fetch menu, create order, add items, table validation |
| `ChefViewController` | Chef operations — fetch active orders, update status, notify waiter |
| `ReceptionistViewController` | Receptionist operations — fetch served orders, mark completed |
| `ManagerDashboardController` | Manager operations — dashboard stats, filtered order history |
| `FoodItemTriggerHandler` | Handler for FoodItemTrigger — syncs availability on stock change |
| `StockTriggerHandler` | Handler for StockTrigger — deducts stock, sends low stock alert |

---

## Triggers

### `FoodItemTrigger` (before update)
Delegates to `FoodItemTriggerHandler`. Automatically syncs `Available__c` to `true` or `false` whenever `Stock_Quantity__c` is manually changed on a Food Item record.

### `StockTrigger` (after insert on Order_Item__c)
Delegates to `StockTriggerHandler`. On every order item insert, deducts the ordered quantity from the corresponding Drinks food item's stock. Sends a low stock email alert to the manager if any item drops below 20 units. Bulk-safe — uses a single SOQL query and single DML update regardless of record volume.

---

## Installation

### Prerequisites
- Salesforce CLI installed (`sf` commands)
- VS Code with Salesforce Extension Pack
- A Salesforce Developer Edition or Scratch Org

### Steps

**1. Clone the repository**
```bash
git clone https://github.com/ajitdas2021/SavorFlow.git
cd SavorFlow
```

**2. Authorize your org**
```bash
sf org login web --alias savorflow-dev
```

**3. Deploy all metadata**
```bash
sf project deploy start --source-dir force-app
```

**4. Open the org**
```bash
sf org open --target-org savorflow-dev
```

---

## Deployment

```bash
sf project deploy start --source-dir force-app
```

---

## Author

**Ajit Das**
- GitHub: [@ajitdas2021](https://github.com/ajitdas2021)

---

> Built with ❤️ on the Salesforce Platform