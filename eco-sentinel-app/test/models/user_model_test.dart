import 'package:flutter_test/flutter_test.dart';
import 'package:swachh_mobile/models/user_model.dart';

void main() {
  group('UserRole', () {
    test('fromString returns correct enum for valid roles', () {
      expect(UserRole.fromString('student'), UserRole.student);
      expect(UserRole.fromString('faculty'), UserRole.faculty);
      expect(UserRole.fromString('worker'), UserRole.worker);
      expect(UserRole.fromString('contractor'), UserRole.contractor);
      expect(UserRole.fromString('admin'), UserRole.admin);
    });

    test('fromString is case-insensitive', () {
      expect(UserRole.fromString('Student'), UserRole.student);
      expect(UserRole.fromString('FACULTY'), UserRole.faculty);
    });

    test('fromString throws for invalid role', () {
      expect(() => UserRole.fromString('invalid'), throwsArgumentError);
      expect(() => UserRole.fromString(''), throwsArgumentError);
    });
  });

  group('AppUser', () {
    test('toFirestore produces snake_case keys', () {
      final user = AppUser(
        uid: 'test-uid',
        email: 'test@example.com',
        role: UserRole.student,
        enrollmentNo: 'ET25BTCO001',
      );

      final map = user.toFirestore();
      expect(map.containsKey('email'), true);
      expect(map.containsKey('role'), true);
      expect(map.containsKey('enrollment_no'), true);
      expect(map.containsKey('worker_id'), true);
      expect(map.containsKey('display_name'), true);
      expect(map.containsKey('points'), true);
      expect(map.containsKey('rating'), true);
      expect(map.containsKey('spam_strikes'), true);
      expect(map.containsKey('is_flagged'), true);
      expect(map.containsKey('created_at'), true);
    });

    test('toFirestore serialises role as lowercase string', () {
      final user = AppUser(
        uid: 'uid',
        email: 'a@b.com',
        role: UserRole.contractor,
      );
      expect(user.toFirestore()['role'], 'contractor');
    });

    test('defaults are applied correctly', () {
      final user = AppUser(uid: 'uid', email: 'a@b.com', role: UserRole.worker);
      expect(user.points, 0);
      expect(user.rating, 0.0);
      expect(user.displayName, '');
      expect(user.spamStrikes, 0);
      expect(user.isFlagged, false);
    });
  });
}
