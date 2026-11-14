import 'package:cloud_firestore/cloud_firestore.dart';

class PharmacyProfile {
  final String uid;
  final String email;
  final String pharmacyName;
  final String handlerName;
  final String city;
  final String area;
  final GeoPoint? location;
  final String address;
  final String phone;
  final bool isOpen;
  final double deliveryRadiusKm;
  final String gstin;
  final DateTime? locationUpdatedAt;
  final String? locationUpdatedBy;
  final DateTime createdAt;

  PharmacyProfile({
    required this.uid,
    required this.email,
    required this.pharmacyName,
    required this.handlerName,
    required this.city,
    required this.area,
    this.location,
    this.address = '',
    this.phone = '',
    this.isOpen = true,
    this.deliveryRadiusKm = 5.0,
    this.gstin = '',
    this.locationUpdatedAt,
    this.locationUpdatedBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get hasLocation => location != null;
  double? get latitude => location?.latitude;
  double? get longitude => location?.longitude;

  /// Firestore path: cities/{city}/areas/{area}/pharmacies/{uid}
  static String firestorePath(String city, String area, String uid) =>
      'cities/$city/areas/$area/pharmacies/$uid';

  /// Slug-safe key for city / area (lowercase, spaces → underscores)
  static String toKey(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  factory PharmacyProfile.fromMap(Map<String, dynamic> data, String uid) {
    GeoPoint? loc;
    if (data['location'] is GeoPoint) {
      loc = data['location'] as GeoPoint;
    } else if (data['lat'] != null && data['lng'] != null) {
      loc = GeoPoint(
        (data['lat'] as num).toDouble(),
        (data['lng'] as num).toDouble(),
      );
    } else if (data['latitude'] != null && data['longitude'] != null) {
      loc = GeoPoint(
        (data['latitude'] as num).toDouble(),
        (data['longitude'] as num).toDouble(),
      );
    }

    return PharmacyProfile(
      uid: uid,
      email: data['email'] ?? '',
      pharmacyName: data['name'] ?? data['pharmacyName'] ?? '',
      handlerName: data['ownerName'] ?? data['handlerName'] ?? '',
      city: data['city'] ?? data['cityId'] ?? '',
      area: data['area'] ?? data['areaId'] ?? '',
      location: loc,
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
      isOpen: data['isOpen'] ?? true,
      deliveryRadiusKm: data['deliveryRadiusKm'] != null
          ? (data['deliveryRadiusKm'] as num).toDouble()
          : 5.0,
      gstin: data['gstin'] ?? '',
      locationUpdatedAt: data['locationUpdatedAt'] != null
          ? (data['locationUpdatedAt'] is Timestamp
              ? (data['locationUpdatedAt'] as Timestamp).toDate()
              : null)
          : null,
      locationUpdatedBy: data['locationUpdatedBy'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'email': email,
      'pharmacyName': pharmacyName,
      'name': pharmacyName,
      'handlerName': handlerName,
      'ownerName': handlerName,
      'city': city,
      'cityId': toKey(city),
      'area': area,
      'areaId': toKey(area),
      'address': address,
      'phone': phone,
      'isOpen': isOpen,
      'deliveryRadiusKm': deliveryRadiusKm,
      'gstin': gstin,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.now(),
    };

    if (location != null) {
      map['location'] = location;
      map['lat'] = location!.latitude;
      map['lng'] = location!.longitude;
    }
    if (locationUpdatedAt != null) {
      map['locationUpdatedAt'] = Timestamp.fromDate(locationUpdatedAt!);
    }
    if (locationUpdatedBy != null) {
      map['locationUpdatedBy'] = locationUpdatedBy;
    }

    return map;
  }

  PharmacyProfile copyWith({
    String? pharmacyName,
    String? handlerName,
    String? city,
    String? area,
    GeoPoint? location,
    String? address,
    String? phone,
    bool? isOpen,
    double? deliveryRadiusKm,
    String? gstin,
    DateTime? locationUpdatedAt,
    String? locationUpdatedBy,
  }) {
    return PharmacyProfile(
      uid: uid,
      email: email,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      handlerName: handlerName ?? this.handlerName,
      city: city ?? this.city,
      area: area ?? this.area,
      location: location ?? this.location,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      isOpen: isOpen ?? this.isOpen,
      deliveryRadiusKm: deliveryRadiusKm ?? this.deliveryRadiusKm,
      gstin: gstin ?? this.gstin,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
      locationUpdatedBy: locationUpdatedBy ?? this.locationUpdatedBy,
      createdAt: createdAt,
    );
  }
}
