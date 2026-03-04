import 'package:cloud_firestore/cloud_firestore.dart';

class CampusLocation {
  final String id;
  final String qrCodeId;
  final String name;
  final String description;
  final GeoPoint coordinates;
  final bool restricted;

  const CampusLocation({
    required this.id,
    required this.qrCodeId,
    required this.name,
    required this.description,
    required this.coordinates,
    this.restricted = false,
  });

  factory CampusLocation.fromMap(Map<String, dynamic> map, String documentId) {
    return CampusLocation(
      id: documentId,
      qrCodeId: map['qr_code_id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown Location',
      description: map['description'] as String? ?? '',
      coordinates: map['coordinates'] as GeoPoint? ?? const GeoPoint(0, 0),
      restricted: map['restricted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'qr_code_id': qrCodeId,
      'name': name,
      'description': description,
      'coordinates': coordinates,
      'restricted': restricted,
    };
  }
}
