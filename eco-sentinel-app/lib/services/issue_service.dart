import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swachh_mobile/models/issue_model.dart';
import 'package:swachh_mobile/services/storage_service.dart';

class IssueService {
  final FirebaseFirestore _firestore;

  IssueService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Creates a new issue report in Firestore.
  Future<void> createIssue({
    required String locationId,
    required String locationName,
    required String description,
    required String imageUrl,
    required String reporterId,
    GeoPoint? exactCoordinates,
  }) async {
    await _firestore.collection('issues').add({
      'location_id': locationId,
      'location_name': locationName,
      'description': description,
      'image_url': imageUrl,
      'reporter_id': reporterId,
      'exact_coordinates': exactCoordinates,
      'status': 'Reported',
      'created_at': FieldValue.serverTimestamp(),
      'assigned_worker_id': null,
      'completion_image_url': null,
      'rating_by_reporter': null,
      'contractor_feedback': null,
    });
  }

  /// Returns a real-time stream of issues reported by a specific user.
  Stream<List<IssueModel>> getMyIssuesStream(String userId) {
    return _firestore
        .collection('issues')
        .where('reporter_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => IssueModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Returns a real-time stream of issues assigned to a specific worker.
  Stream<List<IssueModel>> getWorkerTasksStream(String workerId) {
    return _firestore
        .collection('issues')
        .where('assigned_worker_id', isEqualTo: workerId)
        .where(
          'status',
          whereIn: [
            'Assigned',
            'In_Progress',
            'Completed_Pending_Review',
            'Closed',
          ],
        )
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => IssueModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Returns a real-time stream of all reported issues (for Contractors).
  Stream<List<IssueModel>> getReportedIssuesStream() {
    return _firestore
        .collection('issues')
        .where('status', isEqualTo: 'Reported')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => IssueModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Returns a real-time stream of issues pending verification (for Contractors).
  Stream<List<IssueModel>> getPendingReviewIssuesStream() {
    return _firestore
        .collection('issues')
        .where('status', isEqualTo: 'Completed_Pending_Review')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => IssueModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Returns a real-time stream of active issues (Assigned or In_Progress) for Contractors.
  Stream<List<IssueModel>> getActiveIssuesStream() {
    return _firestore
        .collection('issues')
        .where('status', whereIn: ['Assigned', 'In_Progress'])
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => IssueModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Returns a real-time stream of all closed/verified issues.
  Stream<List<IssueModel>> getClosedIssuesStream() {
    return _firestore
        .collection('issues')
        .where('status', isEqualTo: 'Closed')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => IssueModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Assigns a reported issue to a specific worker.
  Future<void> assignTask(
    String issueId,
    String workerId,
    String contractorId,
  ) async {
    await _firestore.collection('issues').doc(issueId).update({
      'assigned_worker_id': workerId,
      'assigned_by_contractor_id': contractorId,
      'status': 'Assigned',
    });
  }

  /// Marks a task as completed with geo-validated photo evidence.
  Future<void> completeTask(String issueId, File imageFile) async {
    // 1. Upload completion photo
    final storageService = StorageService();
    final imageUrl = await storageService.uploadIssuePhoto(imageFile);

    // 2. Update issue in Firestore
    await _firestore.collection('issues').doc(issueId).update({
      'completion_image_url': imageUrl,
      'status': 'Completed_Pending_Review',
    });
  }

  /// Verifies a completed task and closes the issue.
  /// This updates the issue status and accurately reflects the performance
  /// on the assigned worker's profile using a Firestore transaction.
  Future<void> verifyTask(
    String issueId, {
    int? rating,
    String? feedback,
  }) async {
    await _firestore.runTransaction((transaction) async {
      // 1. PERFORM ALL READS FIRST
      final issueRef = _firestore.collection('issues').doc(issueId);
      final issueDoc = await transaction.get(issueRef);
      final workerId = issueDoc.data()?['assigned_worker_id'] as String?;
      final reporterId = issueDoc.data()?['reporter_id'] as String?;

      DocumentSnapshot<Map<String, dynamic>>? workerDoc;
      DocumentReference<Map<String, dynamic>>? workerRef;

      if (workerId != null && rating != null) {
        workerRef = _firestore.collection('users').doc(workerId);
        workerDoc = await transaction.get(workerRef);
      }

      DocumentSnapshot<Map<String, dynamic>>? reporterDoc;
      DocumentReference<Map<String, dynamic>>? reporterRef;

      if (reporterId != null) {
        reporterRef = _firestore.collection('users').doc(reporterId);
        reporterDoc = await transaction.get(reporterRef);
      }

      // 2. PERFORM ALL WRITES SECOND
      // Update issue status
      transaction.update(issueRef, {
        'status': 'Closed',
        'verification_rating': rating,
        'contractor_feedback': feedback,
        'verified_at': FieldValue.serverTimestamp(),
      });

      // Update worker profile if applicable
      if (workerDoc != null && workerRef != null && workerDoc.exists) {
        final data = workerDoc.data() as Map<String, dynamic>;
        final currentTotalRating =
            (data['total_rating'] as num?)?.toDouble() ?? 0.0;
        final currentCount =
            (data['completed_tasks_count'] as num?)?.toInt() ?? 0;

        final newCount = currentCount + 1;
        final newTotalRating = currentTotalRating + rating!.toDouble();
        final newAverageRating = newTotalRating / newCount;

        // Efficiently update worker's average rating
        transaction.update(workerRef, {
          'total_rating': newTotalRating,
          'completed_tasks_count': newCount,
          'rating': double.parse(newAverageRating.toStringAsFixed(2)),
        });
      }

      // Reward reporter
      if (reporterDoc != null && reporterRef != null && reporterDoc.exists) {
        transaction.update(reporterRef, {'points': FieldValue.increment(10)});
      }
    });
  }

  /// Rejects a completed task and reverts status to Assigned.
  Future<void> rejectTask(String issueId, String reason) async {
    await _firestore.collection('issues').doc(issueId).update({
      'status': 'Assigned',
      'rejection_notes': reason,
    });
  }

  /// Verifies a completed task by the original reporter (Student/Faculty).
  Future<void> verifyTaskByReporter(
    String issueId, {
    required int rating,
    required String feedback,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final issueRef = _firestore.collection('issues').doc(issueId);
      final issueDoc = await transaction.get(issueRef);
      final workerId = issueDoc.data()?['assigned_worker_id'] as String?;

      DocumentSnapshot<Map<String, dynamic>>? workerDoc;
      DocumentReference<Map<String, dynamic>>? workerRef;

      if (workerId != null) {
        workerRef = _firestore.collection('users').doc(workerId);
        workerDoc = await transaction.get(workerRef);
      }

      // Update issue status and reporter feedback
      transaction.update(issueRef, {
        'status': 'Closed',
        'rating_by_reporter': rating,
        'reporter_feedback': feedback,
        'verified_at': FieldValue.serverTimestamp(),
      });

      // Update worker profile (same logic as contractor verification)
      if (workerDoc != null && workerRef != null && workerDoc.exists) {
        final data = workerDoc.data() as Map<String, dynamic>;
        final currentTotalRating =
            (data['total_rating'] as num?)?.toDouble() ?? 0.0;
        final currentCount =
            (data['completed_tasks_count'] as num?)?.toInt() ?? 0;

        final newCount = currentCount + 1;
        final newTotalRating = currentTotalRating + rating.toDouble();
        final newAverageRating = newTotalRating / newCount;

        // Efficiently update worker's average rating
        transaction.update(workerRef, {
          'total_rating': newTotalRating,
          'completed_tasks_count': newCount,
          'rating': double.parse(newAverageRating.toStringAsFixed(2)),
        });
      }
    });
  }

  /// Flags a student-reported issue as spam, updates issue status,
  /// and penalizes the reporter in a single transaction.
  Future<void> flagIssueAsSpam(String issueId, String reporterId) async {
    await _firestore.runTransaction((transaction) async {
      final issueRef = _firestore.collection('issues').doc(issueId);
      final userRef = _firestore.collection('users').doc(reporterId);

      // Perform all reads first
      final issueDoc = await transaction.get(issueRef);
      final userDoc = await transaction.get(userRef);

      if (!issueDoc.exists) {
        throw Exception('Issue not found');
      }

      final issueData = issueDoc.data();
      if (issueData?['status'] != 'Reported') {
        throw Exception('Only new reports can be flagged as spam.');
      }

      // Perform all writes
      transaction.update(issueRef, {
        'status': 'Flagged',
        'flagged_at': FieldValue.serverTimestamp(),
      });

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final currentPoints = (data['points'] as num?)?.toInt() ?? 0;
        final currentStrikes = (data['spam_strikes'] as num?)?.toInt() ?? 0;

        // Deduct points (e.g. 10 points), floor at 0
        int newPoints = currentPoints - 10;
        if (newPoints < 0) newPoints = 0;

        final newStrikes = currentStrikes + 1;
        // Optionally flag the user if they hit a threshold of strikes
        final isFlagged = newStrikes >= 3;

        transaction.update(userRef, {
          'points': newPoints,
          'spam_strikes': newStrikes,
          if (isFlagged) 'is_flagged': true,
        });
      }
    });
  }
}
