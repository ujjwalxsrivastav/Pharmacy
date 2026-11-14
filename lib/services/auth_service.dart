import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pharmacy_profile.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

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

    // Save pharmacy profile under pharmacies/{uid}
    final profile = PharmacyProfile(
      uid: uid,
      email: email.trim(),
      pharmacyName: pharmacyName.trim(),
      handlerName: handlerName.trim(),
      city: city.trim(),
      area: area.trim(),
    );

    await _firestore
        .collection('pharmacies')
        .doc(uid)
        .set(profile.toMap());

    return credential;
  }

  Future<PharmacyProfile?> getPharmacyProfile(String uid) async {
    final doc =
        await _firestore.collection('pharmacies').doc(uid).get();
    if (!doc.exists) return null;
    return PharmacyProfile.fromMap(doc.data()!, uid);
  }

  Stream<PharmacyProfile?> pharmacyProfileStream(String uid) {
    return _firestore
        .collection('pharmacies')
        .doc(uid)
        .snapshots()
        .map((snap) =>
            snap.exists ? PharmacyProfile.fromMap(snap.data()!, uid) : null);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

final authServiceProvider =
    Provider<AuthService>((ref) => AuthService());
