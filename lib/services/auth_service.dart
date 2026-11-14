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

    // 1. Root pharmacies doc: pharmacies/{uid}
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

    // 4. Canonical user identity record: users/{uid}
    final userRef = _db.collection('users').doc(uid);
    batch.set(userRef, {
      'pharmacyId': uid,
      'cityId': cityKey,
      'areaId': areaKey,
      'email': email.trim(),
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    await batch.commit();
    return credential;
  }

  // ─── Locate Exact Pharmacy Document in Backend ────────────────────────────
  Future<PharmacyLocation> resolvePharmacyLocation(String uid, String email) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Single canonical source: users/{uid}
    try {
      final userSnap = await _db.collection('users').doc(uid).get();
      if (userSnap.exists && userSnap.data() != null) {
        final u = userSnap.data()!;
        final pharmacyId = (u['pharmacyId'] ?? '').toString().trim();
        final cityId = (u['cityId'] ?? '').toString().trim();
        final areaId = (u['areaId'] ?? '').toString().trim();

        if (pharmacyId.isNotEmpty) {
          final pSnap = await _db.collection('pharmacies').doc(pharmacyId).get();
          final d = pSnap.data() ?? {};
          return PharmacyLocation(
            docId: pharmacyId,
            path: 'pharmacies/$pharmacyId',
            city: (d['city'] ?? d['cityId'] ?? 'Dehradun').toString(),
            area: (d['area'] ?? d['areaId'] ?? 'Selaqui').toString(),
            cityId: cityId.isNotEmpty ? cityId : 'dehradun',
            areaId: areaId.isNotEmpty ? areaId : 'selaqui',
          );
        }
      }
    } catch (_) {}

    // 2. Migration lookup: If users/{uid} is not yet backfilled, find existing pharmacy by ownerUid or email
    try {
      final queryByUid = await _db
          .collection('pharmacies')
          .where('ownerUid', isEqualTo: uid)
          .limit(1)
          .get();
      DocumentSnapshot<Map<String, dynamic>>? match =
          queryByUid.docs.isNotEmpty ? queryByUid.docs.first : null;

      if (match == null && cleanEmail.isNotEmpty) {
        final queryByEmail = await _db
            .collection('pharmacies')
            .where('email', isEqualTo: cleanEmail)
            .limit(1)
            .get();
        if (queryByEmail.docs.isNotEmpty) {
          match = queryByEmail.docs.first;
        }
      }

      // Check root doc named 'Test' if email matches ceo@klinixy.com or user
      if (match == null) {
        final testDoc = await _db.collection('pharmacies').doc('Test').get();
        if (testDoc.exists) {
          final td = testDoc.data() ?? {};
          final tEmail = (td['email'] ?? '').toString().toLowerCase();
          if (tEmail == cleanEmail || cleanEmail == 'ceo@klinixy.com') {
            match = testDoc;
          }
        }
      }

      if (match != null) {
        final d = match.data() ?? {};
        final pharmacyId = match.id;
        final city = (d['city'] ?? d['cityId'] ?? 'Dehradun').toString();
        final area = (d['area'] ?? d['areaId'] ?? 'Selaqui').toString();
        final cityId = (d['cityId'] ?? PharmacyProfile.toKey(city)).toString();
        final areaId = (d['areaId'] ?? PharmacyProfile.toKey(area)).toString();

        // Backfill users/{uid} so future logins use single source
        try {
          await _db.collection('users').doc(uid).set({
            'pharmacyId': pharmacyId,
            'cityId': cityId,
            'areaId': areaId,
            'email': cleanEmail,
            'updatedAt': Timestamp.now(),
          }, SetOptions(merge: true));
        } catch (_) {}

        return PharmacyLocation(
          docId: pharmacyId,
          path: 'pharmacies/$pharmacyId',
          city: city,
          area: area,
          cityId: cityId,
          areaId: areaId,
        );
      }
    } catch (_) {}

    // 3. Explicit un-onboarded exception — no silent fallbacks to another pharmacy's data!
    throw PharmacyNotOnboardedException(email.isNotEmpty ? email : uid);
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
    GeoPoint? location,
    String? address,
    String? phone,
    bool? isOpen,
    double? deliveryRadiusKm,
    String? gstin,
    String? updatedByUid,
  }) async {
    final updateData = <String, dynamic>{
      'name': pharmacyName.trim(),
      'pharmacyName': pharmacyName.trim(),
      'ownerName': handlerName.trim(),
      'handlerName': handlerName.trim(),
      'updatedAt': Timestamp.now(),
    };

    if (location != null) {
      updateData['location'] = location;
      updateData['lat'] = location.latitude;
      updateData['lng'] = location.longitude;
      updateData['locationUpdatedAt'] = Timestamp.now();
      if (updatedByUid != null) {
        updateData['locationUpdatedBy'] = updatedByUid;
      }
    }
    if (address != null) updateData['address'] = address.trim();
    if (phone != null) updateData['phone'] = phone.trim();
    if (isOpen != null) updateData['isOpen'] = isOpen;
    if (deliveryRadiusKm != null) updateData['deliveryRadiusKm'] = deliveryRadiusKm;
    if (gstin != null) updateData['gstin'] = gstin.trim();

    await _db.doc(docPath).update(updateData);

    // Also mirror to nested path if applicable
    try {
      final docSnap = await _db.doc(docPath).get();
      if (docSnap.exists) {
        final d = docSnap.data()!;
        final cKey = PharmacyProfile.toKey((d['city'] ?? d['cityId'] ?? '').toString());
        final aKey = PharmacyProfile.toKey((d['area'] ?? d['areaId'] ?? '').toString());
        if (cKey.isNotEmpty && aKey.isNotEmpty) {
          await _db
              .collection('cities')
              .doc(cKey)
              .collection('areas')
              .doc(aKey)
              .collection('pharmacies')
              .doc(docSnap.id)
              .set(updateData, SetOptions(merge: true));
        }
        await _db.collection('pharmacyIndex').doc(docSnap.id).set({
          'name': pharmacyName.trim(),
          'ownerName': handlerName.trim(),
          if (location != null) 'location': location,
          if (isOpen != null) 'isOpen': isOpen,
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> signOut() async => await _auth.signOut();

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class PharmacyNotOnboardedException implements Exception {
  final String identifier;
  const PharmacyNotOnboardedException(this.identifier);

  @override
  String toString() => 'Pharmacy not onboarded for: $identifier';
}
