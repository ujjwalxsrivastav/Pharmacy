import 'package:cloud_firestore/cloud_firestore.dart';

/// Item in a Klinixy quick-commerce order.
class OrderItem {
  final String medicineId;
  final String medicineName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  OrderItem({
    required this.medicineId,
    required this.medicineName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      medicineId: data['medicineId'] ?? '',
      medicineName: data['medicineName'] ?? '',
      quantity: ((data['quantity'] ?? data['qty'] ?? 1) as num).toInt(),
      unitPrice: ((data['unitPrice'] ?? 0.0) as num).toDouble(),
      totalPrice: ((data['totalPrice'] ?? 0.0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'medicineId': medicineId,
        'medicineName': medicineName,
        'quantity': quantity,
        'qty': quantity,
        'unitPrice': unitPrice,
        'totalPrice': totalPrice,
      };
}

/// History log entry for order status changes.
class OrderStatusEntry {
  final String status;
  final DateTime at;
  final String by;
  final String? reason;

  OrderStatusEntry({
    required this.status,
    required this.at,
    required this.by,
    this.reason,
  });

  factory OrderStatusEntry.fromMap(Map<String, dynamic> data) {
    return OrderStatusEntry(
      status: data['status'] ?? '',
      at: data['at'] != null && data['at'] is Timestamp
          ? (data['at'] as Timestamp).toDate()
          : DateTime.now(),
      by: data['by'] ?? '',
      reason: data['reason'],
    );
  }

  Map<String, dynamic> toMap() => {
        'status': status,
        'at': Timestamp.fromDate(at),
        'by': by,
        if (reason != null) 'reason': reason,
      };
}

/// Klinixy quick-commerce order contract (§5 of Deep-Dive specification).
/// Connects Customer App -> Pharmacy App (this) -> Rider App -> Admin Panel.
class KlinixyOrder {
  final String id;
  final String pharmacyId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final GeoPoint? deliveryLocation;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String paymentMethod;
  final String paymentStatus;
  final String status; // placed, accepted, packed, rider_assigned, picked, delivered, rejected, cancelled
  final String? rejectionReason;
  final String? prescriptionUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderStatusEntry> statusHistory;

  KlinixyOrder({
    required this.id,
    required this.pharmacyId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    this.deliveryLocation,
    required this.items,
    required this.subtotal,
    this.deliveryFee = 0.0,
    required this.total,
    this.paymentMethod = 'COD',
    this.paymentStatus = 'pending',
    required this.status,
    this.rejectionReason,
    this.prescriptionUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<OrderStatusEntry>? statusHistory,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        statusHistory = statusHistory ?? [];

  bool get isPlaced => status == 'placed';
  bool get isAccepted => status == 'accepted';
  bool get isPacked => status == 'packed';
  bool get isRiderAssigned => status == 'rider_assigned';
  bool get isPicked => status == 'picked';
  bool get isDelivered => status == 'delivered';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';

  factory KlinixyOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawItems = data['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    final rawHistory = data['statusHistory'] as List<dynamic>? ?? [];
    final historyList = rawHistory
        .map((e) => OrderStatusEntry.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    return KlinixyOrder(
      id: doc.id,
      pharmacyId: data['pharmacyId'] ?? '',
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? 'Customer',
      customerPhone: data['customerPhone'] ?? '',
      deliveryAddress: data['deliveryAddress'] ?? '',
      deliveryLocation: data['deliveryLocation'] is GeoPoint
          ? (data['deliveryLocation'] as GeoPoint)
          : null,
      items: itemsList,
      subtotal: ((data['subtotal'] ?? 0.0) as num).toDouble(),
      deliveryFee: ((data['deliveryFee'] ?? 0.0) as num).toDouble(),
      total: ((data['total'] ?? 0.0) as num).toDouble(),
      paymentMethod: data['paymentMethod'] ?? 'COD',
      paymentStatus: data['paymentStatus'] ?? 'pending',
      status: data['status'] ?? 'placed',
      rejectionReason: data['rejectionReason'],
      prescriptionUrl: data['prescriptionUrl'],
      createdAt: data['createdAt'] != null && data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null && data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      statusHistory: historyList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pharmacyId': pharmacyId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      if (deliveryLocation != null) 'deliveryLocation': deliveryLocation,
      'items': items.map((i) => i.toMap()).toList(),
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'total': total,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'status': status,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (prescriptionUrl != null) 'prescriptionUrl': prescriptionUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'statusHistory': statusHistory.map((h) => h.toMap()).toList(),
    };
  }
}

