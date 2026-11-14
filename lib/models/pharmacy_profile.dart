import 'package:cloud_firestore/cloud_firestore.dart';

class PharmacyProfile {
  final String uid;
  final String? ownerUid;
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
    this.ownerUid,
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

  static String _extractFirstNonEmpty(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final val = data[key];
      if (val != null) {
        final s = val.toString().trim();
        if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
      }
    }
    return '';
  }

  factory PharmacyProfile.fromMap(Map<String, dynamic> data, String uid) {
    GeoPoint? loc;
    if (data['location'] is GeoPoint) {
      loc = data['location'] as GeoPoint;
    } else if (data['coordinates'] is GeoPoint) {
      loc = data['coordinates'] as GeoPoint;
    } else if (data['lat'] != null && data['lng'] != null) {
      final lat = double.tryParse(data['lat'].toString());
      final lng = double.tryParse(data['lng'].toString());
      if (lat != null && lng != null) loc = GeoPoint(lat, lng);
    } else if (data['latitude'] != null && data['longitude'] != null) {
      final lat = double.tryParse(data['latitude'].toString());
      final lng = double.tryParse(data['longitude'].toString());
      if (lat != null && lng != null) loc = GeoPoint(lat, lng);
    } else if (data['geo'] is Map) {
      final geo = data['geo'] as Map;
      final lat = double.tryParse(geo['lat']?.toString() ?? '');
      final lng = double.tryParse(geo['lng']?.toString() ?? '');
      if (lat != null && lng != null) loc = GeoPoint(lat, lng);
    }

    final pName = _extractFirstNonEmpty(data, [
      'name',
      'pharmacyName',
      'storeName',
      'pharmacy_name',
      'store_name',
      'title',
      'shopName',
      'displayName',
    ]);

    final hName = _extractFirstNonEmpty(data, [
      'ownerName',
      'handlerName',
      'pharmacistName',
      'owner_name',
      'displayName',
      'pharmacist',
      'contactName',
    ]);

    final pEmail = _extractFirstNonEmpty(data, [
      'email',
      'ownerEmail',
      'contactEmail',
      'userEmail',
    ]);

    final pCity = _extractFirstNonEmpty(data, ['city', 'cityName', 'cityId']);
    final pArea = _extractFirstNonEmpty(data, ['area', 'areaName', 'areaId']);
    final pAddress = _extractFirstNonEmpty(data, ['address', 'storeAddress', 'fullAddress', 'street']);
    final pPhone = _extractFirstNonEmpty(data, ['phone', 'phoneNumber', 'mobile', 'contact', 'contactPhone']);
    final pGstin = _extractFirstNonEmpty(data, ['gstin', 'gst', 'gstNumber', 'gst_number']);
    final pOwnerUid = _extractFirstNonEmpty(data, ['ownerUid', 'owner_uid', 'uid', 'userId', 'user_id', 'pharmacistUid']);

    bool parsedIsOpen = true;
    if (data['isOpen'] is bool) {
      parsedIsOpen = data['isOpen'] as bool;
    } else if (data['open'] is bool) {
      parsedIsOpen = data['open'] as bool;
    } else if (data['status'] != null) {
      parsedIsOpen = data['status'].toString().toLowerCase() != 'closed';
    }

    return PharmacyProfile(
      uid: uid,
      ownerUid: pOwnerUid.isNotEmpty ? pOwnerUid : uid,
      email: pEmail,
      pharmacyName: pName,
      handlerName: hName,
      city: pCity,
      area: pArea,
      location: loc,
      address: pAddress,
      phone: pPhone,
      isOpen: parsedIsOpen,
      deliveryRadiusKm: data['deliveryRadiusKm'] != null
          ? (double.tryParse(data['deliveryRadiusKm'].toString()) ?? 5.0)
          : 5.0,
      gstin: pGstin,
      locationUpdatedAt: data['locationUpdatedAt'] != null
          ? (data['locationUpdatedAt'] is Timestamp
              ? (data['locationUpdatedAt'] as Timestamp).toDate()
              : null)
          : null,
      locationUpdatedBy: data['locationUpdatedBy']?.toString(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uid': uid,
      'ownerUid': ownerUid ?? uid,
      'pharmacyId': uid,
      'email': email,
      'pharmacyName': pharmacyName,
      'name': pharmacyName,
      'storeName': pharmacyName,
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
    String? ownerUid,
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
      ownerUid: ownerUid ?? this.ownerUid,
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
