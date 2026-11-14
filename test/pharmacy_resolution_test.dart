import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacist_dashboard/models/pharmacy_profile.dart';

void main() {
  group('Backend Pharmacy Profile & Dynamic Binding Tests', () {
    test('PharmacyProfile.fromMap extracts name and ownerName from legacy schemas', () {
      final legacyMap = {
        'name': 'LifeCare Meds',
        'ownerName': 'Dr. Alok Verma',
        'email': 'alok@lifecare.com',
        'city': 'Dehradun',
        'area': 'Selaqui',
        'isOpen': true,
        'lat': 30.3643,
        'lng': 77.8542,
      };

      final profile = PharmacyProfile.fromMap(legacyMap, 'pharm_123');

      expect(profile.pharmacyName, 'LifeCare Meds');
      expect(profile.handlerName, 'Dr. Alok Verma');
      expect(profile.email, 'alok@lifecare.com');
      expect(profile.city, 'Dehradun');
      expect(profile.area, 'Selaqui');
      expect(profile.isOpen, true);
      expect(profile.hasLocation, true);
      expect(profile.latitude, closeTo(30.3643, 0.0001));
      expect(profile.longitude, closeTo(77.8542, 0.0001));
    });

    test('PharmacyProfile.fromMap extracts from modern/alternative field keys', () {
      final modernMap = {
        'pharmacyName': 'Apollo Pharmacy Selaqui',
        'handlerName': 'Pooja Rawat',
        'ownerEmail': 'pooja@apollo.com',
        'cityName': 'Dehradun',
        'areaName': 'Industrial Area',
        'phone': '9876543210',
        'status': 'open',
        'location': const GeoPoint(30.35, 77.86),
        'ownerUid': 'user_xyz_789',
      };

      final profile = PharmacyProfile.fromMap(modernMap, 'user_xyz_789');

      expect(profile.pharmacyName, 'Apollo Pharmacy Selaqui');
      expect(profile.handlerName, 'Pooja Rawat');
      expect(profile.email, 'pooja@apollo.com');
      expect(profile.city, 'Dehradun');
      expect(profile.area, 'Industrial Area');
      expect(profile.phone, '9876543210');
      expect(profile.isOpen, true);
      expect(profile.ownerUid, 'user_xyz_789');
      expect(profile.latitude, closeTo(30.35, 0.001));
    });

    test('PharmacyProfile.toMap writes both canonical and backward-compatible fields', () {
      final profile = PharmacyProfile(
        uid: 'user_456',
        ownerUid: 'user_456',
        email: 'test@pharmacy.com',
        pharmacyName: 'City Health Chemist',
        handlerName: 'Rajesh Kumar',
        city: 'Dehradun',
        area: 'Selaqui',
        isOpen: false,
      );

      final map = profile.toMap();

      expect(map['uid'], 'user_456');
      expect(map['ownerUid'], 'user_456');
      expect(map['pharmacyId'], 'user_456');
      expect(map['name'], 'City Health Chemist');
      expect(map['pharmacyName'], 'City Health Chemist');
      expect(map['ownerName'], 'Rajesh Kumar');
      expect(map['handlerName'], 'Rajesh Kumar');
      expect(map['city'], 'Dehradun');
      expect(map['cityId'], 'dehradun');
      expect(map['area'], 'Selaqui');
      expect(map['areaId'], 'selaqui');
      expect(map['isOpen'], false);
    });

    test('Empty name fallbacks never return hardcoded Ujjwal or Klinixy Dehradun', () {
      final emptyMap = <String, dynamic>{
        'email': 'pharmacist@store.com',
      };

      final profile = PharmacyProfile.fromMap(emptyMap, 'pharm_empty');

      expect(profile.pharmacyName, '');
      expect(profile.handlerName, '');
      expect(profile.pharmacyName, isNot('Klinixy Dehradun'));
      expect(profile.handlerName, isNot('Ujjwal'));
    });
  });
}
