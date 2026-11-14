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

  /// Firestore path: cities/{city}/areas/{area}/pharmacies/{uid}
  static String firestorePath(String city, String area, String uid) =>
      'cities/$city/areas/$area/pharmacies/$uid';

  /// Slug-safe key for city / area (lowercase, spaces → underscores)
  static String toKey(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  factory PharmacyProfile.fromMap(Map<String, dynamic> data, String uid) {
    return PharmacyProfile(
      uid: uid,
      email: data['email'] ?? '',
      pharmacyName: data['name'] ?? data['pharmacyName'] ?? '',
      handlerName: data['ownerName'] ?? data['handlerName'] ?? '',
      city: data['city'] ?? data['cityId'] ?? '',
      area: data['area'] ?? data['areaId'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'pharmacyName': pharmacyName,
        'name': pharmacyName,
        'handlerName': handlerName,
        'ownerName': handlerName,
        'city': city,
        'cityId': toKey(city),
        'area': area,
        'areaId': toKey(area),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.now(),
      };
}
