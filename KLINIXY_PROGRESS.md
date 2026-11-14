# Klinixy Pharmacy — Enterprise Implementation Progress

> Tracker created in accordance with `Klinixy-Pharmacy-Enterprise-Deep-Dive.md` §9.
> Tracks the execution status of enterprise milestones (P0 through P14).
> Rule: Verified & committed step-by-step; zero `flutter analyze` errors after every phase.

---

## 📊 Phase Roadmap & Live Status

| Phase | Title | Status | Commit | Verification Notes |
|:---|:---|:---:|:---:|:---|
| **P0** | **Baseline + Cleanup** | 🟢 Complete | `a360050` | `flutter analyze` 0 issues, smoke test green, stray HTML moved, README rewritten. |
| **P1** | **Reconcile Repo vs Live UI** | 🟢 Complete | `20ba9b3` | 5 tabs kept, Analytics banner linked, 15 live category chips added, modal Add Medicine, forgot-password flow. |
| **P2** | **Pharmacy Location (GeoPoint + UI)** | 🟢 Complete | `23fd1d9` | GeoPoint coords, address, phone, isOpen toggle, delivery radius, geolocator GPS. |
| **P3** | **Auth & Identity Hardening** | 🟢 Complete | `a21905e` | Single source `users/{uid}`, explicit un-onboarded state, forgot-password reset, reachable logout. |
| **P4** | **Firestore Scoped Security Rules** | 🟢 Complete | `a0ebe30` | Per-pharmacy rules file in repo (rules file only, not deployed), read/write protection. |
| **P5** | **Atomic Sale & Per-Pharmacy Counter** | 🟢 Complete | `f67dc43` | Firestore transaction: sale + stock decrement + `PH-YYYY-####` sequential bill no. |
| **P6** | **Real Thermal & PDF Printing** | 🟢 Complete | `f3617cc` | Real PDF generation & 80mm thermal receipt printing via `printing` package. |
| **P7** | **Itemized GST by HSN Slab** | 🟢 Complete | `6a636db` | Per-medicine HSN + GST slabs (5/12/18%), CGST+SGST intra-state split on invoice. |
| **P8** | **Orders Inbox (Klinixy Quick-Commerce)** | 🟢 Complete | `a9a0410` | Live listener for `orders` collection, new order badge, Accept/Reject/Pack workflow. |
| **P9** | **Inventory Depth (FEFO, Batches, PO)** | 🟢 Complete | `f808e43` | Batch numbers, FEFO dispensing guard, Purchase Orders, Returns/Refunds. |
| **P10** | **Unified Analytics & Financial Reports** | 🟢 Complete | `ebbdaaf` | Date presets + custom range picker, 4 KPIs, Peak Hours, Excel/CSV multi-export. |
| **P11** | **UX Polish & Keyboard-First POS** | 🟢 Complete | `69f134a` | Riverpod persistent cart, keyboard shortcuts (Enter/Ctrl+Enter/Esc), barcode scan. |
| **P12** | **Klinixy Branding Alignment** | 🟢 Complete | `48bff84` | Systematic branding across app title, headers, invoices, web metadata. |
| **P13** | **Automated Tests & Quality Suite** | 🟢 Complete | `3b01b3a` | Automated widget tests for POS maths, stock guards, and order states. |
| **P14** | **Final End-to-End QA & Handover** | 🟢 Complete | `d79d4f0` | 20-case checklist verification, demo seeding verification, handover documentation. |

---

## 📝 Detailed Log of Completed Steps

### [P0] Baseline + Cleanup
- **Goal:** Clean baseline, remove stray files, verify real widget smoke test, update documentation.
- **Actions:**
  - Verified initial commit HEAD was `1257469`.
  - Moved stray `lib/index.html` (Softrion ERP proposal) to `docs/archive/stray_index.html`.
  - Replaced failing default counter test in `test/widget_test.dart` with a real `ProviderScope` smoke test that tests `PharmaDashApp` booting to `LoginScreen`.
  - Completely rewritten `README.md` with setup guides, tab map, and architectural summary.
  - Verified `flutter test` passing with 0 failures and `flutter analyze` passing with 0 issues.

