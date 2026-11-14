import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pharmacy_profile.dart';
import 'database_service.dart';

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
      city: city.trim(),
      area: area.trim(),
    );

    final batch = _db.batch();

    // 1. Root pharmacies doc (matches existing backend schema)
    final rootRef = _db.collection('pharmacies').doc(uid);
    batch.set(rootRef, profile.toMap(), SetOptions(merge: true));

    // 2. Hierarchical doc: cities/{city}/areas/{area}/pharmacies/{uid}
    final nestedRef = _db
        .collection('cities')
        .doc(cityKey)
        .collection('areas')
        .doc(areaKey)
        .collection('pharmacies')
        .doc(uid);
    batch.set(nestedRef, profile.toMap(), SetOptions(merge: true));

    // 3. Fast index doc
    final indexRef = _db.collection('pharmacyIndex').doc(uid);
    batch.set(indexRef, {
      'path': rootRef.path,
      'city': city.trim(),
      'area': area.trim(),
      'name': pharmacyName.trim(),
      'ownerName': handlerName.trim(),
      'email': email.trim(),
    });

    await batch.commit();
    return credential;
  }

  // ─── Locate Exact Pharmacy Document in Backend ────────────────────────────
  Future<PharmacyLocation> resolvePharmacyLocation(String uid, String email) async {
    final cleanEmail = email.trim().toLowerCase();

    // Strategy 1: Check root collection('pharmacies') by email
    try {
      final snap = await _db
          .collection('pharmacies')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        final d = doc.data();
        return PharmacyLocation(
          docId: doc.id,
          path: doc.reference.path,
          city: (d['city'] ?? d['cityId'] ?? 'Dehradun').toString(),
          area: (d['area'] ?? d['areaId'] ?? 'Selaqui').toString(),
        );
      }
    } catch (_) {}

    // Strategy 2: Check root collection('pharmacies') by ownerUid
    try {
      final snap = await _db
          .collection('pharmacies')
          .where('ownerUid', isEqualTo: uid)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        final d = doc.data();
        return PharmacyLocation(
          docId: doc.id,
          path: doc.reference.path,
          city: (d['city'] ?? d['cityId'] ?? 'Dehradun').toString(),
          area: (d['area'] ?? d['areaId'] ?? 'Selaqui').toString(),
        );
      }
    } catch (_) {}

    // Strategy 3: Check root collection('pharmacies').doc(uid)
    try {
      final doc = await _db.collection('pharmacies').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final d = doc.data()!;
        return PharmacyLocation(
          docId: doc.id,
          path: doc.reference.path,
          city: (d['city'] ?? d['cityId'] ?? 'Dehradun').toString(),
          area: (d['area'] ?? d['areaId'] ?? 'Selaqui').toString(),
        );
      }
    } catch (_) {}

    // Strategy 4: Search collectionGroup('pharmacies')
    try {
      final groupSnap = await _db.collectionGroup('pharmacies').get();
      for (final doc in groupSnap.docs) {
        final d = doc.data();
        final docEmail = (d['email'] ?? '').toString().trim().toLowerCase();
        final docOwnerUid = (d['ownerUid'] ?? '').toString().trim();

        if (doc.id == uid || docEmail == cleanEmail || docOwnerUid == uid) {
          return PharmacyLocation(
            docId: doc.id,
            path: doc.reference.path,
            city: (d['city'] ?? d['cityId'] ?? 'Dehradun').toString(),
            area: (d['area'] ?? d['areaId'] ?? 'Selaqui').toString(),
          );
        }
      }
    } catch (_) {}

    // Fallback: create default root doc so user is never blocked
    final defaultPath = 'pharmacies/$uid';
    try {
      final profile = PharmacyProfile(
        uid: uid,
        email: email,
        pharmacyName: 'Test',
        handlerName: 'Ujjwal',
        city: 'Dehradun',
        area: 'Selaqui',
      );
      await _db.doc(defaultPath).set(profile.toMap(), SetOptions(merge: true));
    } catch (_) {}

    return PharmacyLocation(
      docId: uid,
      path: defaultPath,
      city: 'Dehradun',
      area: 'Selaqui',
    );
  }

  // ─── Live Profile Stream Directly From Resolved Doc Path ───────────────────
  Stream<PharmacyProfile?> pharmacyProfileStream(String docPath) {
    return _db.doc(docPath).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return PharmacyProfile.fromMap(snap.data()!, snap.id);
    });
  }

  // ─── Update Profile in Backend ───────────────────────────────────────────
  Future<void> updatePharmacyProfile({
    required String docPath,
    required String pharmacyName,
    required String handlerName,
  }) async {
    final updateData = {
      'name': pharmacyName.trim(),
      'pharmacyName': pharmacyName.trim(),
      'ownerName': handlerName.trim(),
      'handlerName': handlerName.trim(),
      'updatedAt': Timestamp.now(),
    };

    await _db.doc(docPath).update(updateData);
  }

  Future<void> signOut() async => await _auth.signOut();
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
