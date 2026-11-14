import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/medicine.dart';
import '../models/sale.dart';
import '../models/pharmacy_profile.dart';
import '../providers/providers.dart';

/// Holds the resolved reference path for the logged-in pharmacy.
class PharmacyLocation {
  final String docId;
  final String path; // e.g. "pharmacies/Test"
  final String city;
  final String area;

  const PharmacyLocation({
    required this.docId,
    required this.path,
    required this.city,
    required this.area,
  });
}

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final PharmacyLocation location;

  DatabaseService({required this.location});

  DocumentReference get _pharmacyRef => _db.doc(location.path);

  // ─── Primary Stock (subcollection /stock under pharmacy doc) ──────────────
  CollectionReference get _stockRef => _pharmacyRef.collection('stock');

  // ─── Primary Sales (subcollection /sales under pharmacy doc) ──────────────
  CollectionReference get _salesRef => _pharmacyRef.collection('sales');

  // ─── Mirror / Hierarchical Reference: cities > areas > pharmacies ─────────
  DocumentReference? get _nestedPharmacyRef {
    final c = PharmacyProfile.toKey(location.city);
    final a = PharmacyProfile.toKey(location.area);
    if (c.isEmpty || a.isEmpty) return null;
    return _db
        .collection('cities')
        .doc(c)
        .collection('areas')
        .doc(a)
        .collection('pharmacies')
        .doc(location.docId);
  }

  // ─── Medicines ────────────────────────────────────────────────────────────
  Stream<List<Medicine>> getMedicinesStream() {
    return _stockRef
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) =>
                Medicine.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<void> addMedicine(Medicine medicine) async {
    final docRef = await _stockRef.add(medicine.toMap());
    try {
      final nested = _nestedPharmacyRef;
      if (nested != null) {
        await nested.collection('stock').doc(docRef.id).set(medicine.toMap());
      }
    } catch (_) {}
  }

  Future<void> updateMedicine(String id, Map<String, dynamic> data) async {
    await _stockRef.doc(id).update(data);
    try {
      final nested = _nestedPharmacyRef;
      if (nested != null) {
        await nested.collection('stock').doc(id).update(data);
      }
    } catch (_) {}
  }

  Future<void> deleteMedicine(String id) async {
    await _stockRef.doc(id).delete();
    try {
      final nested = _nestedPharmacyRef;
      if (nested != null) {
        await nested.collection('stock').doc(id).delete();
      }
    } catch (_) {}
  }

  // ─── Sales ────────────────────────────────────────────────────────────────
  Stream<List<Sale>> getSalesStream() {
    return _salesRef
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) =>
                Sale.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<void> addSale(Sale sale) async {
    final docRef = await _salesRef.add(sale.toMap());
    try {
      final nested = _nestedPharmacyRef;
      if (nested != null) {
        await nested.collection('sales').doc(docRef.id).set(sale.toMap());
      }
    } catch (_) {}
  }

  Future<void> decrementStock(String medicineId, int quantity) async {
    final updateData = {'stock': FieldValue.increment(-quantity)};
    await _stockRef.doc(medicineId).update(updateData);
    try {
      final nested = _nestedPharmacyRef;
      if (nested != null) {
        await nested.collection('stock').doc(medicineId).update(updateData);
      }
    } catch (_) {}
  }
}

// ─── Database service provider ───────────────────────────────────────────────
final databaseServiceProvider = Provider<DatabaseService?>((ref) {
  final loc = ref.watch(pharmacyLocationFutureProvider).valueOrNull;
  if (loc == null) return null;
  return DatabaseService(location: loc);
});
