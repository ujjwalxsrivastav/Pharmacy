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
  final String docId; // e.g. "garhwal-medical-store"
  final String path; // e.g. "pharmacies/garhwal-medical-store"
  final String city; // e.g. "Dehradun"
  final String area; // e.g. "Selaqui"
  final String cityId; // e.g. "dehradun"
  final String areaId; // e.g. "selaqui"
  final String pharmacyName; // e.g. "Garhwal Medical Store"
  final String? legacyDocId; // e.g. "CXnweu0t8raPUdhwReZsLeYtFt13"

  const PharmacyLocation({
    required this.docId,
    required this.path,
    required this.city,
    required this.area,
    String? cityId,
    String? areaId,
    String? pharmacyName,
    this.legacyDocId,
  })  : cityId = cityId ?? 'dehradun',
        areaId = areaId ?? 'selaqui',
        pharmacyName = pharmacyName ?? '';
}

class DatabaseService {
  final FirebaseFirestore? _firestore;
  final PharmacyLocation location;

  DatabaseService({required this.location, FirebaseFirestore? firestore})
      : _firestore = firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

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

  /// Returns all document references where this pharmacy's data and stock must reside:
  /// 1. Root pharmacies collection (e.g. pharmacies/garhwal-medical-store)
  /// 2. Direct resolved path (location.path)
  /// 3. Hierarchical cities/city/areas/area/pharmacies/slug (lowercase)
  /// 4. Hierarchical exact case (e.g. areas/Selaqui)
  /// 5. Root areas collection (e.g. areas/Selaqui/pharmacies/slug)
  /// 6. Legacy doc ID (if migrated from glibberish UID)
  List<DocumentReference> get _allPharmacyDocRefs {
    final refs = <DocumentReference>[];
    final seen = <String>{};

    void addRef(DocumentReference ref) {
      if (seen.add(ref.path)) {
        refs.add(ref);
      }
    }

    addRef(_rootPharmacyRef);

    if (location.path.isNotEmpty) {
      try {
        addRef(_db.doc(location.path));
      } catch (_) {}
    }

    final cKey = location.cityId.isNotEmpty
        ? location.cityId
        : PharmacyProfile.toKey(location.city);
    final aKey = location.areaId.isNotEmpty
        ? location.areaId
        : PharmacyProfile.toKey(location.area);

    if (cKey.isNotEmpty && aKey.isNotEmpty) {
      addRef(_db
          .collection('cities')
          .doc(cKey)
          .collection('areas')
          .doc(aKey)
          .collection('pharmacies')
          .doc(location.docId));
    }

    final rawArea = location.area.trim();
    if (rawArea.isNotEmpty && rawArea != aKey && cKey.isNotEmpty) {
      addRef(_db
          .collection('cities')
          .doc(cKey)
          .collection('areas')
          .doc(rawArea)
          .collection('pharmacies')
          .doc(location.docId));
    }

    if (rawArea.isNotEmpty) {
      addRef(_db
          .collection('areas')
          .doc(rawArea)
          .collection('pharmacies')
          .doc(location.docId));
    }
    if (aKey.isNotEmpty && aKey != rawArea) {
      addRef(_db
          .collection('areas')
          .doc(aKey)
          .collection('pharmacies')
          .doc(location.docId));
    }

    if (location.legacyDocId != null &&
        location.legacyDocId!.isNotEmpty &&
        location.legacyDocId != location.docId) {
      addRef(_db.collection('pharmacies').doc(location.legacyDocId!));
      if (cKey.isNotEmpty && aKey.isNotEmpty) {
        addRef(_db
            .collection('cities')
            .doc(cKey)
            .collection('areas')
            .doc(aKey)
            .collection('pharmacies')
            .doc(location.legacyDocId!));
      }
      if (rawArea.isNotEmpty && rawArea != aKey && cKey.isNotEmpty) {
        addRef(_db
            .collection('cities')
            .doc(cKey)
            .collection('areas')
            .doc(rawArea)
            .collection('pharmacies')
            .doc(location.legacyDocId!));
      }
      if (rawArea.isNotEmpty) {
        addRef(_db
            .collection('areas')
            .doc(rawArea)
            .collection('pharmacies')
            .doc(location.legacyDocId!));
      }
    }

    return refs;
  }