### [P1] Reconcile Repo vs Live UI
- **Goal:** Reconcile navigation, category chips, Add Medicine modal, and forgot-password link with live site §2.
- **Actions:**
  - Retained 5-tab bottom navigation with live Dashboard banner ("Analytics & Reports →") linking to Tab 3.
  - Connected 4 Dashboard stat cards to their respective tabs (Revenue → Billing, Products → Inventory, Alerts → Alerts).
  - Added full set of 15 horizontally scrollable live category chips in `InventoryScreen`.
  - Added in-page modal dialog for "+ Add Medicine" with fields: Name, Category, Price (₹), Initial Stock, Min Safe Stock, and Expiry Date.
  - Added "Forgot password?" flow on `LoginScreen` powered by `sendPasswordResetEmail`.
  - Verified `flutter analyze` passing with 0 issues and `flutter test` green.

### [P2] Pharmacy Location (GeoPoint + UI)
- **Goal:** Enable the pharmacy to set and edit its GPS coordinates, street address, store open/closed status, and delivery radius.
- **Actions:**
  - Added `location` (Firestore `GeoPoint`), `address`, `phone`, `isOpen`, `deliveryRadiusKm`, `gstin`, `locationUpdatedAt`, and `locationUpdatedBy` to `PharmacyProfile`.
  - Added `geolocator` dependency with Android location permissions and web compatibility.
  - Added full Location & Store section to `EditProfileDialog`:
    - Device GPS detection via "Use Current Location" button with safe permission checking & error handling.
    - Editable validated latitude & longitude input fields (-90..90, -180..180).
    - "Open in Google Maps" external link viewer (universal web/mobile).
    - Store Open / Closed status switch and delivery radius configuration.
  - Integrated Location Status chip ("Location Set ✓" vs "Location Not Set") and gentle callout banner on Dashboard.
  - Mirrored updates to root `pharmacies/{id}`, hierarchical `cities/.../pharmacies/{id}`, and `pharmacyIndex/{id}`.
  - Verified `flutter analyze` 0 issues and `flutter test` green.

### [P3] Auth & Identity Hardening
- **Goal:** Harden authentication identity resolution using `users/{uid}` as canonical source, remove silent fallbacks/dummy deletions, and enforce explicit un-onboarded handling.
- **Actions:**
  - Rewrote `resolvePharmacyLocation`:
    - Checks `users/{uid}` single source of truth for canonical `pharmacyId`, `cityId`, and `areaId`.
    - Removed arbitrary document deletion and hardcoded fallback data.
    - If no pharmacy profile is associated with the user, throws `PharmacyNotOnboardedException`.
  - Integrated explicit "Pharmacy Not Onboarded" error screen in `main.dart` with "Sign Out & Register" flow.
  - Updated `signUp` to automatically write the canonical identity record to `users/{uid}` inside the atomic batch.
  - Verified `flutter analyze` 0 issues and `flutter test` green.

### [P4] Firestore Scoped Security Rules
- **Goal:** Enforce per-pharmacy scoping and ecosystem access rules in `firestore.rules`.
- **Actions:**
  - Auth user restricted to reading/writing only their own pharmacy root and nested paths (`stock`, `sales`, `counters`).
  - Read-only protection for `pharmacyIndex` across standard authenticated clients.
  - Protected `isVerified` field from non-admin client modifications.
  - Scoped `orders` collection so pharmacies can only read and transition statuses of their own assigned orders.
  - Rules updated in the repo file only (not deployed — Maalik deploys).
  - Verified `flutter analyze` 0 issues and `flutter test` green.

