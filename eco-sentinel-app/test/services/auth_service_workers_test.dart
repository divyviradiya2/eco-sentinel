// ignore_for_file: subtype_of_sealed_class
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swachh_mobile/services/auth_service.dart';
import 'package:swachh_mobile/models/user_model.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late AuthService authService;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseAuth mockAuth;
  late MockCollectionReference mockCollectionReference;
  late MockQuery mockQuery;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockCollectionReference = MockCollectionReference();
    mockQuery = MockQuery();

    when(
      () => mockFirestore.collection('users'),
    ).thenReturn(mockCollectionReference);
    authService = AuthService(auth: mockAuth, firestore: mockFirestore);
  });

  test('getWorkers returns list of workers from Firestore', () async {
    when(
      () => mockCollectionReference.where('role', isEqualTo: 'worker'),
    ).thenReturn(mockQuery);

    final mockSnapshot = MockQuerySnapshot();
    final mockDoc = MockQueryDocumentSnapshot();

    when(() => mockDoc.id).thenReturn('worker_1');
    when(() => mockDoc.data()).thenReturn({
      'uid': 'worker_1',
      'email': 'worker@test.com',
      'role': 'worker',
    });
    when(() => mockSnapshot.docs).thenReturn([mockDoc]);
    when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);

    // This will fail because getWorkers doesn't exist yet
    final workers = await authService.getWorkers();

    expect(workers.length, 1);
    expect(workers.first.uid, 'worker_1');
    expect(workers.first.role, UserRole.worker);
  });
}
