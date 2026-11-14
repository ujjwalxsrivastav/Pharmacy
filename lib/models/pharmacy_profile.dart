import 'package:cloud_firestore/cloud_firestore.dart';

class PharmacyProfile {
  final String uid;
  final String email;
  final String pharmacyName;
  final String handlerName;
  final String city;
  final String area;
  final DateTime createdAt;

  PharmacyProfile({
    required this.uid,
    required this.email,
    required this.pharmacyName,
    required this.handlerName,
    required this.city,
    required this.area,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PharmacyProfile.fromMap(Map<String, dynamic> data, String uid) {
    return PharmacyProfile(
      uid: uid,
      email: data['email'] ?? '',
      pharmacyName: data['pharmacyName'] ?? '',
      handlerName: data['handlerName'] ?? '',
      city: data['city'] ?? '',
      area: data['area'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'pharmacyName': pharmacyName,
      'handlerName': handlerName,
      'city': city,
      'area': area,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