### [P5] Atomic Sale & Per-Pharmacy Counter
- **Goal:** Eliminate partial writes and race conditions by making billing execution fully transactional with guaranteed sequential numbering.
- **Actions:**
  - Implemented `processAtomicSale` inside a Firestore `runTransaction`:
    - Checks stock availability of all items in cart before deducting (guard against negative inventory).
    - Sequential bill counter per pharmacy per year format `PH-YYYY-####` stored at `pharmacies/{docId}/counters/bill_counter_$year`.
    - Decrements stock across both root and nested paths atomically.
    - Creates sale document in root and nested subcollections with server `Timestamp` and `updatedBy`.
  - Replaced legacy sequential loop in `CounterBillingScreen` with single atomic invocation.
  - Verified `flutter analyze` 0 issues and `flutter test` green.

### [P6] Real Thermal & PDF Printing
- **Goal:** Replace fake success SnackBars with real document generation and printing for 80mm thermal receipts and A4 financial reports.
- **Actions:**
  - Created `PrinterService` in `lib/services/printer_service.dart`:
    - `generateReceiptBytes` & `printReceipt`: formats clean 80mm thermal roll PDF receipts with store name, address, profile GSTIN, phone, customer name, sequential bill number, itemized rates/totals, subtotal, CGST/SGST tax split, and grand total.
    - `generateSalesReportBytes` & `printSalesReport`: generates comprehensive A4 financial reports with executive KPI summary table (revenue, GST, transactions count, avg value) and transaction breakdowns.
  - Completely removed fake success SnackBars in `BillReceiptDialog` and `SalesScreen`.
  - Replaced hardcoded `GSTIN: 27AABCP1234F1Z5` with the authenticated pharmacy's live profile `gstin`.
  - Wired real `Printing.layoutPdf` into POS billing dialog, sales transaction receipts, and financial report print buttons.
  - Resolved `image`/`archive` transitive dependency incompatibility via dependency override.
  - Verified `flutter analyze` passing with 0 issues and `flutter test` passing with 0 failures.

### [P7] Itemized GST by HSN Slab
- **Goal:** Replace flat 18% calculation with real pharmaceutical GST slabs (5%, 12%, 18%) configured per item by HSN code, displaying CGST and SGST intra-state splits on receipts, bills, and reports.
- **Actions:**
  - Updated `Medicine` model: added `hsn` (default `'3004'`) and `gstSlab` (default `12`, options 5/12/18%), with backward-compatible Firestore decoders.
  - Updated Add Medicine modal, Quick Add dialog, and Edit Medicine dialogs with editable HSN Code and GST Slab dropdowns.
  - Updated `SaleItem` model: added `hsn`, `gstSlab`, and computed `taxAmount`.
  - Updated `Sale` model: added `cgst` (`taxAmount / 2`), `sgst` (`taxAmount / 2`), and `taxBySlab` map breakdown.
  - Updated `CounterBillingScreen`: calculates itemized tax per item by its specific slab for Pakka bills, displays CGST & SGST intra-state split in footer, and charges 0 GST on Kaccha bills.
  - Updated `BillReceiptDialog`: renders HSN and GST slab per line item, and displays CGST/SGST/Total GST breakdown.
  - Updated `PrinterService`: prints HSN and slab in 80mm thermal receipts and itemized GST columns in financial reports.
  - Added unit test suite `test/billing_gst_test.dart` verifying multi-slab calculations (5% + 12% + 18%), backward-compatible deserialization, and Kaccha 0-tax behavior.
  - Verified `flutter analyze` passing with 0 issues and `flutter test` passing (4/4 tests green).

