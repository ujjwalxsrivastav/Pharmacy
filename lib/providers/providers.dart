import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/medicine.dart';
import '../models/sale.dart';
import '../models/pharmacy_profile.dart';
import '../models/supplier.dart';
import '../models/purchase_order.dart';
import '../services/order_contract.dart';

// ─── Theme ────────────────────────────────────────────────────────────────────
class ThemeModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, bool>(ThemeModeNotifier.new);

// ─── Navigation ───────────────────────────────────────────────────────────────
class SelectedTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int index) => state = index;
}

final selectedTabProvider =
    NotifierProvider<SelectedTabNotifier, int>(SelectedTabNotifier.new);

// ─── Inventory Search ─────────────────────────────────────────────────────────
class InventorySearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String query) => state = query;
}

final inventorySearchProvider =
    NotifierProvider<InventorySearchNotifier, String>(
        InventorySearchNotifier.new);

// ─── Auth User ────────────────────────────────────────────────────────────────
final authUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// ─── Pharmacy Location FutureProvider ─────────────────────────────────────────
final pharmacyLocationFutureProvider = FutureProvider<PharmacyLocation?>((ref) async {
  final user = ref.watch(authUserProvider).valueOrNull;
  if (user == null) return null;

  return await ref.read(authServiceProvider).resolvePharmacyLocation(
        user.uid,
        user.email ?? '',
      );
});

// ─── Pharmacy Profile ─────────────────────────────────────────────────────────
final pharmacyProfileProvider = StreamProvider<PharmacyProfile?>((ref) {
  final locAsync = ref.watch(pharmacyLocationFutureProvider);
  final loc = locAsync.valueOrNull;
  if (loc == null) return Stream.value(null);
  return ref.watch(authServiceProvider).pharmacyProfileStream(loc.path);
});

// ─── Stock Stream ────────────────────────────────────────────────────────────
final medicinesStreamProvider = StreamProvider<List<Medicine>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  if (db == null) return Stream.value([]);
  return db.getMedicinesStream();
});

// ─── Sales Stream ────────────────────────────────────────────────────────────
final salesStreamProvider = StreamProvider<List<Sale>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  if (db == null) return Stream.value([]);
  return db.getSalesStream();
});

// ─── Orders Stream (Quick-Commerce Ecosystem) ─────────────────────────────────
final ordersStreamProvider = StreamProvider<List<KlinixyOrder>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  if (db == null) return Stream.value([]);
  return db.getOrdersStream();
});

final pendingOrdersCountProvider = Provider<int>((ref) {
  final orders = ref.watch(ordersStreamProvider).valueOrNull ?? [];
  return orders.where((o) => o.isPlaced).length;
});

// ─── Suppliers Stream (P9 Inventory Depth) ────────────────────────────────────
final suppliersStreamProvider = StreamProvider<List<Supplier>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  if (db == null) return Stream.value([]);
  return db.getSuppliersStream();
});

// ─── Purchase Orders Stream (P9 Inventory Depth) ──────────────────────────────
final purchaseOrdersStreamProvider = StreamProvider<List<PurchaseOrder>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  if (db == null) return Stream.value([]);
  return db.getPurchaseOrdersStream();
});

// ─── POS Cart Notifier (P11 UX Pass: Persistent across tabs) ──────────────────
class CartNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => {};

  bool addItem(String medicineId, int maxStock, {int qty = 1}) {
    final current = state[medicineId] ?? 0;
    if (current + qty <= maxStock) {
      state = {...state, medicineId: current + qty};
      return true;
    }
    return false;
  }

  void decrementItem(String medicineId) {
    final current = state[medicineId];
    if (current == null) return;
    if (current > 1) {
      state = {...state, medicineId: current - 1};
    } else {
      removeItem(medicineId);
    }
  }

  void setQuantity(String medicineId, int qty, int maxStock) {
    if (qty <= 0) {
      removeItem(medicineId);
    } else {
      final safeQty = qty > maxStock ? maxStock : qty;
      state = {...state, medicineId: safeQty};
    }
  }

  void removeItem(String medicineId) {
    final updated = Map<String, int>.from(state)..remove(medicineId);
    state = updated;
  }

  void clearCart() {
    state = {};
  }
}

final cartProvider =
    NotifierProvider<CartNotifier, Map<String, int>>(CartNotifier.new);

final cartTotalUnitsProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.values.fold<int>(0, (sum, q) => sum + q);
});

final cartUniqueCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.length;
});
