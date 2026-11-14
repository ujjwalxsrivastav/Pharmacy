import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/medicine.dart';
import '../models/sale.dart';
import '../models/pharmacy_profile.dart';
import '../providers/providers.dart';

/// Holds the resolved reference path for the logged-in pharmacy.
class PharmacyLocation {
  final String docId; // e.g. "Test"
  final String path; // e.g. "pharmacies/Test"
  final String city; // e.g. "Dehradun"
  final String area; // e.g. "Selaqui"
  final String cityId; // e.g. "dehradun"
  final String areaId; // e.g. "selaqui"

  const PharmacyLocation({
    required this.docId,
    required this.path,
    required this.city,
    required this.area,
    String? cityId,
    String? areaId,
  })  : cityId = cityId ?? 'dehradun',
        areaId = areaId ?? 'selaqui';
}

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final PharmacyLocation location;

  DatabaseService({required this.location});

  DocumentReference get _rootPharmacyRef =>
      _db.collection('pharmacies').doc(location.docId);

  DocumentReference get _nestedPharmacyRef {
    final cKey = location.cityId.isNotEmpty
        ? location.cityId
        : PharmacyProfile.toKey(location.city);
    final aKey = location.areaId.isNotEmpty
        ? location.areaId
        : PharmacyProfile.toKey(location.area);
    return _db
        .collection('cities')
        .doc(cKey)
        .collection('areas')
        .doc(aKey)
        .collection('pharmacies')
        .doc(location.docId);
  }

  // ─── Medicines ────────────────────────────────────────────────────────────
  Stream<List<Medicine>> getMedicinesStream() {
    return _rootPharmacyRef
        .collection('stock')
        .orderBy('name')
        .snapshots()
        .asyncMap((rootSnap) async {
      if (rootSnap.docs.isNotEmpty) {
        return rootSnap.docs
            .map((doc) =>
                Medicine.fromMap(doc.data(), doc.id))
            .toList();
      }
      try {
        final nestedSnap = await _nestedPharmacyRef
            .collection('stock')
            .orderBy('name')
            .get();
        if (nestedSnap.docs.isNotEmpty) {
          for (final doc in nestedSnap.docs) {
            _rootPharmacyRef
                .collection('stock')
                .doc(doc.id)
                .set(doc.data(), SetOptions(merge: true))
                .catchError((_) {});
          }
          return nestedSnap.docs
              .map((doc) =>
                  Medicine.fromMap(doc.data(), doc.id))
              .toList();
        }
      } catch (_) {}
      return [];
    });
  }

  Future<void> addMedicine(Medicine medicine) async {
    final docRef = await _rootPharmacyRef.collection('stock').add(medicine.toMap());
    try {
      await _nestedPharmacyRef
          .collection('stock')
          .doc(docRef.id)
          .set(medicine.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> updateMedicine(String id, Map<String, dynamic> data) async {
    await _rootPharmacyRef.collection('stock').doc(id).update(data);
    try {
      await _nestedPharmacyRef.collection('stock').doc(id).update(data);
    } catch (_) {}
  }

  Future<void> deleteMedicine(String id) async {
    await _rootPharmacyRef.collection('stock').doc(id).delete();
    try {
      await _nestedPharmacyRef.collection('stock').doc(id).delete();
    } catch (_) {}
  }

  Future<void> adjustStock(String medicineId, int delta) async {
    final updateData = {'stock': FieldValue.increment(delta)};
    await _rootPharmacyRef.collection('stock').doc(medicineId).update(updateData);
    try {
      await _nestedPharmacyRef
          .collection('stock')
          .doc(medicineId)
          .update(updateData);
    } catch (_) {}
  }

  Future<void> decrementStock(String medicineId, int quantity) async {
    await adjustStock(medicineId, -quantity);
  }

  // ─── Sales ────────────────────────────────────────────────────────────────
  Stream<List<Sale>> getSalesStream() {
    return _rootPharmacyRef
        .collection('sales')
        .orderBy('date', descending: true)
        .snapshots()
        .asyncMap((rootSnap) async {
      if (rootSnap.docs.isNotEmpty) {
        return rootSnap.docs
            .map((doc) =>
                Sale.fromMap(doc.data(), doc.id))
            .toList();
      }
      try {
        final nestedSnap = await _nestedPharmacyRef
            .collection('sales')
            .orderBy('date', descending: true)
            .get();
        if (nestedSnap.docs.isNotEmpty) {
          for (final doc in nestedSnap.docs) {
            _rootPharmacyRef
                .collection('sales')
                .doc(doc.id)
                .set(doc.data(), SetOptions(merge: true))
                .catchError((_) {});
          }
          return nestedSnap.docs
              .map((doc) =>
                  Sale.fromMap(doc.data(), doc.id))
              .toList();
        }
      } catch (_) {}
      return [];
    });
  }

  Future<void> addSale(Sale sale) async {
    final docRef = await _rootPharmacyRef.collection('sales').add(sale.toMap());
    try {
      await _nestedPharmacyRef
          .collection('sales')
          .doc(docRef.id)
          .set(sale.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }
}

// ─── Database service provider ───────────────────────────────────────────────
final databaseServiceProvider = Provider<DatabaseService?>((ref) {
  final loc = ref.watch(pharmacyLocationFutureProvider).valueOrNull;
  if (loc == null) return null;
  return DatabaseService(location: loc);
});