### [P8] Orders Inbox (Klinixy Quick-Commerce)
- **Goal:** Build the complete quick-commerce online orders workflow connecting the Customer app, Pharmacy dashboard, and Rider app based on §5 ecosystem contracts.
- **Actions:**
  - Implemented `lib/services/order_contract.dart`:
    - Strict `KlinixyOrder`, `OrderItem`, and `OrderStatusEntry` contracts matching the Firestore top-level `orders` schema.
    - Status lifecycle: `placed` → `accepted` → `packed` → `rider_assigned` → `picked` → `delivered`, or `rejected`/`cancelled`.
  - Added order operations to `DatabaseService`:
    - `getOrdersStream()`: real-time Firestore listener filtered by authenticated `pharmacyId`.
    - `acceptOrder`: transactional verification of stock availability and atomic decrement of stock across root and nested collections before marking `accepted` with `statusHistory` logging.
    - `rejectOrder`: requires mandatory rejection reason (e.g. out of stock, closed), updates status to `rejected`, and appends reason to `statusHistory` without touching stock.
    - `markOrderPacked`: sets status to `packed` indicating ready for rider pickup.
  - Added `ordersStreamProvider` and `pendingOrdersCountProvider` in `lib/providers/providers.dart`.
  - Created `OrdersScreen` (`lib/screens/orders_screen.dart`):
    - Filter chips (All, Placed, Accepted, Packed, In Transit, Delivered, Rejected).
    - Itemized breakdown, customer delivery address and phone, prescription indicators, and status badges.
    - Accept / Reject (with reason picker modal) / Mark Packed interactive actions.
  - Linked Orders directly to `DashboardScreen` (top header icon with live count badge + urgent alert banner when new orders are placed) and `AlertsScreen` (inbox shortcut button).
  - Added unit tests in `test/orders_contract_test.dart` verifying order serialization, status methods, and rejection reasons.
  - Verified `flutter analyze` passing with 0 issues and `flutter test` passing (6/6 tests green).

### [P9] Inventory Depth (FEFO, Batches, Purchase Orders, Returns)
- **Goal:** Implement enterprise pharmaceutical inventory controls: batch numbers, physical rack/shelf tracking, Schedule H prescription requirements, FEFO (First-Expired, First-Out) dispensing guards, complete supplier procurement workflows, and customer returns/refunds.
- **Actions:**
  - Extended `Medicine` model: added `batchNo`, `rackShelf`, and `rxRequired` (Schedule H/H1 flag) with backward-compatible Firestore decoders.
  - Updated Add Medicine modal, Quick Add dialog, Edit Medicine dialog, and medicine details sheet to manage and display batch, shelf location, and prescription flags.
  - Integrated FEFO & Expiration Guards in `CounterBillingScreen`:
    - Blocks expired items outright from cart with explicit expiration date explanation.
    - Warns cashier with a FEFO banner if an earlier-expiring batch of the formulation exists in stock.
    - Highlights Schedule H/H1 prescription requirement.
  - Created Supplier & Purchase Order architecture:
    - Added `Supplier` (`lib/models/supplier.dart`) and `PurchaseOrder` (`lib/models/purchase_order.dart`) models.
    - Created `PurchaseOrdersScreen` (`lib/screens/purchase_orders_screen.dart`) featuring two tabs: Purchase Orders and Suppliers Directory.
    - Linked PO procurement directly from `InventoryScreen` header ("POs & Vendors" button).
    - Added `receivePurchaseOrder` transaction in `DatabaseService`: atomically increments stock across root and nested paths while updating medicine batch and expiry details.
  - Implemented Customer Returns & Refunds:
    - Added `processReturn` in `DatabaseService`: transactional restock of returned items and generation of negative audit sale record (`REF-PH-...`) preserving historical audit integrity without deleting original sales.
    - Added "Process Return / Refund" modal in `SalesScreen` allowing selection of original bill and return items.
  - Created unit test suite `test/inventory_depth_test.dart` testing batch tracking, FEFO batch detection, and negative refund calculation (10/10 tests green).
  - Verified `flutter analyze` passing with 0 issues.

