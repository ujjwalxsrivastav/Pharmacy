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

    final pharmacyRef = _db
        .collection('cities')
        .doc(cityKey)
        .collection('areas')
        .doc(areaKey)
        .collection('pharmacies')
        .doc(uid);
    batch.set(pharmacyRef, profile.toMap());

    final indexRef = _db.collection('pharmacyIndex').doc(uid);
    batch.set(indexRef, {
      'city': cityKey,
      'area': areaKey,
      'pharmacyName': pharmacyName.trim(),
      'email': email.trim(),
    });

    await batch.commit();
    return credential;
  }

  // ─── Auto-Resolve or Auto-Migrate Existing Pharmacy ────────────────────────
  Future<Map<String, String>> resolvePharmacyPath(String uid, String email) async {
    // 1. Try reading pharmacyIndex
    try {
      final snap = await _db.collection('pharmacyIndex').doc(uid).get();
      if (snap.exists && snap.data() != null) {
        final d = snap.data()!;
        if (d['city'] != null && d['area'] != null) {
          return {'city': d['city'] as String, 'area': d['area'] as String};
        }
      }
    } catch (_) {}

    // 2. Try searching cities collection group
    try {
      final groupSnap = await _db.collectionGroup('pharmacies').get();
      for (final doc in groupSnap.docs) {
        if (doc.id == uid) {
          final parts = doc.reference.path.split('/');
          if (parts.length >= 4 && parts[0] == 'cities' && parts[2] == 'areas') {
            final city = parts[1];
            final area = parts[3];
            try {
              await _db.collection('pharmacyIndex').doc(uid).set({
                'city': city,
                'area': area,
                'pharmacyName': doc.data()['pharmacyName'] ?? 'Pharmacy',
                'email': email,
              }, SetOptions(merge: true));
            } catch (_) {}
            return {'city': city, 'area': area};
          }
        }
      }
    } catch (_) {}

    // 3. Try root pharmacies/{uid} collection
    try {
      final rootSnap = await _db.collection('pharmacies').doc(uid).get();
      if (rootSnap.exists && rootSnap.data() != null) {
        final d = rootSnap.data()!;
        final city = PharmacyProfile.toKey(d['city'] ?? 'default_city');
        final area = PharmacyProfile.toKey(d['area'] ?? 'default_area');
        final name = d['pharmacyName'] ?? 'Pharmacy';
        final handler = d['handlerName'] ?? 'Pharmacist';

        // Migrate to cities > areas > pharmacies > uid
        await _migrateToHierarchy(uid, email, city, area, name, handler);
        return {'city': city, 'area': area};
      }
    } catch (_) {}

    // 4. Default auto-initialization for existing legacy account
    // So the user doesn't get blocked and can immediately access everything!
    final defaultCity = 'default_city';
    final defaultArea = 'default_area';
    final defaultName = email.split('@').first.toUpperCase();
    await _migrateToHierarchy(uid, email, defaultCity, defaultArea, defaultName, 'Pharmacist');

    return {'city': defaultCity, 'area': defaultArea};
  }

  Future<void> _migrateToHierarchy(
    String uid,
    String email,
    String city,
    String area,
    String pharmacyName,
    String handlerName,
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
        'email': email,
      }, SetOptions(merge: true));

      // Copy legacy medicines from root /medicines to the new /stock if any exist
      final legacyMeds = await _db.collection('medicines').get();
      for (final doc in legacyMeds.docs) {
        await pharmRef.collection('stock').doc(doc.id).set(doc.data(), SetOptions(merge: true));
      }

      // Copy legacy sales from root /sales to the new /sales if any exist
      final legacySales = await _db.collection('sales').get();
      for (final doc in legacySales.docs) {
        await pharmRef.collection('sales').doc(doc.id).set(doc.data(), SetOptions(merge: true));
      }
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
    final pharmRef = _db
        .collection('cities')
        .doc(city)
        .collection('areas')
        .doc(area)
        .collection('pharmacies')
        .doc(uid);

    await pharmRef.update({
      'pharmacyName': pharmacyName.trim(),
      'handlerName': handlerName.trim(),
    });

    try {
      await _db.collection('pharmacyIndex').doc(uid).update({
        'pharmacyName': pharmacyName.trim(),
      });
    } catch (_) {}
  }

  Future<void> signOut() async => await _auth.signOut();
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