  // ─── Medicines ────────────────────────────────────────────────────────────
  Stream<List<Medicine>> getMedicinesStream() {
    return _rootPharmacyRef
        .collection('stock')
        .orderBy('name')
        .snapshots()
        .asyncMap((rootSnap) async {
      final medicinesMap = <String, Medicine>{};

      for (final doc in rootSnap.docs) {
        medicinesMap[doc.id] = Medicine.fromMap(doc.data(), doc.id);
      }

      // Check all other mirror locations for existing medicines to cross-backfill
      for (final pRef in _allPharmacyDocRefs) {
        if (pRef.path == _rootPharmacyRef.path) continue;
        try {
          final snap = await pRef.collection('stock').get();
          for (final doc in snap.docs) {
            if (!medicinesMap.containsKey(doc.id)) {
              final med = Medicine.fromMap(doc.data(), doc.id);
              medicinesMap[doc.id] = med;
              _rootPharmacyRef
                  .collection('stock')
                  .doc(doc.id)
                  .set(doc.data(), SetOptions(merge: true))
                  .catchError((_) {});
              _rootPharmacyRef
                  .collection('medicines')
                  .doc(doc.id)
                  .set(doc.data(), SetOptions(merge: true))
                  .catchError((_) {});
            }
          }
        } catch (_) {}
      }

      final medicines = medicinesMap.values.toList();
      medicines.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      for (final med in medicines) {
        _syncMedicineToEcosystem(med.id, med).catchError((_) {});
        for (final pRef in _allPharmacyDocRefs) {
          if (pRef.path != _rootPharmacyRef.path) {
            pRef
                .collection('stock')
                .doc(med.id)
                .set(med.toMap(), SetOptions(merge: true))
                .catchError((_) {});
            pRef
                .collection('medicines')
                .doc(med.id)
                .set(med.toMap(), SetOptions(merge: true))
                .catchError((_) {});
          }
        }
      }

      return medicines;
    });
  }

  String get pharmacyName => location.pharmacyName.isNotEmpty
      ? location.pharmacyName
      : location.docId;

