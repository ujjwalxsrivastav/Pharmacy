import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/medicine.dart';
import '../models/sale.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Medicines ───────────────────────────────────────────
  Stream<List<Medicine>> getMedicinesStream() {
    return _firestore.collection('medicines').orderBy('name').snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => Medicine.fromMap(doc.data(), doc.id)).toList(),
    );
  }

  Future<void> addMedicine(Medicine medicine) async {
    await _firestore.collection('medicines').add(medicine.toMap());
  }

  Future<void> updateMedicine(String id, Map<String, dynamic> data) async {
    await _firestore.collection('medicines').doc(id).update(data);
  }

  Future<void> deleteMedicine(String id) async {
    await _firestore.collection('medicines').doc(id).delete();
  }

  // ─── Sales ──────────────────────────────────────────────
  Stream<List<Sale>> getSalesStream() {
    return _firestore.collection('sales').orderBy('date', descending: true).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => Sale.fromMap(doc.data(), doc.id)).toList(),
    );
  }

  Future<void> addSale(Sale sale) async {
    await _firestore.collection('sales').add(sale.toMap());
  }

  Future<void> decrementStock(String medicineId, int quantity) async {
    await _firestore.collection('medicines').doc(medicineId).update({
      'stock': FieldValue.increment(-quantity),
    });
  }
}

final databaseServiceProvider = Provider<DatabaseService>((ref) => DatabaseService());
