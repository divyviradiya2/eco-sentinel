import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';

/// Service responsible for all Firebase Authentication and user document
/// operations. Centralises auth logic so that screens remain thin.
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Validation & Availability helpers
  // ---------------------------------------------------------------------------

  /// Returns a stream of whether more contractors can be registered.
  Stream<bool> contractorAvailabilityStream() {
    return _firestore.collection('metadata').doc('roles').snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return true;
      final data = snapshot.data()!;
      final count = (data['contractor_count'] as num?)?.toInt() ?? 0;
      final max = (data['max_contractors'] as num?)?.toInt() ?? 1;
      return count < max;
    });
  }

  /// One-time check for contractor availability.
  Future<bool> isContractorRegistrationAllowed() async {
    try {
      final doc = await _firestore.collection('metadata').doc('roles').get();
      if (!doc.exists) return true; // Default to allow if doc missing

      final data = doc.data()!;
      final count = (data['contractor_count'] as num?)?.toInt() ?? 0;
      final max = (data['max_contractors'] as num?)?.toInt() ?? 1;

      return count < max;
    } catch (e) {
      debugPrint('Error checking contractor availability: $e');
      return true; // Fallback to allow
    }
  }

  /// Validates a Student enrollment format: ET followed by 2 digits, 4 uppercase
  /// letters, and 3 digits (e.g., ET25BTCO001).
  static bool isValidEnrollment(String value) {
    return RegExp(r'^ET\d{2}[A-Z]{4}\d{3}$').hasMatch(value);
  }

  /// Validates a Faculty ID format: FID- followed by digits.
  static bool isValidFacultyId(String value) {
    return RegExp(r'^FID-\d+$').hasMatch(value);
  }

  /// Validates a Worker/Contractor ID format: W- or C- prefix followed by digits.
  static bool isValidWorkerId(String value) {
    return RegExp(r'^[WC]-\d+$').hasMatch(value);
  }

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Registers a new user with [email], [password], and role-specific metadata.
  Future<AppUser> registerUser({
    required String email,
    required String password,
    required UserRole role,
    String? enrollmentNo,
    String? facultyId,
    String? workerId,
    String displayName = '',
  }) async {
    // Client-side validation guards
    if (role == UserRole.student &&
        (enrollmentNo == null || !isValidEnrollment(enrollmentNo))) {
      throw Exception('Invalid enrollment format: ET25BTCO001');
    }

    if (role == UserRole.faculty &&
        (facultyId == null || !isValidFacultyId(facultyId))) {
      throw Exception('Invalid faculty ID format: FID-1234');
    }

    if ((role == UserRole.worker || role == UserRole.contractor) &&
        (workerId == null || !isValidWorkerId(workerId))) {
      throw Exception('Invalid ID format: W-101 or C-201');
    }

    // Production Hardened: Check limit one last time before creating Auth account
    if (role == UserRole.contractor) {
      final allowed = await isContractorRegistrationAllowed();
      if (!allowed) {
        throw Exception(
          'Maximum number of contractors are registered. You cannot register as a contractor.',
        );
      }
    }

    // 1. Create Firebase Auth account
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;

    // 2. Build the AppUser model
    final appUser = AppUser(
      uid: uid,
      email: email,
      role: role,
      enrollmentNo: enrollmentNo,
      facultyId: facultyId,
      workerId: workerId,
      displayName: displayName.isEmpty ? email.split('@').first : displayName,
    );

    // 3. Write to Firestore & Update Metadata if needed
    final batch = _firestore.batch();
    batch.set(_firestore.collection('users').doc(uid), appUser.toFirestore());

    if (role == UserRole.contractor) {
      batch.update(_firestore.collection('metadata').doc('roles'), {
        'contractor_count': FieldValue.increment(1),
      });
    }

    await batch.commit();

    return appUser;
  }

  // ---------------------------------------------------------------------------
  // Session / Data streams
  // ---------------------------------------------------------------------------

  /// Signs in an existing user with [email] and [password].
  Future<UserCredential> loginWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Returns a stream of the current user's profile document from Firestore.
  Stream<AppUser?> userDocStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
  }

  /// Returns the currently signed-in Firebase user, or `null`.
  User? get currentUser => _auth.currentUser;

  /// Signs out the current user.
  Future<void> signOut() async => _auth.signOut();

  /// Returns a list of all registered workers.
  Future<List<AppUser>> getWorkers() async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .get();

    return querySnapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
  }

  /// Updates the display name for the currently signed-in user in Firestore.
  Future<void> updateDisplayName(String newName) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in.');
    }

    await _firestore.collection('users').doc(user.uid).update({
      'display_name': newName,
    });
  }

  /// Returns a user's profile document from Firestore by UID.
  Future<AppUser?> getUserById(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists ? AppUser.fromFirestore(doc) : null;
  }
}
