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
| **P4** | **Firestore Scoped Security Rules** | 🟢 Complete | `in-progress` | Per-pharmacy rules file in repo (rules file only, not deployed), read/write protection. |
| **P5** | **Atomic Sale & Per-Pharmacy Counter** | 🟡 Ready | Pending | Firestore transaction: sale + stock decrement + `PH-YYYY-####` sequential bill no. |
| **P6** | **Real Thermal & PDF Printing** | ⚪ Pending | — | Real PDF generation & 80mm thermal receipt printing via `printing` package. |
| **P7** | **Itemized GST by HSN Slab** | ⚪ Pending | — | Per-medicine HSN + GST slabs (5/12/18%), CGST+SGST intra-state split on invoice. |
| **P8** | **Orders Inbox (Klinixy Quick-Commerce)** | ⚪ Pending | — | Live listener for `orders` collection, new order badge, Accept/Reject/Pack workflow. |
| **P9** | **Inventory Depth (FEFO, Batches, PO)** | ⚪ Pending | — | Batch numbers, FEFO dispensing guard, Purchase Orders, Returns/Refunds. |
| **P10** | **Unified Analytics & Financial Reports** | ⚪ Pending | — | Date presets + custom range picker, 4 KPIs, Peak Hours, Excel/CSV multi-export. |
| **P11** | **UX Polish & Keyboard-First POS** | ⚪ Pending | — | Riverpod persistent cart, keyboard shortcuts (Enter/Ctrl+Enter/Esc), barcode scan. |
| **P12** | **Klinixy Branding Alignment** | ⚪ Pending | — | Systematic branding across app title, headers, invoices, web metadata. |
| **P13** | **Automated Tests & Quality Suite** | ⚪ Pending | — | Automated widget tests for POS maths, stock guards, and order states. |
| **P14** | **Final End-to-End QA & Handover** | ⚪ Pending | — | 20-case checklist verification, demo seeding verification, handover documentation. |

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
