import 'package:cloud_firestore/cloud_firestore.dart';

class Supplier {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String gstin;
  final String address;
  final DateTime createdAt;

  Supplier({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.gstin = '',
    this.address = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Supplier.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Supplier(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      gstin: data['gstin'] ?? '',
      address: data['address'] ?? '',
      createdAt: data['createdAt'] != null && data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'email': email,
        'gstin': gstin,
        'address': address,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
