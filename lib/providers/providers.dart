import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../models/medicine.dart';
import '../models/sale.dart';

// ─── Theme ──────────────────────────────────────────────────
class ThemeModeNotifier extends Notifier<bool> {
  @override
  bool build() => false; // false = light mode

  void toggle() => state = !state;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, bool>(ThemeModeNotifier.new);

// ─── Navigation ─────────────────────────────────────────────
class SelectedTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}

final selectedTabProvider = NotifierProvider<SelectedTabNotifier, int>(SelectedTabNotifier.new);

// ─── Inventory Search ────────────────────────────────────────
class InventorySearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

final inventorySearchProvider = NotifierProvider<InventorySearchNotifier, String>(InventorySearchNotifier.new);

// ─── Data Streams ────────────────────────────────────────────
final medicinesStreamProvider = StreamProvider<List<Medicine>>((ref) {
  return ref.watch(databaseServiceProvider).getMedicinesStream();
});

final salesStreamProvider = StreamProvider<List<Sale>>((ref) {
  return ref.watch(databaseServiceProvider).getSalesStream();
});
