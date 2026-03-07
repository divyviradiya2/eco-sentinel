import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/campus_location.dart';

class LocationService {
  final FirebaseFirestore _firestore;

  LocationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<CampusLocation?> getLocationByQrCodeId(String qrCodeId) async {
    try {
      final querySnapshot = await _firestore
          .collection('locations')
          .where('qr_code_id', isEqualTo: qrCodeId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return CampusLocation.fromMap(
          querySnapshot.docs.first.data(),
          querySnapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch location by QR code: $e');
    }
  }

  Future<List<CampusLocation>> getLocations() async {
    try {
      final querySnapshot = await _firestore.collection('locations').get();
      return querySnapshot.docs
          .map((doc) => CampusLocation.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch locations: $e');
    }
  }

  Future<CampusLocation?> getLocationById(String id) async {
    try {
      final doc = await _firestore.collection('locations').doc(id).get();
      if (doc.exists) {
        return CampusLocation.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch location by ID: $e');
    }
  }

  /// Fetches global campus geofence configuration
  Future<Map<String, dynamic>?> getCampusGeofence() async {
    try {
      final doc = await _firestore
          .collection('metadata')
          .doc('campus_configs')
          .get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching campus geofence: $e');
      return null;
    }
  }
}
