import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/medicine.dart';
import '../models/sale.dart';
import '../models/pharmacy_profile.dart';
import '../models/supplier.dart';
import '../models/purchase_order.dart';
import '../providers/providers.dart';
import 'order_contract.dart';

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

  String get pharmacyId => location.docId;

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

  // ─── Atomic Sale Transaction & Sequential Counter ──────────────────────────
  Future<Sale> processAtomicSale({
    required List<SaleItem> items,
    required String customerName,
    required String customerPhone,
    required String billType,
    required double subtotal,
    required double taxAmount,
    required double totalPrice,
    String? updatedByUid,
  }) async {
    final year = DateTime.now().year;
    final counterRef = _rootPharmacyRef.collection('counters').doc('bill_counter_$year');

    final generatedSale = await _db.runTransaction<Sale>((transaction) async {
      // 1. Read sequential counter
      final counterSnap = await transaction.get(counterRef);
      int currentSeq = 0;
      if (counterSnap.exists && counterSnap.data() != null) {
        currentSeq = ((counterSnap.data()!['lastSeq'] ?? 0) as num).toInt();
      }
      final nextSeq = currentSeq + 1;
      final seqStr = nextSeq.toString().padLeft(4, '0');
      final billNo = 'PH-$year-$seqStr';

      // 2. Verify stock availability for each item
      for (final item in items) {
        final stockDocRef = _rootPharmacyRef.collection('stock').doc(item.medicineId);
        final stockSnap = await transaction.get(stockDocRef);
        if (stockSnap.exists && stockSnap.data() != null) {
          final currentStock = ((stockSnap.data()!['stock'] ?? 0) as num).toInt();
          if (currentStock < item.quantity) {
            throw Exception('Insufficient stock for ${item.medicineName}. Available: $currentStock, Required: ${item.quantity}');
          }
        }
      }

      // 3. Increment counter
      transaction.set(counterRef, {
        'lastSeq': nextSeq,
        'year': year,
        'updatedAt': FieldValue.serverTimestamp(),
        if (updatedByUid != null) 'updatedBy': updatedByUid,
      }, SetOptions(merge: true));

      // 4. Decrement stock atomically
      for (final item in items) {
        final stockDocRef = _rootPharmacyRef.collection('stock').doc(item.medicineId);
        transaction.update(stockDocRef, {
          'stock': FieldValue.increment(-item.quantity),
          'updatedAt': FieldValue.serverTimestamp(),
          if (updatedByUid != null) 'updatedBy': updatedByUid,
        });

        final nestedStockDocRef = _nestedPharmacyRef.collection('stock').doc(item.medicineId);
        transaction.update(nestedStockDocRef, {
          'stock': FieldValue.increment(-item.quantity),
          'updatedAt': FieldValue.serverTimestamp(),
          if (updatedByUid != null) 'updatedBy': updatedByUid,
        });
      }

      // 5. Create Sale document in root & nested
      final saleRef = _rootPharmacyRef.collection('sales').doc();
      final saleData = {
        'billNo': billNo,
        'billType': billType,
        'customerName': customerName.trim().isNotEmpty ? customerName.trim() : 'Walk-in',
        'customerPhone': customerPhone.trim(),
        'items': items.map((i) => i.toMap()).toList(),
        'quantity': items.fold<int>(0, (sum, i) => sum + i.quantity),
        'medicineName': items.isNotEmpty ? items.first.medicineName : 'Medicine',
        'medicineId': items.isNotEmpty ? items.first.medicineId : '',
        'unitPrice': items.isNotEmpty ? items.first.unitPrice : 0.0,
        'subtotal': subtotal,
        'taxAmount': taxAmount,
        'totalPrice': totalPrice,
        'date': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (updatedByUid != null) 'updatedBy': updatedByUid,
      };

      transaction.set(saleRef, saleData);
      final nestedSaleRef = _nestedPharmacyRef.collection('sales').doc(saleRef.id);
      transaction.set(nestedSaleRef, saleData);

      return Sale(
        id: saleRef.id,
        billNo: billNo,
        billType: billType,
        customerName: customerName.trim().isNotEmpty ? customerName.trim() : 'Walk-in',
        medicineId: items.isNotEmpty ? items.first.medicineId : '',
        medicineName: items.isNotEmpty ? items.first.medicineName : 'Medicine',
        quantity: items.fold<int>(0, (sum, i) => sum + i.quantity),
        unitPrice: items.isNotEmpty ? items.first.unitPrice : 0.0,
        subtotal: subtotal,
        taxAmount: taxAmount,
        totalPrice: totalPrice,
        items: items,
        date: DateTime.now(),
      );
    });

    return generatedSale;
  }

  // ─── Orders Inbox (Klinixy Quick-Commerce) ──────────────────────────────
  Stream<List<KlinixyOrder>> getOrdersStream() {
    return _db
        .collection('orders')
        .where('pharmacyId', isEqualTo: pharmacyId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => KlinixyOrder.fromDoc(doc))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  Future<void> acceptOrder({
    required KlinixyOrder order,
    required String byUid,
  }) async {
    final orderRef = _db.collection('orders').doc(order.id);

    await _db.runTransaction((transaction) async {
      // 1. Verify and check stock for each item
      for (final item in order.items) {
        final stockDocRef =
            _rootPharmacyRef.collection('stock').doc(item.medicineId);
        final stockSnap = await transaction.get(stockDocRef);
        if (stockSnap.exists && stockSnap.data() != null) {
          final currentStock =
              ((stockSnap.data()!['stock'] ?? 0) as num).toInt();
          if (currentStock < item.quantity) {
            throw Exception(
                'Insufficient stock for ${item.medicineName}. Available: $currentStock, Required: ${item.quantity}');
          }
        }
      }

      // 2. Atomically decrement stock
      for (final item in order.items) {
        final stockDocRef =
            _rootPharmacyRef.collection('stock').doc(item.medicineId);
        transaction.update(stockDocRef, {
          'stock': FieldValue.increment(-item.quantity),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': byUid,
        });

        final nestedStockDocRef =
            _nestedPharmacyRef.collection('stock').doc(item.medicineId);
        transaction.update(nestedStockDocRef, {
          'stock': FieldValue.increment(-item.quantity),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': byUid,
        });
      }

      // 3. Update order state
      transaction.update(orderRef, {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': 'accepted',
            'at': Timestamp.now(),
            'by': byUid,
          }
        ]),
      });
    });
  }

  Future<void> rejectOrder({
    required String orderId,
    required String reason,
    required String byUid,
  }) async {
    if (reason.trim().isEmpty) {
      throw Exception('A mandatory reason is required to reject an order.');
    }
    await _db.collection('orders').doc(orderId).update({
      'status': 'rejected',
      'rejectionReason': reason.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'statusHistory': FieldValue.arrayUnion([
        {
          'status': 'rejected',
          'at': Timestamp.now(),
          'by': byUid,
          'reason': reason.trim(),
        }
      ]),
    });
  }

  Future<void> markOrderPacked({
    required String orderId,
    required String byUid,
  }) async {
    await _db.collection('orders').doc(orderId).update({
      'status': 'packed',
      'updatedAt': FieldValue.serverTimestamp(),
      'statusHistory': FieldValue.arrayUnion([
        {
          'status': 'packed',
          'at': Timestamp.now(),
          'by': byUid,
        }
      ]),
    });
  }

  // ─── Suppliers (P9 Inventory Depth) ─────────────────────────────────────────
  Stream<List<Supplier>> getSuppliersStream() {
    return _rootPharmacyRef
        .collection('suppliers')
        .orderBy('name')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Supplier.fromDoc(d)).toList());
  }

  Future<void> addSupplier(Supplier supplier) async {
    final docRef = _rootPharmacyRef.collection('suppliers').doc();
    await docRef.set(supplier.toMap());
  }

  // ─── Purchase Orders (P9 Inventory Depth) ───────────────────────────────────
  Stream<List<PurchaseOrder>> getPurchaseOrdersStream() {
    return _rootPharmacyRef
        .collection('purchaseOrders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PurchaseOrder.fromDoc(d)).toList());
  }

  Future<void> createPurchaseOrder(PurchaseOrder po) async {
    final docRef = _rootPharmacyRef.collection('purchaseOrders').doc();
    await docRef.set(po.toMap());
  }

  Future<void> receivePurchaseOrder({
    required String poId,
    required String byUid,
  }) async {
    final poRef = _rootPharmacyRef.collection('purchaseOrders').doc(poId);

    await _db.runTransaction((transaction) async {
      final poSnap = await transaction.get(poRef);
      if (!poSnap.exists || poSnap.data() == null) {
        throw Exception('Purchase order not found.');
      }
      final po = PurchaseOrder.fromDoc(poSnap);
      if (po.isReceived) {
        throw Exception('Purchase order is already received.');
      }

      // Increment stock for each item & update batch/expiry
      for (final item in po.items) {
        final stockRef = _rootPharmacyRef.collection('stock').doc(item.medicineId);
        final nestedRef = _nestedPharmacyRef.collection('stock').doc(item.medicineId);

        transaction.update(stockRef, {
          'stock': FieldValue.increment(item.quantity),
          'batchNo': item.batchNo,
          'expiryDate': Timestamp.fromDate(item.expiryDate),
          'costPrice': item.unitCost,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': byUid,
        });

        transaction.update(nestedRef, {
          'stock': FieldValue.increment(item.quantity),
          'batchNo': item.batchNo,
          'expiryDate': Timestamp.fromDate(item.expiryDate),
          'costPrice': item.unitCost,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': byUid,
        });
      }

      // Mark PO as received
      transaction.update(poRef, {
        'status': 'received',
        'receivedAt': FieldValue.serverTimestamp(),
        'receivedBy': byUid,
      });
    });
  }

  // ─── Returns & Refunds (P9 Inventory Depth) ─────────────────────────────────
  Future<void> processReturn({
    required Sale originalSale,
    required List<SaleItem> returnedItems,
    required String reason,
    required String byUid,
  }) async {
    if (returnedItems.isEmpty) {
      throw Exception('No items selected for return.');
    }

    final refundSubtotal = returnedItems.fold<double>(
        0, (sum, i) => sum + (i.unitPrice * i.quantity));
    final refundTax = originalSale.isPakka
        ? returnedItems.fold<double>(
            0, (sum, i) => sum + (i.unitPrice * i.quantity * (i.gstSlab / 100.0)))
        : 0.0;
    final refundTotal = refundSubtotal + refundTax;

    await _db.runTransaction((transaction) async {
      // 1. Restock returned items
      for (final item in returnedItems) {
        final stockRef = _rootPharmacyRef.collection('stock').doc(item.medicineId);
        final nestedRef = _nestedPharmacyRef.collection('stock').doc(item.medicineId);

        transaction.update(stockRef, {
          'stock': FieldValue.increment(item.quantity),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': byUid,
        });

        transaction.update(nestedRef, {
          'stock': FieldValue.increment(item.quantity),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': byUid,
        });
      }

      // 2. Create negative sale record for audit reconciliation
      final refundRef = _rootPharmacyRef.collection('sales').doc();
      final refundData = {
        'billNo': 'REF-${originalSale.billNo}',
        'originalBillNo': originalSale.billNo,
        'billType': 'refund',
        'customerName': originalSale.customerName,
        'items': returnedItems.map((i) => i.toMap()).toList(),
        'quantity': returnedItems.fold<int>(0, (sum, i) => sum + i.quantity),
        'medicineName': returnedItems.first.medicineName,
        'medicineId': returnedItems.first.medicineId,
        'unitPrice': returnedItems.first.unitPrice,
        'subtotal': -refundSubtotal,
        'taxAmount': -refundTax,
        'totalPrice': -refundTotal,
        'date': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': byUid,
        'reason': reason,
      };

      transaction.set(refundRef, refundData);
      final nestedRefundRef = _nestedPharmacyRef.collection('sales').doc(refundRef.id);
      transaction.set(nestedRefundRef, refundData);
    });
  }
}

// ─── Database service provider ───────────────────────────────────────────────
final databaseServiceProvider = Provider<DatabaseService?>((ref) {
  final loc = ref.watch(pharmacyLocationFutureProvider).valueOrNull;
  if (loc == null) return null;
  return DatabaseService(location: loc);
});
