import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/medicine.dart';
import '../models/sale.dart';
import '../providers/providers.dart';

/// Holds the resolved location path for the logged-in pharmacy.
class PharmacyLocation {
  final String uid;
  final String city;
  final String area;

  const PharmacyLocation({
    required this.uid,
    required this.city,
    required this.area,
  });
}

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final PharmacyLocation location;

  DatabaseService({required this.location});

  // ─── Base reference ────────────────────────────────────────────────────
  // cities/{city}/areas/{area}/pharmacies/{uid}
  DocumentReference get _pharmacyRef => _db
      .collection('cities')
      .doc(location.city)
      .collection('areas')
      .doc(location.area)
      .collection('pharmacies')
      .doc(location.uid);

  // ─── Stock ────────────────────────────────────────────────────────────
  CollectionReference get _stockRef => _pharmacyRef.collection('stock');

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
    await _stockRef.add(medicine.toMap());
  }

  Future<void> updateMedicine(String id, Map<String, dynamic> data) async {
    await _stockRef.doc(id).update(data);
  }

  Future<void> deleteMedicine(String id) async {
    await _stockRef.doc(id).delete();
  }

  // ─── Sales ─────────────────────────────────────────────────────────────
  CollectionReference get _salesRef => _pharmacyRef.collection('sales');

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
    await _salesRef.add(sale.toMap());
  }

  Future<void> decrementStock(String medicineId, int quantity) async {
    await _stockRef.doc(medicineId).update({
      'stock': FieldValue.increment(-quantity),
    });
  }
}

// ─── Database service provider ───────────────────────────────────────────────
final databaseServiceProvider = Provider<DatabaseService?>((ref) {
  final loc = ref.watch(pharmacyLocationFutureProvider).valueOrNull;
  if (loc == null) return null;
  return DatabaseService(location: loc);
});