### [P10] Unified Analytics & Financial Reports
- **Goal:** Unify the repository `SalesScreen` and the live Reports page spec (§2 & §3) into a single enterprise analytics surface featuring period presets, custom range picker, 4 standard financial KPI cards, 24-hour peak sales hours chart, top selling items, slow moving stock, category revenue breakdown, and multi-section CSV/Excel exports.
- **Actions:**
  - Standardized navigation and header in `SalesScreen`: back button returning to Dashboard / tab 0, "Reports" title, and green pill "Export" button with dropdown menu.
  - Implemented 5 period filter presets: Today, 7 Days, Month (default!), Year, and Custom (calendar icon) opening `showDateRangePicker`.
  - Configured 4 standard KPI cards: Total Revenue, Avg Order Value, GST Collected (CGST+SGST), and Invoice Types (Pakka vs Kaccha).
  - Built 24-hour Peak Sales Hours & Store Traffic chart (12AM - 11PM) with peak period indicator badge.
  - Added lower analytics sections:
    - "Top Selling Items 🔥": Ranked list with units sold and total revenue, with empty state: "No sales in this filter".
    - "Slow Moving Stock": Identifies active inventory with 0 or low sales, with empty states: "No stock data" / "All items are moving actively!".
    - "Category Revenue Breakdown": Visual percentage bars with category revenue, with empty state: "No revenue data for selected range".
  - Implemented multi-section CSV exports with standardized naming `Pharma_<Section>_yyyyMMdd_HHmm.csv` for Sales, Top Products, Slow Moving, Category Breakdown, and Full Aggregated Financial Report.
  - Retained Sales Ledger search, Pakka/Kaccha filter, and customer return/refund modal.
  - Created unit test suite `test/analytics_reports_test.dart` testing range filtering, KPIs, 24-hour peak hours, top selling, slow moving, and category revenue (16/16 tests green).
  - Verified `flutter analyze` passing with 0 issues.

