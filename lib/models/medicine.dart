import 'package:cloud_firestore/cloud_firestore.dart';

class Medicine {
  final String id;
  final String name;
  final String genericName;
  final String category;
  final String manufacturer;
  final int stock;
  final int reorderLevel;
  final double price;
  final double costPrice;
  final DateTime expiryDate;
  final DateTime createdAt;

  Medicine({
    required this.id,
    required this.name,
    this.genericName = '',
    required this.category,
    this.manufacturer = '',
    required this.stock,
    this.reorderLevel = 10,
    required this.price,
    this.costPrice = 0.0,
    required this.expiryDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isLowStock => stock <= reorderLevel;
  bool get isExpired => expiryDate.isBefore(DateTime.now());
  bool get isExpiringSoon =>
      !isExpired &&
      expiryDate.isBefore(DateTime.now().add(const Duration(days: 30)));
  double get profitMargin =>
      costPrice > 0 ? ((price - costPrice) / costPrice * 100) : 0;

  factory Medicine.fromMap(Map<String, dynamic> data, String documentId) {
    return Medicine(
      id: documentId,
      name: data['name'] ?? '',
      genericName: data['genericName'] ?? '',
      category: data['category'] ?? 'Other',
      manufacturer: data['manufacturer'] ?? '',
      stock: data['stock'] ?? 0,
      reorderLevel: data['reorderLevel'] ?? 10,
      price: (data['price'] ?? 0.0).toDouble(),
      costPrice: (data['costPrice'] ?? 0.0).toDouble(),
      expiryDate: data['expiryDate'] != null
          ? (data['expiryDate'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(days: 365)),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'genericName': genericName,
      'category': category,
      'manufacturer': manufacturer,
      'stock': stock,
      'reorderLevel': reorderLevel,
      'price': price,
      'costPrice': costPrice,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Medicine copyWith({int? stock}) {
    return Medicine(
      id: id,
      name: name,
      genericName: genericName,
      category: category,
      manufacturer: manufacturer,
      stock: stock ?? this.stock,
      reorderLevel: reorderLevel,
      price: price,
      costPrice: costPrice,
      expiryDate: expiryDate,
      createdAt: createdAt,
    );
  }
}
