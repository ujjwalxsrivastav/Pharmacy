import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pharmacy_profile.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ─── Sign In ────────────────────────────────────────────────────────────
  Future<UserCredential?> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  // ─── Sign Up ─────────────────────────────────────────────────────────────
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String pharmacyName,
    required String handlerName,
    required String city,
    required String area,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    final uid = credential.user!.uid;

    final cityKey = PharmacyProfile.toKey(city);
    final areaKey = PharmacyProfile.toKey(area);

    final profile = PharmacyProfile(
      uid: uid,
      email: email.trim(),
      pharmacyName: pharmacyName.trim(),
      handlerName: handlerName.trim(),
      city: cityKey,
      area: areaKey,
    );

    final batch = _db.batch();

    // 1. Nested path: cities/{city}/areas/{area}/pharmacies/{uid}
    final nestedRef = _db
        .collection('cities')
        .doc(cityKey)
        .collection('areas')
        .doc(areaKey)
        .collection('pharmacies')
        .doc(uid);
    batch.set(nestedRef, profile.toMap());

    // 2. Root pharmacies collection: pharmacies/{uid}
    final rootRef = _db.collection('pharmacies').doc(uid);
    batch.set(rootRef, profile.toMap(), SetOptions(merge: true));

    // 3. Fast index: pharmacyIndex/{uid}
    final indexRef = _db.collection('pharmacyIndex').doc(uid);
    batch.set(indexRef, {
      'city': cityKey,
      'area': areaKey,
      'pharmacyName': pharmacyName.trim(),
      'name': pharmacyName.trim(),
      'ownerName': handlerName.trim(),
      'email': email.trim(),
    });

    await batch.commit();
    return credential;
  }

  // ─── Match Existing or Nested Pharmacy ────────────────────────────────────
  Future<Map<String, String>> resolvePharmacyPath(String uid, String email) async {
    // Check 1: Root pharmacies where ownerUid == uid or doc.id == uid
    try {
      final rootSnap = await _db.collection('pharmacies').doc(uid).get();
      if (rootSnap.exists && rootSnap.data() != null) {
        final d = rootSnap.data()!;
        final city = PharmacyProfile.toKey(d['cityId'] ?? d['city'] ?? 'default_city');
        final area = PharmacyProfile.toKey(d['areaId'] ?? d['area'] ?? 'default_area');
        final name = d['name'] ?? d['pharmacyName'] ?? 'Pharmacy';
        final handler = d['ownerName'] ?? d['handlerName'] ?? 'Pharmacist';

        await _syncProfile(uid, email, city, area, name, handler, d);
        return {'city': city, 'area': area};
      }
    } catch (_) {}

    // Check 2: Root pharmacies where email matches or ownerUid matches
    try {
      final queryByUid = await _db
          .collection('pharmacies')
          .where('ownerUid', isEqualTo: uid)
          .limit(1)
          .get();

      if (queryByUid.docs.isNotEmpty) {
        final d = queryByUid.docs.first.data();
        final city = PharmacyProfile.toKey(d['cityId'] ?? d['city'] ?? 'default_city');
        final area = PharmacyProfile.toKey(d['areaId'] ?? d['area'] ?? 'default_area');
        final name = d['name'] ?? d['pharmacyName'] ?? 'Pharmacy';
        final handler = d['ownerName'] ?? d['handlerName'] ?? 'Pharmacist';

        await _syncProfile(uid, email, city, area, name, handler, d);
        return {'city': city, 'area': area};
      }

      final queryByEmail = await _db
          .collection('pharmacies')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();

      if (queryByEmail.docs.isNotEmpty) {
        final d = queryByEmail.docs.first.data();
        final city = PharmacyProfile.toKey(d['cityId'] ?? d['city'] ?? 'default_city');
        final area = PharmacyProfile.toKey(d['areaId'] ?? d['area'] ?? 'default_area');
        final name = d['name'] ?? d['pharmacyName'] ?? 'Pharmacy';
        final handler = d['ownerName'] ?? d['handlerName'] ?? 'Pharmacist';

        await _syncProfile(uid, email, city, area, name, handler, d);
        return {'city': city, 'area': area};
      }
    } catch (_) {}

    // Check 3: pharmacyIndex
    try {
      final snap = await _db.collection('pharmacyIndex').doc(uid).get();
      if (snap.exists && snap.data() != null) {
        final d = snap.data()!;
        if (d['city'] != null && d['area'] != null) {
          return {'city': d['city'] as String, 'area': d['area'] as String};
        }
      }
    } catch (_) {}

    // Check 4: nested collectionGroup('pharmacies')
    try {
      final groupSnap = await _db.collectionGroup('pharmacies').get();
      for (final doc in groupSnap.docs) {
        final d = doc.data();
        if (doc.id == uid || d['ownerUid'] == uid || d['email'] == email.trim()) {
          final parts = doc.reference.path.split('/');
          if (parts.length >= 4 && parts[0] == 'cities' && parts[2] == 'areas') {
            final city = parts[1];
            final area = parts[3];
            final name = d['name'] ?? d['pharmacyName'] ?? 'Pharmacy';
            final handler = d['ownerName'] ?? d['handlerName'] ?? 'Pharmacist';

            await _syncProfile(uid, email, city, area, name, handler, d);
            return {'city': city, 'area': area};
          }
        }
      }
    } catch (_) {}

    // Default fallback
    final defaultCity = 'default_city';
    final defaultArea = 'default_area';
    final defaultName = email.split('@').first.toUpperCase();
    await _syncProfile(uid, email, defaultCity, defaultArea, defaultName, 'Pharmacist', {});
    return {'city': defaultCity, 'area': defaultArea};
  }

  Future<void> _syncProfile(
    String uid,
    String email,
    String city,
    String area,
    String pharmacyName,
    String handlerName,
    Map<String, dynamic> existingData,
  ) async {
    try {
      final profile = PharmacyProfile(
        uid: uid,
        email: email,
        pharmacyName: pharmacyName,
        handlerName: handlerName,
        city: city,
        area: area,
      );

      final pharmRef = _db
          .collection('cities')
          .doc(city)
          .collection('areas')
          .doc(area)
          .collection('pharmacies')
          .doc(uid);

      await pharmRef.set(profile.toMap(), SetOptions(merge: true));

      await _db.collection('pharmacyIndex').doc(uid).set({
        'city': city,
        'area': area,
        'pharmacyName': pharmacyName,
        'name': pharmacyName,
        'ownerName': handlerName,
        'email': email,
      }, SetOptions(merge: true));

      // Also ensure root pharmacies doc exists and is updated
      await _db.collection('pharmacies').doc(uid).set(profile.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }

  // ─── Profile stream ───────────────────────────────────────────────────────
  Stream<PharmacyProfile?> pharmacyProfileStream(
      String uid, String city, String area) {
    return _db
        .collection('cities')
        .doc(city)
        .collection('areas')
        .doc(area)
        .collection('pharmacies')
        .doc(uid)
        .snapshots()
        .map((snap) =>
            snap.exists ? PharmacyProfile.fromMap(snap.data()!, uid) : null);
  }

  // ─── Update Profile ──────────────────────────────────────────────────────
  Future<void> updatePharmacyProfile({
    required String uid,
    required String city,
    required String area,
    required String pharmacyName,
    required String handlerName,
  }) async {
    final cityKey = PharmacyProfile.toKey(city);
    final areaKey = PharmacyProfile.toKey(area);

    final nestedRef = _db
        .collection('cities')
        .doc(cityKey)
        .collection('areas')
        .doc(areaKey)
        .collection('pharmacies')
        .doc(uid);

    final updateData = {
      'pharmacyName': pharmacyName.trim(),
      'name': pharmacyName.trim(),
      'handlerName': handlerName.trim(),
      'ownerName': handlerName.trim(),
      'updatedAt': Timestamp.now(),
    };

    await nestedRef.update(updateData);

    try {
      await _db.collection('pharmacies').doc(uid).update(updateData);
    } catch (_) {}

    try {
      await _db.collection('pharmacyIndex').doc(uid).update({
        'pharmacyName': pharmacyName.trim(),
        'name': pharmacyName.trim(),
        'ownerName': handlerName.trim(),
      });
    } catch (_) {}
  }

  Future<void> signOut() async => await _auth.signOut();
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