  static String slugify(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Map<String, dynamic> buildEcosystemStockPayload({
    required String id,
    required Medicine medicine,
    required String slug,
  }) {
    final cleanName = medicine.name.trim();
    final brandOrVerified = medicine.manufacturer.trim().isNotEmpty
        ? medicine.manufacturer.trim()
        : 'Klinixy Verified';
    final genericOrName = medicine.genericName.trim().isNotEmpty
        ? medicine.genericName.trim()
        : cleanName;
    final catRaw = medicine.category.trim().isNotEmpty
        ? medicine.category.trim()
        : 'Medicines';
    final catSlug = slugify(catRaw).isNotEmpty ? slugify(catRaw) : 'medicines';
    final catName = catRaw.isNotEmpty
        ? '${catRaw[0].toUpperCase()}${catRaw.substring(1)}'
        : 'Medicines';

    final price = medicine.price;
    final mrp = medicine.costPrice > 0 && medicine.costPrice > price
        ? (medicine.costPrice * 1.15).roundToDouble()
        : (price > 0 ? (price * 1.1).roundToDouble() : 0.0);
    final discountPercent = mrp > price && mrp > 0
        ? (((mrp - price) / mrp) * 100).round()
        : 0;

    final inStock = medicine.stock > 0;
    final resolvedPharmacyName = pharmacyName;
    final resolvedCity = location.city.isNotEmpty ? location.city : 'Dehradun';
    final resolvedArea = location.area.isNotEmpty ? location.area : 'Selaqui';
    final desc =
        '$cleanName available at $resolvedPharmacyName, $resolvedArea, $resolvedCity. Express delivery in 120 minutes.';

    final tags = <String>[
      catName,
      'Dehradun Express',
      '120 Mins Delivery',
      cleanName,
      if (medicine.manufacturer.trim().isNotEmpty) medicine.manufacturer.trim(),
      if (resolvedPharmacyName.isNotEmpty) resolvedPharmacyName,
      if (resolvedArea.isNotEmpty) resolvedArea,
    ];

    return {
      'id': id,
      'medicineId': id,
      'productId': id,
      'name': cleanName,
      'medicineName': cleanName,
      'medicine_name': cleanName,
      'productName': cleanName,
      'title': cleanName,
      'brand': brandOrVerified,
      'brandName': brandOrVerified,
      'manufacturer': brandOrVerified,
      'company': brandOrVerified,
      'composition': genericOrName,
      'salt': genericOrName,
      'genericName': genericOrName,
      'generic_name': genericOrName,
      'category': catSlug,
      'categoryId': catSlug,
      'categoryName': catName,
      'type': catSlug,
      'price': price,
      'sellingPrice': price,
      'rate': price,
      'discountedPrice': price,
      'mrp': mrp > 0 ? mrp : price,
      'marketPrice': mrp > 0 ? mrp : price,
      'originalPrice': mrp > 0 ? mrp : price,
      'costPrice': medicine.costPrice,
      'discount': discountPercent,
      'discountPercent': discountPercent,
      'discountPercentage': discountPercent,
      'stock': medicine.stock,
      'stockCount': medicine.stock,
      'stock_count': medicine.stock,
      'quantity': medicine.stock,
      'qty': medicine.stock,
      'units': medicine.stock,
      'totalStock': medicine.stock,
      'inStock': inStock,
      'in_stock': inStock,
      'available': inStock,
      'isAvailable': inStock,
      'isActive': true,
      'requiresPrescription': medicine.rxRequired,
      'isPrescriptionRequired': medicine.rxRequired,
      'prescriptionRequired': medicine.rxRequired,
      'rx': medicine.rxRequired,
      'rxRequired': medicine.rxRequired,
      'scheduleH': medicine.rxRequired,
      'rating': 4.8,
      'reviewCount': 25,
      'pharmacyId': location.docId,
      'pharmacyName': resolvedPharmacyName,
      'cityId': location.cityId.isNotEmpty ? location.cityId : 'dehradun',
      'areaId': location.areaId.isNotEmpty ? location.areaId : 'selaqui',
      'cityName': resolvedCity,
      'areaName': resolvedArea,
      'description': desc,
      'about': desc,
      'desc': desc,
      'hsn': medicine.hsn,
      'gstSlab': medicine.gstSlab,
      'batchNo': medicine.batchNo,
      'rackShelf': medicine.rackShelf,
      'expiryDate': Timestamp.fromDate(medicine.expiryDate),
      'imageUrls': <String>[],
      'imageUrl': '',
      'tags': tags,
      'uses': <String>['General Healthcare', 'Prescription Care'],
      'sideEffects': <String>[
        'Consult doctor if symptoms persist',
        'Take as directed by physician'
      ],
      'slug': slug,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _syncMedicineToEcosystem(String docId, Medicine medicine) async {
    try {
      final slugRaw = slugify('${medicine.name} ${medicine.manufacturer}'.trim());
      final slug = slugRaw.isNotEmpty ? slugRaw : slugify(medicine.name);
      final payload = buildEcosystemStockPayload(
        id: docId,
        medicine: medicine,
        slug: slug,
      );

      final batch = _db.batch();

      // Mirror to all pharmacy references: stock & medicines subcollections
      for (final pRef in _allPharmacyDocRefs) {
        batch.set(
          pRef.collection('stock').doc(docId),
          medicine.toMap(),
          SetOptions(merge: true),
        );
        batch.set(
          pRef.collection('medicines').doc(docId),
          medicine.toMap(),
          SetOptions(merge: true),
        );
      }

      // Root stock & products indexed by docId
      batch.set(
        _db.collection('stock').doc(docId),
        payload,
        SetOptions(merge: true),
      );
      batch.set(
        _db.collection('products').doc(docId),
        payload,
        SetOptions(merge: true),
      );

      // Root stock & products indexed by slug
      if (slug.isNotEmpty) {
        final slugPayload = Map<String, dynamic>.from(payload)
          ..['id'] = slug
          ..['medicineId'] = slug
          ..['productId'] = slug;
        batch.set(
          _db.collection('stock').doc(slug),
          slugPayload,
          SetOptions(merge: true),
        );
        batch.set(
          _db.collection('products').doc(slug),
          slugPayload,
          SetOptions(merge: true),
        );

        // Also pharmacy-scoped slug doc
        if (location.docId.isNotEmpty) {
          final scopedId = '${location.docId}_$slug';
          batch.set(
            _db.collection('stock').doc(scopedId),
            slugPayload,
            SetOptions(merge: true),
          );
          batch.set(
            _db.collection('products').doc(scopedId),
            slugPayload,
            SetOptions(merge: true),
          );
        }
      }

      await batch.commit();
    } catch (_) {}
  }

  Future<int> syncAllMedicinesToEcosystem() async {
    int syncedCount = 0;
    try {
      final snap = await _rootPharmacyRef.collection('stock').get();
      for (final doc in snap.docs) {
        final med = Medicine.fromMap(doc.data(), doc.id);
        await _syncMedicineToEcosystem(doc.id, med);
        syncedCount++;
      }
    } catch (_) {}
    return syncedCount;
  }

  Future<void> addMedicine(Medicine medicine) async {
    final docRef = _rootPharmacyRef.collection('stock').doc();
    final medId = docRef.id;
    final medicineWithId = medicine.copyWith(id: medId);
    final data = medicineWithId.toMap();

    // 1. Write to all pharmacy doc mirrors in both 'stock' and 'medicines' subcollections
    for (final pRef in _allPharmacyDocRefs) {
      try {
        await pRef.collection('stock').doc(medId).set(data, SetOptions(merge: true));
        await pRef.collection('medicines').doc(medId).set(data, SetOptions(merge: true));
      } catch (_) {}
    }

    // 2. Sync to ecosystem (root 'stock' and 'products' collections for Klinixy customer app)
    await _syncMedicineToEcosystem(medId, medicineWithId);
  }

  Future<void> updateMedicine(String id, Map<String, dynamic> data) async {
    for (final pRef in _allPharmacyDocRefs) {
      try {
        await pRef.collection('stock').doc(id).set(data, SetOptions(merge: true));
        await pRef.collection('medicines').doc(id).set(data, SetOptions(merge: true));
      } catch (_) {}
    }

    try {
      // Re-read full document to sync complete updated state to ecosystem
      final updatedSnap = await _rootPharmacyRef.collection('stock').doc(id).get();
      if (updatedSnap.exists && updatedSnap.data() != null) {
        final updatedMed = Medicine.fromMap(updatedSnap.data()!, id);
        await _syncMedicineToEcosystem(id, updatedMed);
      }
    } catch (_) {}
  }

  Future<void> deleteMedicine(String id) async {
    for (final pRef in _allPharmacyDocRefs) {
      try {
        await pRef.collection('stock').doc(id).delete();
        await pRef.collection('medicines').doc(id).delete();
      } catch (_) {}
    }

    try {
      final deactivateData = {
        'isActive': false,
        'inStock': false,
        'in_stock': false,
        'available': false,
        'isAvailable': false,
        'stock': 0,
        'stockCount': 0,
        'quantity': 0,
        'qty': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('stock').doc(id).set(deactivateData, SetOptions(merge: true));
      await _db.collection('products').doc(id).set(deactivateData, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> adjustStock(String medicineId, int delta) async {
    final updateData = {'stock': FieldValue.increment(delta)};
    for (final pRef in _allPharmacyDocRefs) {
      try {
        await pRef.collection('stock').doc(medicineId).update(updateData);
        await pRef.collection('medicines').doc(medicineId).set(updateData, SetOptions(merge: true));
      } catch (_) {}
    }

    try {
      final ecosystemData = {
        'stock': FieldValue.increment(delta),
        'stockCount': FieldValue.increment(delta),
        'stock_count': FieldValue.increment(delta),
        'quantity': FieldValue.increment(delta),
        'qty': FieldValue.increment(delta),
        'units': FieldValue.increment(delta),
        'totalStock': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('stock').doc(medicineId).set(ecosystemData, SetOptions(merge: true));
      await _db.collection('products').doc(medicineId).set(ecosystemData, SetOptions(merge: true));

      // Check new stock level to update inStock boolean flag
      final snap = await _rootPharmacyRef.collection('stock').doc(medicineId).get();
      if (snap.exists && snap.data() != null) {
        final currentStock = ((snap.data()!['stock'] ?? 0) as num).toInt();
        final inStock = currentStock > 0;
        final statusUpdate = {
          'inStock': inStock,
          'in_stock': inStock,
          'available': inStock,
          'isAvailable': inStock,
        };
        await _db.collection('stock').doc(medicineId).update(statusUpdate).catchError((_) {});
        await _db.collection('products').doc(medicineId).update(statusUpdate).catchError((_) {});
      }
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

        final medDocRef = _rootPharmacyRef.collection('medicines').doc(item.medicineId);
        transaction.set(medDocRef, {
          'stock': FieldValue.increment(-item.quantity),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final nestedStockDocRef = _nestedPharmacyRef.collection('stock').doc(item.medicineId);
        transaction.set(nestedStockDocRef, {
          'stock': FieldValue.increment(-item.quantity),
          'updatedAt': FieldValue.serverTimestamp(),
          if (updatedByUid != null) 'updatedBy': updatedByUid,
        }, SetOptions(merge: true));

        final nestedMedDocRef = _nestedPharmacyRef.collection('medicines').doc(item.medicineId);
        transaction.set(nestedMedDocRef, {
          'stock': FieldValue.increment(-item.quantity),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final ecoDelta = {
          'stock': FieldValue.increment(-item.quantity),
          'stockCount': FieldValue.increment(-item.quantity),
          'stock_count': FieldValue.increment(-item.quantity),
          'quantity': FieldValue.increment(-item.quantity),
          'qty': FieldValue.increment(-item.quantity),
          'units': FieldValue.increment(-item.quantity),
          'totalStock': FieldValue.increment(-item.quantity),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        transaction.set(_db.collection('stock').doc(item.medicineId), ecoDelta, SetOptions(merge: true));
        transaction.set(_db.collection('products').doc(item.medicineId), ecoDelta, SetOptions(merge: true));
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
        final medRef = _rootPharmacyRef.collection('medicines').doc(item.medicineId);
        final nestedRef = _nestedPharmacyRef.collection('stock').doc(item.medicineId);
        final nestedMedRef = _nestedPharmacyRef.collection('medicines').doc(item.medicineId);

        final updateData = {
          'stock': FieldValue.increment(item.quantity),
          'batchNo': item.batchNo,
          'expiryDate': Timestamp.fromDate(item.expiryDate),
          'costPrice': item.unitCost,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': byUid,
        };

        transaction.update(stockRef, updateData);
        transaction.set(medRef, updateData, SetOptions(merge: true));
        transaction.set(nestedRef, updateData, SetOptions(merge: true));
        transaction.set(nestedMedRef, updateData, SetOptions(merge: true));

        final ecoInc = {
          'stock': FieldValue.increment(item.quantity),
          'stockCount': FieldValue.increment(item.quantity),
          'stock_count': FieldValue.increment(item.quantity),
          'quantity': FieldValue.increment(item.quantity),
          'qty': FieldValue.increment(item.quantity),
          'units': FieldValue.increment(item.quantity),
          'totalStock': FieldValue.increment(item.quantity),
          'inStock': true,
          'in_stock': true,
          'available': true,
          'isAvailable': true,
          'batchNo': item.batchNo,
          'expiryDate': Timestamp.fromDate(item.expiryDate),
          'costPrice': item.unitCost,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        transaction.set(_db.collection('stock').doc(item.medicineId), ecoInc, SetOptions(merge: true));
        transaction.set(_db.collection('products').doc(item.medicineId), ecoInc, SetOptions(merge: true));
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
        final medRef = _rootPharmacyRef.collection('medicines').doc(item.medicineId);
        final nestedRef = _nestedPharmacyRef.collection('stock').doc(item.medicineId);
        final nestedMedRef = _nestedPharmacyRef.collection('medicines').doc(item.medicineId);

        final restockData = {
          'stock': FieldValue.increment(item.quantity),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': byUid,
        };

        transaction.update(stockRef, restockData);
        transaction.set(medRef, restockData, SetOptions(merge: true));
        transaction.set(nestedRef, restockData, SetOptions(merge: true));
        transaction.set(nestedMedRef, restockData, SetOptions(merge: true));

        final ecoInc = {
          'stock': FieldValue.increment(item.quantity),
          'stockCount': FieldValue.increment(item.quantity),
          'stock_count': FieldValue.increment(item.quantity),
          'quantity': FieldValue.increment(item.quantity),
          'qty': FieldValue.increment(item.quantity),
          'units': FieldValue.increment(item.quantity),
          'totalStock': FieldValue.increment(item.quantity),
          'inStock': true,
          'in_stock': true,
          'available': true,
          'isAvailable': true,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        transaction.set(_db.collection('stock').doc(item.medicineId), ecoInc, SetOptions(merge: true));
        transaction.set(_db.collection('products').doc(item.medicineId), ecoInc, SetOptions(merge: true));
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
