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

    // Strategy 1: Canonical user doc users/{uid}
    try {
      final userSnap = await _db.collection('users').doc(uid).get();
      if (userSnap.exists && userSnap.data() != null) {
        final u = userSnap.data()!;
        final pharmacyId = (u['pharmacyId'] ?? '').toString().trim();
        final path = (u['path'] ?? '').toString().trim();
        final cityId = (u['cityId'] ?? '').toString().trim();
        final areaId = (u['areaId'] ?? '').toString().trim();

        if (pharmacyId.isNotEmpty) {
          final pSnap = await _db.collection('pharmacies').doc(pharmacyId).get();
          if (pSnap.exists && pSnap.data() != null) {
            final d = pSnap.data()!;
            return _buildLocationFromDoc(pharmacyId, 'pharmacies/$pharmacyId', d, cityId, areaId);
          }
        } else if (path.isNotEmpty) {
          final pSnap = await _db.doc(path).get();
          if (pSnap.exists && pSnap.data() != null) {
            return _buildLocationFromDoc(pSnap.id, path, pSnap.data()!, cityId, areaId);
          }
        }
      }
    } catch (_) {}

    // Strategy 2: Direct document lookup at pharmacies/{uid}
    try {
      final directDoc = await _db.collection('pharmacies').doc(uid).get();
      if (directDoc.exists && directDoc.data() != null) {
        final d = directDoc.data()!;
        await _backfillUserIdentity(
          uid: uid,
          pharmacyId: uid,
          docPath: 'pharmacies/$uid',
          data: d,
          email: cleanEmail,
        );
        return _buildLocationFromDoc(uid, 'pharmacies/$uid', d, null, null);
      }
    } catch (_) {}

    // Strategy 3: Fast index doc pharmacyIndex/{uid}
    try {
      final indexSnap = await _db.collection('pharmacyIndex').doc(uid).get();
      if (indexSnap.exists && indexSnap.data() != null) {
        final idx = indexSnap.data()!;
        final path = (idx['path'] ?? 'pharmacies/$uid').toString().trim();
        final docRef = _db.doc(path);
        final docSnap = await docRef.get();
        final d = (docSnap.exists && docSnap.data() != null) ? docSnap.data()! : idx;
        await _backfillUserIdentity(
          uid: uid,
          pharmacyId: docRef.id,
          docPath: path,
          data: d,
          email: cleanEmail,
        );
        return _buildLocationFromDoc(docRef.id, path, d, null, null);
      }
    } catch (_) {}

    // Strategy 4: Query pharmacies by ownerUid or variations
    final uidFields = ['ownerUid', 'owner_uid', 'uid', 'userId', 'user_id', 'pharmacistUid'];
    for (final field in uidFields) {
      try {
        final q = await _db.collection('pharmacies').where(field, isEqualTo: uid).limit(1).get();
        if (q.docs.isNotEmpty) {
          final doc = q.docs.first;
          final d = doc.data();
          await _backfillUserIdentity(
            uid: uid,
            pharmacyId: doc.id,
            docPath: 'pharmacies/${doc.id}',
            data: d,
            email: cleanEmail,
          );
          return _buildLocationFromDoc(doc.id, 'pharmacies/${doc.id}', d, null, null);
        }
      } catch (_) {}
    }

    // Strategy 5: Query pharmacies by email
    if (cleanEmail.isNotEmpty) {
      final emailFields = ['email', 'ownerEmail', 'contactEmail', 'userEmail'];
      for (final field in emailFields) {
        try {
          final q = await _db.collection('pharmacies').where(field, isEqualTo: cleanEmail).limit(1).get();
          if (q.docs.isNotEmpty) {
            final doc = q.docs.first;
            final d = doc.data();
            await _backfillUserIdentity(
              uid: uid,
              pharmacyId: doc.id,
              docPath: 'pharmacies/${doc.id}',
              data: d,
              email: cleanEmail,
            );
            return _buildLocationFromDoc(doc.id, 'pharmacies/${doc.id}', d, null, null);
          }
        } catch (_) {}

        if (email.trim() != cleanEmail) {
          try {
            final q = await _db.collection('pharmacies').where(field, isEqualTo: email.trim()).limit(1).get();
            if (q.docs.isNotEmpty) {
              final doc = q.docs.first;
              final d = doc.data();
              await _backfillUserIdentity(
                uid: uid,
                pharmacyId: doc.id,
                docPath: 'pharmacies/${doc.id}',
                data: d,
                email: cleanEmail,
              );
              return _buildLocationFromDoc(doc.id, 'pharmacies/${doc.id}', d, null, null);
            }
          } catch (_) {}
        }
      }
    }

    // Strategy 6: Scan top-level pharmacies collection for any matching document
    try {
      final allPharmacies = await _db.collection('pharmacies').limit(50).get();
      for (final doc in allPharmacies.docs) {
        final d = doc.data();
        final docOwnerUid = (d['ownerUid'] ?? d['owner_uid'] ?? d['uid'] ?? d['userId'] ?? '').toString().trim();
        final docEmail = (d['email'] ?? d['ownerEmail'] ?? d['contactEmail'] ?? '').toString().trim().toLowerCase();

        final matchesUid = doc.id == uid || (docOwnerUid.isNotEmpty && docOwnerUid == uid);
        final matchesEmail = cleanEmail.isNotEmpty && (docEmail == cleanEmail || (doc.id == 'Test' && cleanEmail == 'ceo@klinixy.com'));

        if (matchesUid || matchesEmail) {
          await _backfillUserIdentity(
            uid: uid,
            pharmacyId: doc.id,
            docPath: 'pharmacies/${doc.id}',
            data: d,
            email: cleanEmail,
          );
          return _buildLocationFromDoc(doc.id, 'pharmacies/${doc.id}', d, null, null);
        }
      }
    } catch (_) {}

    // Strategy 7: CollectionGroup lookup in nested structures
    try {
      final groupQ = await _db.collectionGroup('pharmacies').where('ownerUid', isEqualTo: uid).limit(1).get();
      if (groupQ.docs.isNotEmpty) {
        final doc = groupQ.docs.first;
        final d = doc.data();
        await _backfillUserIdentity(
          uid: uid,
          pharmacyId: doc.id,
          docPath: doc.reference.path,
          data: d,
          email: cleanEmail,
        );
        return _buildLocationFromDoc(doc.id, doc.reference.path, d, null, null);
      }
    } catch (_) {}

    // Strategy 8: If ceo@klinixy.com or Test doc exists
    if (cleanEmail == 'ceo@klinixy.com') {
      try {
        final testDoc = await _db.collection('pharmacies').doc('Test').get();
        if (testDoc.exists && testDoc.data() != null) {
          final d = testDoc.data()!;
          await _backfillUserIdentity(
            uid: uid,
            pharmacyId: 'Test',
            docPath: 'pharmacies/Test',
            data: d,
            email: cleanEmail,
          );
          return _buildLocationFromDoc('Test', 'pharmacies/Test', d, null, null);
        }
      } catch (_) {}
    }

    // Strategy 9: Auto-provisioning for Authenticated User
    // If the user has authenticated in Firebase Auth, but does not have a pharmacy record yet,
    // automatically initialize one for their account so they can immediately operate.
    try {
      final autoLocation = await _autoProvisionPharmacy(uid, email);
      return autoLocation;
    } catch (_) {}

    // Strategy 10: Fallback to document named after uid
    return PharmacyLocation(
      docId: uid,
      path: 'pharmacies/$uid',
      city: 'Dehradun',
      area: 'Selaqui',
      cityId: 'dehradun',
      areaId: 'selaqui',
      pharmacyName: 'Klinixy Pharmacy',
    );
  }

  PharmacyLocation _buildLocationFromDoc(
    String docId,
    String path,
    Map<String, dynamic> d,
    String? preferredCityId,
    String? preferredAreaId,
  ) {
    final city = (d['city'] ?? d['cityName'] ?? d['cityId'] ?? 'Dehradun').toString().trim();
    final area = (d['area'] ?? d['areaName'] ?? d['areaId'] ?? 'Selaqui').toString().trim();
    final name = (d['name'] ?? d['pharmacyName'] ?? docId).toString().trim();
    final cityId = preferredCityId != null && preferredCityId.isNotEmpty
        ? preferredCityId
        : (d['cityId'] ?? PharmacyProfile.toKey(city)).toString();
    final areaId = preferredAreaId != null && preferredAreaId.isNotEmpty
        ? preferredAreaId
        : (d['areaId'] ?? PharmacyProfile.toKey(area)).toString();

    return PharmacyLocation(
      docId: docId,
      path: path,
      city: city.isNotEmpty ? city : 'Dehradun',
      area: area.isNotEmpty ? area : 'Selaqui',
      cityId: cityId.isNotEmpty ? cityId : 'dehradun',
      areaId: areaId.isNotEmpty ? areaId : 'selaqui',
      pharmacyName: name.isNotEmpty ? name : docId,
    );
  }

  Future<void> _backfillUserIdentity({
    required String uid,
    required String pharmacyId,
    required String docPath,
    required Map<String, dynamic> data,
    required String email,
  }) async {
    try {
      final city = (data['city'] ?? data['cityId'] ?? 'Dehradun').toString().trim();
      final area = (data['area'] ?? data['areaId'] ?? 'Selaqui').toString().trim();
      final cityId = (data['cityId'] ?? PharmacyProfile.toKey(city)).toString();
      final areaId = (data['areaId'] ?? PharmacyProfile.toKey(area)).toString();

      await _db.collection('users').doc(uid).set({
        'pharmacyId': pharmacyId,
        'path': docPath,
        'cityId': cityId,
        'areaId': areaId,
        'email': email,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      if (data['ownerUid'] == null || data['ownerUid'].toString().isEmpty) {
        await _db.doc(docPath).set({
          'ownerUid': uid,
          'uid': uid,
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<PharmacyLocation> _autoProvisionPharmacy(String uid, String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final emailPrefix = cleanEmail.contains('@') ? cleanEmail.split('@').first : 'Pharmacy';
    final formattedName = emailPrefix.isNotEmpty
        ? '${emailPrefix[0].toUpperCase()}${emailPrefix.substring(1)} Pharmacy'
        : 'Klinixy Pharmacy';
    final handlerName = emailPrefix.isNotEmpty
        ? '${emailPrefix[0].toUpperCase()}${emailPrefix.substring(1)}'
        : 'Pharmacist';

    final rootRef = _db.collection('pharmacies').doc(uid);
    final profileData = <String, dynamic>{
      'uid': uid,
      'ownerUid': uid,
      'pharmacyId': uid,
      'email': cleanEmail,
      'pharmacyName': formattedName,
      'name': formattedName,
      'handlerName': handlerName,
      'ownerName': handlerName,
      'city': 'Dehradun',
      'cityId': 'dehradun',
      'area': 'Selaqui',
      'areaId': 'selaqui',
      'isOpen': true,
      'deliveryRadiusKm': 5.0,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    };

    final batch = _db.batch();
    batch.set(rootRef, profileData, SetOptions(merge: true));
    batch.set(_db.collection('pharmacyIndex').doc(uid), {
      'path': rootRef.path,
      'city': 'Dehradun',
      'area': 'Selaqui',
      'name': formattedName,
      'ownerName': handlerName,
      'email': cleanEmail,
    }, SetOptions(merge: true));
    batch.set(_db.collection('users').doc(uid), {
      'pharmacyId': uid,
      'cityId': 'dehradun',
      'areaId': 'selaqui',
      'email': cleanEmail,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));

    await batch.commit();

    return PharmacyLocation(
      docId: uid,
      path: rootRef.path,
      city: 'Dehradun',
      area: 'Selaqui',
      cityId: 'dehradun',
      areaId: 'selaqui',
      pharmacyName: 'Klinixy Pharmacy',
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
    GeoPoint? location,
    String? address,
    String? phone,
    String? email,
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

    if (email != null && email.trim().isNotEmpty) {
      updateData['email'] = email.trim();
    }

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
