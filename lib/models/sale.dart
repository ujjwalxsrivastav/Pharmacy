import 'package:cloud_firestore/cloud_firestore.dart';

class Sale {
  final String id;
  final String medicineId;
  final String medicineName;
  final String customerName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final DateTime date;

  Sale({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    this.customerName = 'Walk-in',
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  factory Sale.fromMap(Map<String, dynamic> data, String documentId) {
    return Sale(
      id: documentId,
      medicineId: data['medicineId'] ?? '',
      medicineName: data['medicineName'] ?? '',
      customerName: data['customerName'] ?? 'Walk-in',
      quantity: data['quantity'] ?? 0,
      unitPrice: (data['unitPrice'] ?? 0.0).toDouble(),
      totalPrice: (data['totalPrice'] ?? 0.0).toDouble(),
      date: data['date'] != null
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medicineId': medicineId,
      'medicineName': medicineName,
      'customerName': customerName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'date': Timestamp.fromDate(date),
    };
  }
}
