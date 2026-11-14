import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseOrderItem {
  final String medicineId;
  final String medicineName;
  final String batchNo;
  final DateTime expiryDate;
  final int quantity;
  final double unitCost;
  final double totalCost;

  PurchaseOrderItem({
    required this.medicineId,
    required this.medicineName,
    required this.batchNo,
    required this.expiryDate,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
  });

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> data) {
    return PurchaseOrderItem(
      medicineId: data['medicineId'] ?? '',
      medicineName: data['medicineName'] ?? '',
      batchNo: data['batchNo'] ?? '',
      expiryDate: data['expiryDate'] != null && data['expiryDate'] is Timestamp
          ? (data['expiryDate'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(days: 365)),
      quantity: ((data['quantity'] ?? data['qty'] ?? 1) as num).toInt(),
      unitCost: ((data['unitCost'] ?? 0.0) as num).toDouble(),
      totalCost: ((data['totalCost'] ?? 0.0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'medicineId': medicineId,
        'medicineName': medicineName,
        'batchNo': batchNo,
        'expiryDate': Timestamp.fromDate(expiryDate),
        'quantity': quantity,
        'unitCost': unitCost,
        'totalCost': totalCost,
      };
}

class PurchaseOrder {
  final String id;
  final String poNumber; // e.g. PO-2026-0001
  final String supplierId;
  final String supplierName;
  final List<PurchaseOrderItem> items;
  final double totalAmount;
  final String status; // 'created' or 'received'
  final DateTime createdAt;
  final DateTime? receivedAt;
  final String? receivedBy;

  PurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.supplierId,
    required this.supplierName,
    required this.items,
    required this.totalAmount,
    this.status = 'created',
    DateTime? createdAt,
    this.receivedAt,
    this.receivedBy,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isReceived => status == 'received';

  factory PurchaseOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawItems = data['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((e) => PurchaseOrderItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    return PurchaseOrder(
      id: doc.id,
      poNumber: data['poNumber'] ?? doc.id,
      supplierId: data['supplierId'] ?? '',
      supplierName: data['supplierName'] ?? 'Supplier',
      items: itemsList,
      totalAmount: ((data['totalAmount'] ?? 0.0) as num).toDouble(),
      status: data['status'] ?? 'created',
      createdAt: data['createdAt'] != null && data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      receivedAt: data['receivedAt'] != null && data['receivedAt'] is Timestamp
          ? (data['receivedAt'] as Timestamp).toDate()
          : null,
      receivedBy: data['receivedBy'],
    );
  }

  Map<String, dynamic> toMap() => {
        'poNumber': poNumber,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'items': items.map((i) => i.toMap()).toList(),
        'totalAmount': totalAmount,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        if (receivedAt != null) 'receivedAt': Timestamp.fromDate(receivedAt!),
        if (receivedBy != null) 'receivedBy': receivedBy,
      };
}
