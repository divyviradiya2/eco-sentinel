import 'package:cloud_firestore/cloud_firestore.dart';

class IssueModel {
  final String id;
  final String locationId;
  final String locationName;
  final String description;
  final String imageUrl;
  final String reporterId;
  final String status;
  final DateTime createdAt;
  final String? assignedWorkerId;
  final String? assignedByContractorId;
  final String? completionImageUrl;
  final int? ratingByReporter;
  final String? contractorFeedback;
  final String? reporterFeedback;
  final int? verificationRating;
  final String? rejectionNotes;
  final GeoPoint? exactCoordinates;

  IssueModel({
    required this.id,
    required this.locationId,
    required this.locationName,
    required this.description,
    required this.imageUrl,
    required this.reporterId,
    required this.status,
    required this.createdAt,
    this.assignedWorkerId,
    this.assignedByContractorId,
    this.completionImageUrl,
    this.ratingByReporter,
    this.contractorFeedback,
    this.reporterFeedback,
    this.verificationRating,
    this.rejectionNotes,
    this.exactCoordinates,
  });

  factory IssueModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return IssueModel(
      id: doc.id,
      locationId: data['location_id'] ?? '',
      locationName: data['location_name'] ?? (data['location_id'] ?? ''),
      description: data['description'] ?? '',
      imageUrl: data['image_url'] ?? '',
      reporterId: data['reporter_id'] ?? '',
      status: data['status'] ?? 'Reported',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assignedWorkerId: data['assigned_worker_id'],
      assignedByContractorId: data['assigned_by_contractor_id'],
      completionImageUrl: data['completion_image_url'],
      ratingByReporter: data['rating_by_reporter'],
      contractorFeedback: data['contractor_feedback'],
      reporterFeedback: data['reporter_feedback'],
      verificationRating: data['verification_rating'],
      rejectionNotes: data['rejection_notes'],
      exactCoordinates: data['exact_coordinates'] as GeoPoint?,
    );
  }
}
