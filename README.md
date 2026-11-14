# PharmaDash — Klinixy Pharmacy Management System

Enterprise Pharmacy Point-of-Sale (POS), inventory management, financial analytics, and order fulfillment platform for the **Klinixy** healthcare ecosystem.

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK `^3.7.2` (Dart 3.x)
- Google Chrome / Microsoft Edge (Web) or Android Device

### Running the Web Application
```bash
# Get dependencies
flutter pub get

# Run on Chrome
flutter run -d chrome

# Run on Edge
flutter run -d edge
```

### Running Tests & Lint
```bash
# Run unit & widget smoke tests
flutter test

# Code analysis
flutter analyze
```

---

## ☁️ Firebase Infrastructure

- **Firebase Project:** `klinixy-68521`
- **Authentication:** Firebase Auth (Email & Password, reactive state streaming)
- **Database:** Cloud Firestore
  - Root collections: `pharmacies`, `pharmacyIndex`, `users`, `orders`
  - Hierarchical mirroring: `cities/{cityId}/areas/{areaId}/pharmacies/{pharmacyId}`
  - Subcollections: `stock` (inventory catalog), `sales` (invoices & transaction records)

---

## 📱 Navigation & Tab Map

1. **Dashboard (Tab 0)**
   - Live greeting & pharmacy identity badge (`Ujjwal` / `Test`)
   - Quick "Start Counter Billing" banner
   - Real-time stat cards (Today's Revenue, In-Stock Products, Low Stock Count, Expiring Soon)
   - Last 7 days sales trend chart & recent transactions
   - Dark / Light mode toggle & profile bottom sheet (Edit Profile, Sign Out)

2. **Inventory Management (Tab 1)**
   - Live searchable medicine catalog with category chips
   - Direct **Stock In (+)** modal with chips (+10, +25, +50, +100) & atomic update
   - Direct **Stock Out (-)** with strict over-draw boundary guards & reason tracking
   - Full **Edit Medicine Details** and **Delete Medicine** with confirmation
   - **+ Add Medicine** Floating Action Button (FAB)

3. **Counter Billing & POS (Tab 2)**
   - **Pakka Bill (+18% GST Tax Invoice)** vs **Kaccha Bill (Estimate)** toggle
   - Walk-in customer search & quick add to cart
   - Interactive quantity steppers (+ / -) & real-time cart calculations
   - Official **Thermal Receipt Dialog** popup on bill generation with print & tax breakdown
   - Real-time Firestore stock decrement & sales logging

4. **Analytics & Financial Reports (Tab 3)**
   - Range presets: `Today`, `Last 7 Days`, `This Month`, `All Time`
   - 4 Enterprise KPIs: Total Revenue, Total GST collected, Order Count, Average Order Value
   - **Peak Sales Hours & Store Traffic** volume chart (09:00 - 21:00) with peak badge
   - **Category Revenue Breakdown** progress bars
   - **Export Excel / CSV** (direct browser CSV download)
   - **Export PDF & Print** dialog with full ledger preview

5. **Alerts & Stock Health (Tab 4)**
   - Category filtering: All Alerts, Low Stock, Expiring Soon, Expired, Slow Moving (30-day zero-sales)
   - Direct one-click **Stock In** shortcut on low stock items
   - Direct **Stock Out / Dispose** on expired items
   - Clean state indicator when all inventory is healthy

---

## 🎨 Theme & Style Guidelines
- **Primary Color:** Teal `#00BFA6`
- **Accent Color:** Violet `#7C4DFF`
- **Typography:** Google Fonts Inter
- **Border Radius:** 16px cards, modern Material 3 design
- **Modes:** Full Dark (`#0F1923`) and Light (`#F5F7FA`) parity
