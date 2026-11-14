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

    // 1. Full hierarchical path:
    //    cities/{city}/areas/{area}/pharmacies/{uid}
    final pharmacyRef = _db
        .collection('cities')
        .doc(cityKey)
        .collection('areas')
        .doc(areaKey)
        .collection('pharmacies')
        .doc(uid);
    batch.set(pharmacyRef, profile.toMap());

    // 2. Index doc for fast lookup on login:
    //    pharmacyIndex/{uid} → { city, area }
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

  // ─── Resolve path from index ─────────────────────────────────────────────
  Future<Map<String, String>?> resolvePharmacyPath(String uid) async {
    final snap = await _db.collection('pharmacyIndex').doc(uid).get();
    if (!snap.exists) return null;
    final d = snap.data()!;
    return {'city': d['city'] as String, 'area': d['area'] as String};
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

  Future<void> signOut() async => await _auth.signOut();
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
