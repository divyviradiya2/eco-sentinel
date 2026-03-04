// ignore_for_file: subtype_of_sealed_class
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swachh_mobile/services/issue_service.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

void main() {
  late IssueService issueService;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollectionReference;
  late MockDocumentReference mockDocumentReference;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollectionReference = MockCollectionReference();
    mockDocumentReference = MockDocumentReference();

    when(
      () => mockFirestore.collection('issues'),
    ).thenReturn(mockCollectionReference);
    when(
      () => mockCollectionReference.doc(any()),
    ).thenReturn(mockDocumentReference);
    when(() => mockDocumentReference.update(any())).thenAnswer((_) async => {});

    // No factory constructor for IssueService yet that takes both,
    // it defaults to instance if not provided.
    // Wait, let's check IssueService constructor again.
    // issue_service.dart:9:   IssueService({FirebaseFirestore? firestore})

    issueService = IssueService(firestore: mockFirestore);
  });

  test(
    'assignTask updates status, assigned_worker_id and assigned_by_contractor_id',
    () async {
      await issueService.assignTask(
        'issue_123',
        'worker_456',
        'contractor_789',
      );

      verify(
        () => mockDocumentReference.update({
          'assigned_worker_id': 'worker_456',
          'assigned_by_contractor_id': 'contractor_789',
          'status': 'Assigned',
        }),
      ).called(1);
    },
  );
}
