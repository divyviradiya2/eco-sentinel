import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum representing the 5 user roles in Swachh Campus 360.
enum UserRole {
  student,
  faculty,
  worker,
  contractor,
  admin;

  /// Converts a raw string from Firestore to a [UserRole].
  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value.toLowerCase(),
      orElse: () => throw ArgumentError('Invalid role: $value'),
    );
  }
}

/// Data model representing a user document in the `users` Firestore collection.
class AppUser {
  final String uid;
  final String email;
  final UserRole role;
  final String? enrollmentNo;
  final String? facultyId;
  final String? workerId;
  final String displayName;
  final String? realName;
  final int points;
  final double rating;
  final double totalRating;
  final int completedTasksCount;
  final int spamStrikes;
  final bool isFlagged;
  final Timestamp createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.enrollmentNo,
    this.facultyId,
    this.workerId,
    this.displayName = '',
    this.realName,
    this.points = 0,
    this.rating = 0.0,
    this.totalRating = 0.0,
    this.completedTasksCount = 0,
    this.spamStrikes = 0,
    this.isFlagged = false,
    Timestamp? createdAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  /// Creates an [AppUser] from a Firestore document snapshot.
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      role: UserRole.fromString(data['role'] as String),
      enrollmentNo: data['enrollment_no'] as String?,
      facultyId: data['faculty_id'] as String?,
      workerId: data['worker_id'] as String?,
      displayName: data['display_name'] as String? ?? '',
      realName: data['real_name'] as String?,
      points: (data['points'] as num?)?.toInt() ?? 0,
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      totalRating: (data['total_rating'] as num?)?.toDouble() ?? 0.0,
      completedTasksCount:
          (data['completed_tasks_count'] as num?)?.toInt() ?? 0,
      spamStrikes: (data['spam_strikes'] as num?)?.toInt() ?? 0,
      isFlagged: data['is_flagged'] as bool? ?? false,
      createdAt: data['created_at'] as Timestamp? ?? Timestamp.now(),
    );
  }

  /// Converts this [AppUser] to a Firestore-compatible map.
  /// Production implementation: Only includes fields relevant to the user's role
  /// to keep documents clean and enforce schema integrity.
  Map<String, dynamic> toFirestore() {
    // Base fields common to all users
    final map = <String, dynamic>{
      'email': email,
      'role': role.name,
      'display_name': displayName,
      'created_at': createdAt,
    };

    // Role-specific fields
    switch (role) {
      case UserRole.student:
        map['enrollment_no'] = enrollmentNo;
        map['points'] = points;
        map['spam_strikes'] = spamStrikes;
        map['is_flagged'] = isFlagged;
        break;
      case UserRole.faculty:
        map['faculty_id'] = facultyId;
        map['real_name'] = realName;
        map['points'] = points;
        map['spam_strikes'] = spamStrikes;
        map['is_flagged'] = isFlagged;
        break;
      case UserRole.worker:
        map['worker_id'] = workerId;
        map['rating'] = rating;
        map['total_rating'] = totalRating;
        map['completed_tasks_count'] = completedTasksCount;
        break;
      case UserRole.contractor:
        map['worker_id'] = workerId;
        break;
      case UserRole.admin:
        break;
    }

    return map;
  }
}
