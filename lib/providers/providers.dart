import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/medicine.dart';
import '../models/sale.dart';
import '../models/pharmacy_profile.dart';

// ─── Theme ───────────────────────────────────────────────────────────────────
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

// ─── Current Auth User ────────────────────────────────────────────────────────
final authUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// ─── Current Pharmacy Profile ─────────────────────────────────────────────────
final pharmacyProfileProvider = StreamProvider<PharmacyProfile?>((ref) {
  final userAsync = ref.watch(authUserProvider);
  final uid = userAsync.valueOrNull?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(authServiceProvider).pharmacyProfileStream(uid);
});

// ─── Data Streams (pharmacy-scoped) ──────────────────────────────────────────
final medicinesStreamProvider = StreamProvider<List<Medicine>>((ref) {
  final pharmacyId = ref.watch(currentPharmacyIdProvider);
  if (pharmacyId == null || pharmacyId.isEmpty) return Stream.value([]);
  return ref.watch(databaseServiceProvider).getMedicinesStream();
});

final salesStreamProvider = StreamProvider<List<Sale>>((ref) {
  final pharmacyId = ref.watch(currentPharmacyIdProvider);
  if (pharmacyId == null || pharmacyId.isEmpty) return Stream.value([]);
  return ref.watch(databaseServiceProvider).getSalesStream();
});
