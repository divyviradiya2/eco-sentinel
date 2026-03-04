import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swachh_mobile/services/auth_service.dart';

void main() {
  group('AuthService.isValidEnrollment', () {
    test('accepts valid enrollment numbers', () {
      expect(AuthService.isValidEnrollment('ET25BTCO001'), true);
      expect(AuthService.isValidEnrollment('ET22CSEE123'), true);
      expect(AuthService.isValidEnrollment('ET99ABCD999'), true);
    });

    test('rejects invalid formats', () {
      // Missing ET prefix
      expect(AuthService.isValidEnrollment('25BTCO001'), false);
      // Too short
      expect(AuthService.isValidEnrollment('ET25BTC001'), false);
      // Lowercase letters
      expect(AuthService.isValidEnrollment('ET25btco001'), false);
      // Extra characters
      expect(AuthService.isValidEnrollment('ET25BTCO0011'), false);
      // Empty
      expect(AuthService.isValidEnrollment(''), false);
    });
  });

  group('AuthService.isValidFacultyId', () {
    test('accepts valid faculty IDs', () {
      expect(AuthService.isValidFacultyId('FID-1234'), true);
      expect(AuthService.isValidFacultyId('FID-1'), true);
    });

    test('rejects invalid faculty IDs', () {
      expect(AuthService.isValidFacultyId('1234'), false);
      expect(AuthService.isValidFacultyId('F-1234'), false);
      expect(AuthService.isValidFacultyId('FID-abc'), false);
      expect(AuthService.isValidFacultyId(''), false);
    });
  });

  group('AuthService.isValidWorkerId', () {
    test('accepts valid worker IDs', () {
      expect(AuthService.isValidWorkerId('W-101'), true);
      expect(AuthService.isValidWorkerId('W-1'), true);
      expect(AuthService.isValidWorkerId('C-201'), true);
      expect(AuthService.isValidWorkerId('C-99'), true);
    });

    test('rejects invalid worker IDs', () {
      // Missing prefix
      expect(AuthService.isValidWorkerId('101'), false);
      // Wrong prefix
      expect(AuthService.isValidWorkerId('X-101'), false);
      // Missing dash
      expect(AuthService.isValidWorkerId('W101'), false);
      // Letters after dash
      expect(AuthService.isValidWorkerId('W-abc'), false);
      // Empty
      expect(AuthService.isValidWorkerId(''), false);
    });
  });

  group('AuthService.loginWithEmail', () {
    test('calls signInWithEmailAndPassword with correct parameters', () async {
      final mockAuth = MockFirebaseAuth();
      final mockFirestore = MockFirebaseFirestore();
      final mockCredential = MockUserCredential();

      when(
        () => mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).thenAnswer((_) async => mockCredential);

      final authService = AuthService(auth: mockAuth, firestore: mockFirestore);

      final result = await authService.loginWithEmail(
        'test@example.com',
        'password123',
      );

      expect(result, equals(mockCredential));
      verify(
        () => mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).called(1);
    });
  });

  group('AuthService.updateDisplayName', () {
    test('updates display_name in firestore for current user', () async {
      final mockAuth = MockFirebaseAuth();
      final mockFirestore = MockFirebaseFirestore();
      final mockUser = MockUser();
      final mockCollection = MockCollectionReference();
      final mockDocument = MockDocumentReference();

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('user123');

      when(() => mockFirestore.collection('users')).thenReturn(mockCollection);
      when(() => mockCollection.doc('user123')).thenReturn(mockDocument);
      when(
        () => mockDocument.update({'display_name': 'New Alias'}),
      ).thenAnswer((_) async {});

      final authService = AuthService(auth: mockAuth, firestore: mockFirestore);

      await authService.updateDisplayName('New Alias');

      verify(
        () => mockDocument.update({'display_name': 'New Alias'}),
      ).called(1);
    });

    test('throws exception if current user is null', () async {
      final mockAuth = MockFirebaseAuth();
      final mockFirestore = MockFirebaseFirestore();

      when(() => mockAuth.currentUser).thenReturn(null);

      final authService = AuthService(auth: mockAuth, firestore: mockFirestore);

      expect(
        () => authService.updateDisplayName('New Alias'),
        throwsA(isA<Exception>()),
      );
    });
  });
}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}
