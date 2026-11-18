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

    final pharmacySlug = DatabaseService.slugify(pharmacyName.trim());
    final pharmacyDocId = pharmacySlug.isNotEmpty ? pharmacySlug : uid;

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

    // 1. Root pharmacies doc: pharmacies/{pharmacySlug} (clean, human-readable name slug)
    final rootRef = _db.collection('pharmacies').doc(pharmacyDocId);
    batch.set(rootRef, profile.toMap(), SetOptions(merge: true));

    // 2. Hierarchical doc: cities/{city}/areas/{area}/pharmacies/{pharmacySlug}
    final nestedRef = _db
        .collection('cities')
        .doc(cityKey)
        .collection('areas')
        .doc(areaKey)
        .collection('pharmacies')
        .doc(pharmacyDocId);
    batch.set(nestedRef, profile.toMap(), SetOptions(merge: true));

    // 2b. Hierarchical exact case (e.g. Selaqui)
    if (area.trim() != areaKey) {
      final exactNestedRef = _db
          .collection('cities')
          .doc(cityKey)
          .collection('areas')
          .doc(area.trim())
          .collection('pharmacies')
          .doc(pharmacyDocId);
      batch.set(exactNestedRef, profile.toMap(), SetOptions(merge: true));
    }

    // 2c. Root areas collection (e.g. areas/Selaqui/pharmacies/slug)
    final areaRootRef = _db
        .collection('areas')
        .doc(area.trim())
        .collection('pharmacies')
        .doc(pharmacyDocId);
    batch.set(areaRootRef, profile.toMap(), SetOptions(merge: true));

    // 3. Fast index doc
    final indexRef = _db.collection('pharmacyIndex').doc(pharmacyDocId);
    batch.set(indexRef, {
      'path': rootRef.path,
      'city': city.trim(),
      'area': area.trim(),
      'name': pharmacyName.trim(),
      'ownerName': handlerName.trim(),
      'email': email.trim(),
      'ownerUid': uid,
    });
    batch.set(_db.collection('pharmacyIndex').doc(uid), {
      'path': rootRef.path,
      'pharmacyId': pharmacyDocId,
      'name': pharmacyName.trim(),
      'email': email.trim(),
    });

    // 4. Canonical user identity record: users/{uid}
    final userRef = _db.collection('users').doc(uid);
    batch.set(userRef, {
      'pharmacyId': pharmacyDocId,
      'path': rootRef.path,
      'cityId': cityKey,
      'areaId': areaKey,
      'email': email.trim(),
      'pharmacyName': pharmacyName.trim(),
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    await batch.commit();
    return credential;
  }

  static final Map<String, PharmacyLocation> _locationCache = {};

  // ─── Locate Exact Pharmacy Document in Backend (Optimized Minimal Reads) ────
  Future<PharmacyLocation> resolvePharmacyLocation(String uid, String email) async {
    final cleanEmail = email.trim().toLowerCase();

    // 0. In-Memory Cache (0 Firestore reads for current session)
    if (_locationCache.containsKey(uid)) {
      return _locationCache[uid]!;
    }

    // 1. Canonical user document (1 Firestore read)
    try {
      final userSnap = await _db.collection('users').doc(uid).get();
      if (userSnap.exists && userSnap.data() != null) {
        final u = userSnap.data()!;
        final pharmacyId = (u['pharmacyId'] ?? '').toString().trim();
        if (pharmacyId.isNotEmpty) {
          final loc = PharmacyLocation(
            docId: pharmacyId,
            path: (u['path'] ?? 'pharmacies/$pharmacyId').toString().trim(),
            city: (u['city'] ?? 'Dehradun').toString().trim(),
            area: (u['area'] ?? 'Selaqui').toString().trim(),
            cityId: (u['cityId'] ?? 'dehradun').toString().trim(),
            areaId: (u['areaId'] ?? 'selaqui').toString().trim(),
            pharmacyName: (u['pharmacyName'] ?? '').toString().trim(),
          );
          _locationCache[uid] = loc;
          return loc;
        }
      }
    } catch (_) {}

    // 2. Fast index document (1 Firestore read)
    try {
      final indexSnap = await _db.collection('pharmacyIndex').doc(uid).get();
      if (indexSnap.exists && indexSnap.data() != null) {
        final idx = indexSnap.data()!;
        final pharmacyId = (idx['pharmacyId'] ?? idx['docId'] ?? '').toString().trim();
        final path = (idx['path'] ?? 'pharmacies/$pharmacyId').toString().trim();
        final name = (idx['name'] ?? idx['pharmacyName'] ?? '').toString().trim();
        if (pharmacyId.isNotEmpty) {
          final loc = PharmacyLocation(
            docId: pharmacyId,
            path: path,
            city: (idx['city'] ?? 'Dehradun').toString().trim(),
            area: (idx['area'] ?? 'Selaqui').toString().trim(),
            cityId: (idx['cityId'] ?? 'dehradun').toString().trim(),
            areaId: (idx['areaId'] ?? 'selaqui').toString().trim(),
            pharmacyName: name,
          );
          _locationCache[uid] = loc;
          _backfillUserIdentity(
            uid: uid,
            pharmacyId: pharmacyId,
            docPath: path,
            data: idx,
            email: cleanEmail,
          ).catchError((_) {});
          return loc;
        }
      }
    } catch (_) {}

    // 3. Direct lookup by derived slug from email
    final emailPrefix = cleanEmail.contains('@') ? cleanEmail.split('@').first : '';
    final potentialSlug = emailPrefix.isNotEmpty ? DatabaseService.slugify(emailPrefix) : '';
    if (potentialSlug.isNotEmpty) {
      try {
        final slugSnap = await _db.collection('pharmacies').doc(potentialSlug).get();
        if (slugSnap.exists && slugSnap.data() != null) {
          final d = slugSnap.data()!;
          final loc = _buildLocationFromDoc(potentialSlug, 'pharmacies/$potentialSlug', d, null, null);
          _locationCache[uid] = loc;
          _backfillUserIdentity(
            uid: uid,
            pharmacyId: potentialSlug,
            docPath: 'pharmacies/$potentialSlug',
            data: d,
            email: cleanEmail,
          ).catchError((_) {});
          return loc;
        }
      } catch (_) {}
    }

    // 4. Direct lookup at pharmacies/{uid}
    try {
      final directDoc = await _db.collection('pharmacies').doc(uid).get();
      if (directDoc.exists && directDoc.data() != null) {
        final d = directDoc.data()!;
        final rawName = (d['pharmacyName'] ?? d['name'] ?? '').toString().trim();
        final slug = rawName.isNotEmpty ? DatabaseService.slugify(rawName) : uid;
        final loc = _buildLocationFromDoc(slug, 'pharmacies/$slug', d, null, null);
        _locationCache[uid] = loc;
        _backfillUserIdentity(
          uid: uid,
          pharmacyId: slug,
          docPath: 'pharmacies/$slug',
          data: d,
          email: cleanEmail,
        ).catchError((_) {});
        return loc;
      }
    } catch (_) {}

    // 5. Query pharmacies by ownerUid (single targeted query)
    try {
      final q = await _db.collection('pharmacies').where('ownerUid', isEqualTo: uid).limit(1).get();
      if (q.docs.isNotEmpty) {
        final doc = q.docs.first;
        final d = doc.data();
        final loc = _buildLocationFromDoc(doc.id, 'pharmacies/${doc.id}', d, null, null);
        _locationCache[uid] = loc;
        _backfillUserIdentity(
          uid: uid,
          pharmacyId: doc.id,
          docPath: 'pharmacies/${doc.id}',
          data: d,
          email: cleanEmail,
        ).catchError((_) {});
        return loc;
      }
    } catch (_) {}

    // 6. Fallback / Auto-provision
    try {
      final autoLocation = await _autoProvisionPharmacy(uid, email);
      _locationCache[uid] = autoLocation;
      return autoLocation;
    } catch (_) {}

    final fallbackSlug = potentialSlug.isNotEmpty ? potentialSlug : 'garhwal-medical-store';
    final fallbackLoc = PharmacyLocation(
      docId: fallbackSlug,
      path: 'pharmacies/$fallbackSlug',
      city: 'Dehradun',
      area: 'Selaqui',
      cityId: 'dehradun',
      areaId: 'selaqui',
      pharmacyName: 'Garhwal Medical Store',
    );
    _locationCache[uid] = fallbackLoc;
    return fallbackLoc;
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
    final words = emailPrefix.split(RegExp(r'[\._\-]')).where((w) => w.isNotEmpty).toList();
    final formattedName = words.isNotEmpty
        ? words.map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ')
        : 'Garhwal Medical Store';
    final handlerName = words.isNotEmpty
        ? '${words.first[0].toUpperCase()}${words.first.substring(1)}'
        : 'Pharmacist';

    String cleanSlug = DatabaseService.slugify(formattedName);
    if (cleanSlug.isEmpty || cleanSlug == 'pharmacy') {
      cleanSlug = 'garhwal-medical-store';
    }

    final rootRef = _db.collection('pharmacies').doc(cleanSlug);
    final nestedLowerRef = _db
        .collection('cities')
        .doc('dehradun')
        .collection('areas')
        .doc('selaqui')
        .collection('pharmacies')
        .doc(cleanSlug);
    final nestedExactRef = _db
        .collection('cities')
        .doc('dehradun')
        .collection('areas')
        .doc('Selaqui')
        .collection('pharmacies')
        .doc(cleanSlug);
    final areaRootRef = _db
        .collection('areas')
        .doc('Selaqui')
        .collection('pharmacies')
        .doc(cleanSlug);

    final profileData = <String, dynamic>{
      'uid': uid,
      'ownerUid': uid,
      'pharmacyId': cleanSlug,
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
    batch.set(nestedLowerRef, profileData, SetOptions(merge: true));
    batch.set(nestedExactRef, profileData, SetOptions(merge: true));
    batch.set(areaRootRef, profileData, SetOptions(merge: true));

    batch.set(_db.collection('pharmacyIndex').doc(cleanSlug), {
      'path': rootRef.path,
      'city': 'Dehradun',
      'area': 'Selaqui',
      'name': formattedName,
      'ownerName': handlerName,
      'email': cleanEmail,
      'ownerUid': uid,
    }, SetOptions(merge: true));
    batch.set(_db.collection('pharmacyIndex').doc(uid), {
      'path': rootRef.path,
      'pharmacyId': cleanSlug,
      'name': formattedName,
      'email': cleanEmail,
    }, SetOptions(merge: true));

    batch.set(_db.collection('users').doc(uid), {
      'pharmacyId': cleanSlug,
      'path': rootRef.path,
      'cityId': 'dehradun',
      'areaId': 'selaqui',
      'email': cleanEmail,
      'pharmacyName': formattedName,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));

    await batch.commit();

    return PharmacyLocation(
      docId: cleanSlug,
      path: rootRef.path,
      city: 'Dehradun',
      area: 'Selaqui',
      cityId: 'dehradun',
      areaId: 'selaqui',
      pharmacyName: formattedName,
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

  Future<void> signOut() async {
    _locationCache.clear();
    await _auth.signOut();
  }

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
