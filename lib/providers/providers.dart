import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/medicine.dart';
import '../models/sale.dart';
import '../models/pharmacy_profile.dart';

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

// ─── Pharmacy Profile ─────────────────────────────────────────────────────────
// Streams from: cities/{city}/areas/{area}/pharmacies/{uid}
final pharmacyProfileProvider = StreamProvider<PharmacyProfile?>((ref) {
  final loc = ref.watch(pharmacyLocationProvider);
  if (loc == null) return Stream.value(null);
  return ref
      .watch(authServiceProvider)
      .pharmacyProfileStream(loc.uid, loc.city, loc.area);
});

// ─── Stock Stream ────────────────────────────────────────────────────────────
// cities/{city}/areas/{area}/pharmacies/{uid}/stock
final medicinesStreamProvider = StreamProvider<List<Medicine>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  if (db == null) return Stream.value([]);
  return db.getMedicinesStream();
});

// ─── Sales Stream ────────────────────────────────────────────────────────────
// cities/{city}/areas/{area}/pharmacies/{uid}/sales
final salesStreamProvider = StreamProvider<List<Sale>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  if (db == null) return Stream.value([]);
  return db.getSalesStream();
});