### [P11] UX Polish & Keyboard-First POS
- **Goal:** Elevate pharmacist usability to enterprise standards while strictly preserving the locked design system (#00BFA6 teal, #7C4DFF violet, Inter, radius 16): persistent Riverpod cart across bottom tabs, full keyboard-first billing shortcuts, camera barcode scanner, 48px+ touch targets, optimistic updates, skeleton loaders, and explicit expiry indicators.
- **Actions:**
  - Migrated POS cart from ephemeral state to Riverpod `CartNotifier` (`cartProvider`): cart survives tab switches and page navigations without losing staged items.
  - Added live item-count badge to the Billing tab icon in `HomeShell` bottom navigation.
  - Implemented keyboard-first billing in `CounterBillingScreen`:
    - Autofocuses search input on open.
    - `Enter`: automatically adds top matching non-expired in-stock medicine to cart.
    - `Ctrl + Enter` (and `Cmd + Enter`): generates bill immediately without touching the mouse.
    - `Escape`: clears search input and closes search dropdown.
  - Added `mobile_scanner` integration with `BarcodeScannerDialog`:
    - Real-time camera barcode scan with reticle overlay.
    - Manual barcode / name fallback for web and desktop environments.
    - Automatic medicine lookup by barcode/batch/id and cart addition.
  - Enhanced touch targets: steppers and primary buttons updated to ≥ 48px.
  - Added destructive action confirmation: "Clear Cart" dialog explicitly states consequence ("Clearing the cart will remove all X items...").
  - Created `DashboardSkeleton` and `InventorySkeleton` in `lib/widgets/skeleton_loader.dart`, replacing bare spinners on initial load.
  - Enforced prominent red left border on expired medicine cards across Inventory, Billing search results, and Alerts.
  - Standardized currency formatting on `NumberFormat('#,##0.00')` throughout billing and headers.
  - Added unit test suite `test/cart_ux_test.dart` verifying cart state persistence, stock limits, decrementing, and counts (20/20 total tests green).
  - Verified `flutter analyze` passing with 0 issues.

### [P12] Klinixy Branding Alignment
- **Goal:** Execute agreed decision D-P2 by systematically branding the entire application to "Klinixy Pharmacy" across all titles, headers, authentication screens, invoice generators, and web metadata while keeping the locked teal/violet palette and functionality intact.
- **Actions:**
  - Updated application title in `lib/main.dart` from `PharmaDash` to `Klinixy Pharmacy`.
  - Rebranded authentication headline in `lib/screens/login_screen.dart` to `Klinixy Pharmacy`.
  - Updated web application title and metadata in `web/index.html` to `Klinixy Pharmacy — Enterprise POS & Quick-Commerce Dashboard`.
  - Configured progressive web app identity and theme colors in `web/manifest.json` (`name: "Klinixy Pharmacy"`, `short_name: "Klinixy"`, `#00BFA6` theme color).
  - Updated widget smoke test in `test/widget_test.dart` to explicitly verify that `Klinixy Pharmacy` is rendered on boot.
  - Verified `flutter analyze` passing with 0 issues and all 20 tests passing.

### [P13] Automated Tests & Quality Suite
- **Goal:** Replace all temporary and minimal test harnesses with an automated unit and widget quality suite covering POS billing maths, stock guards, dashboard rendering, Riverpod state lifecycle, and orders contract without hitting production Firestore.
- **Actions:**
  - Created `DashboardScreen` widget test suite (`test/dashboard_widget_test.dart`):
    - Verified rendering with seeded medicines, sales, and pharmacy profile (handler name, store title, 4 KPI cards, reports banner).
    - Verified graceful empty-state handling with ₹0.00 and 0 orders today.
  - Created `CounterBillingScreen` POS widget test suite (`test/pos_billing_widget_test.dart`):
    - Verified guidance text and "Focus Search" action when cart is empty.
    - Verified itemized bill breakdown: 40.00 subtotal, CGST (2.40), SGST (2.40), and 44.80 grand total for a 12% GST medicine.
  - Ensured header and skeleton layouts are flexible and responsive across mobile and desktop test viewports.
  - Test suite total grew to 24 tests across 7 test files, all passing in 3 seconds.
  - Verified `flutter analyze` passing with 0 issues.

### [P14] Final End-to-End QA & Handover
- **Goal:** Execute comprehensive acceptance QA against the 20-case checklist from §11, build a modular demo data seeder utility (`DemoDataSeeder`) covering 20 medicines across multiple categories and 30 days of sales history, write the executive handover notes, and ensure complete zero-error delivery.
- **Actions:**
  - Created `DemoDataSeeder` (`lib/utils/demo_seeder.dart`) generating 20 realistic pharmaceutical items with batches, rack locations, HSN 3004, GST slabs (5%, 12%, 18%), and 30 days of balanced Pakka and Kaccha sales.
  - Created `test/demo_seeder_test.dart` asserting seeder diversity, batch/shelf mappings, and sequential bill numbers.
  - Verified all 20 acceptance checklist items from §11:
    1. Login with wrong password yields friendly error without crashing.
    2. Forgot password sends Firebase reset email.
    3. Un-onboarded accounts redirect to explicit error screen with sign out option.
    4. Dashboard handles both 0/empty and populated data gracefully.
    5. Light (#F5F7FA) and dark (#0F1923) theme toggles function seamlessly across all screens.
    6. Adding medicine with expiry renders correct status chips.
    7. Stock In and Stock Out update inventory atomically with over-draw guards.
    8. Medicine edit and deletion with confirmation safeguards.
    9. Counter billing calculates Pakka intra-state CGST+SGST split and decrements stock.
    10. Kaccha bills correctly levy 0% tax.
    11. Expired medicines are blocked from entering cart with inline reason.
    12. Real thermal 80mm PDF printing via `Printing.layoutPdf`.
    13. Reports period pills (Today, 7 Days, Month, Year, Custom date picker) filter metrics dynamically.
    14. Multi-section CSV export generates valid formatted files.
    15. Alerts screen filters by low stock, expiring soon, expired, and slow moving.
    16. GPS and manual coordinates update GeoPoint and persist open/closed toggle.
    17. Quick-commerce orders stream updates inbox badge and supports accept/pack workflows.
    18. Order rejection requires mandatory reason and logs status history without touching stock.
    19. Profile avatar bottom sheet supports editing and secure logout.
    20. Complete automated test suite (26/26 tests passing) and `flutter analyze` 0 issues.
  - Authored the executive handover note at the top of `Klinixy-Pharmacy-Enterprise-Deep-Dive.md`.
