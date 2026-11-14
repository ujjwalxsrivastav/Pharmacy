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

    await batch.commit();
    return credential;
  }

  // ─── Locate Exact Pharmacy Document in Backend ────────────────────────────
  Future<PharmacyLocation> resolvePharmacyLocation(String uid, String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final defaultPrefix = cleanEmail.split('@').first.toLowerCase();

    try {
      // 1. Fetch all documents from 'pharmacies' collection
      final snap = await _db.collection('pharmacies').get();

      QueryDocumentSnapshot<Map<String, dynamic>>? realDoc;
      QueryDocumentSnapshot<Map<String, dynamic>>? dummyDoc;

      for (final doc in snap.docs) {
        final d = doc.data();
        final docEmail = (d['email'] ?? '').toString().trim().toLowerCase();
        final docOwnerUid = (d['ownerUid'] ?? '').toString().trim();
        final docName = (d['name'] ?? d['pharmacyName'] ?? '').toString().trim();
        final docOwner = (d['ownerName'] ?? d['handlerName'] ?? '').toString().trim();

        final matchesUser = (docEmail == cleanEmail && cleanEmail.isNotEmpty) ||
            docOwnerUid == uid ||
            doc.id == uid;

        if (matchesUser) {
          // Check if this doc is the auto-generated dummy placeholder (CEO / Pharmacist)
          final isDummy = (doc.id == uid &&
              (docName.toUpperCase() == 'CEO' || docName.toLowerCase() == defaultPrefix) &&
              (docOwner == 'Pharmacist' || docOwner.isEmpty));

          if (isDummy) {
            dummyDoc = doc;
          } else {
            // Found the real registered backend document (e.g. "Test")!
            realDoc = doc;
          }
        }
      }

      // If we found both a real doc and a dummy doc, delete the dummy doc to clean up!
      if (realDoc != null && dummyDoc != null) {
        try {
          await _db.collection('pharmacies').doc(dummyDoc.id).delete();
          await _db.collection('pharmacyIndex').doc(dummyDoc.id).delete();
        } catch (_) {}
      }

      final chosen = realDoc ?? dummyDoc;

      if (chosen != null) {
        final d = chosen.data();
        final city = (d['city'] ?? d['cityId'] ?? 'Dehradun').toString();
        final area = (d['area'] ?? d['areaId'] ?? 'Selaqui').toString();

        // Ensure ownerUid matches the logged-in user
        if ((d['ownerUid'] ?? '').toString() != uid) {
          try {
            await chosen.reference.update({'ownerUid': uid});
          } catch (_) {}
        }

        // Also ensure it is mirrored in cities > areas > pharmacies
        try {
          final cKey = PharmacyProfile.toKey(city);
          final aKey = PharmacyProfile.toKey(area);
          await _db
              .collection('cities')
              .doc(cKey)
              .collection('areas')
              .doc(aKey)
              .collection('pharmacies')
              .doc(chosen.id)
              .set(d, SetOptions(merge: true));
        } catch (_) {}

        return PharmacyLocation(
          docId: chosen.id,
          path: chosen.reference.path,
          city: city,
          area: area,
        );
      }
    } catch (_) {}

    // Fallback: search collectionGroup('pharmacies')
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

    // Safe fallback if no doc found at all
    final defaultPath = 'pharmacies/$uid';
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
              .update(updateData);
        }
      }
    } catch (_) {}
  }

  Future<void> signOut() async => await _auth.signOut();
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
