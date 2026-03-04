// ignore_for_file: subtype_of_sealed_class
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swachh_mobile/services/issue_service.dart';
import 'dart:async';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {
  /// Settable transaction handler to bypass mocktail generic method limitation.
  /// Set this in your test before calling code that uses runTransaction.
  MockTransaction? mockTransactionInstance;

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> updateFunction, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    return await updateFunction(mockTransactionInstance!);
  }
}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class MockTransaction extends Mock implements Transaction {}

class MockDocumentSnapshot<T extends Object?> extends Mock
    implements DocumentSnapshot<T> {}

void main() {
  late IssueService issueService;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollectionReference;
  late MockDocumentReference mockDocumentReference;
  late MockQuery mockQuery;
  late MockQuery mockQueryOrdered;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollectionReference = MockCollectionReference();
    mockDocumentReference = MockDocumentReference();
    mockQuery = MockQuery();
    mockQueryOrdered = MockQuery();

    when(
      () => mockFirestore.collection('issues'),
    ).thenReturn(mockCollectionReference);
    when(
      () => mockCollectionReference.add(any()),
    ).thenAnswer((_) async => mockDocumentReference);

    issueService = IssueService(firestore: mockFirestore);
  });

  test('createIssue adds a document to issues collection', () async {
    await issueService.createIssue(
      locationId: 'loc_123',
      locationName: 'Main Entrance',
      description: 'Broken pipe',
      imageUrl: 'https://example.com/photo.jpg',
      reporterId: 'user_456',
    );

    verify(
      () => mockCollectionReference.add(any(that: isA<Map<String, dynamic>>())),
    ).called(1);
  });

  test('getMyIssuesStream returns stream of issues', () async {
    when(
      () => mockCollectionReference.where(
        'reporter_id',
        isEqualTo: any(named: 'isEqualTo'),
      ),
    ).thenReturn(mockQuery);
    when(
      () =>
          mockQuery.orderBy('created_at', descending: any(named: 'descending')),
    ).thenReturn(mockQueryOrdered);

    final mockSnapshot = MockQuerySnapshot();
    final mockDoc = MockQueryDocumentSnapshot();

    when(() => mockDoc.id).thenReturn('issue_1');
    when(() => mockDoc.data()).thenReturn({
      'location_id': 'loc_1',
      'description': 'test desc',
      'image_url': 'http://imgbb.../img.jpg',
      'reporter_id': 'user_1',
      'status': 'Reported',
      'created_at': Timestamp.fromDate(DateTime(2023, 1, 1)),
    });

    when(() => mockSnapshot.docs).thenReturn([mockDoc]);

    final streamController =
        StreamController<QuerySnapshot<Map<String, dynamic>>>();
    when(
      () => mockQueryOrdered.snapshots(),
    ).thenAnswer((_) => streamController.stream);

    final stream = issueService.getMyIssuesStream('user_1');

    streamController.add(mockSnapshot);

    final issues = await stream.first;
    expect(issues.length, 1);
    expect(issues.first.id, 'issue_1');
    expect(issues.first.status, 'Reported');
    expect(issues.first.locationId, 'loc_1');

    streamController.close();
  });

  test('getWorkerTasksStream returns stream of assigned issues', () async {
    final mockQueryFiltered = MockQuery();
    when(
      () => mockCollectionReference.where(
        'assigned_worker_id',
        isEqualTo: any(named: 'isEqualTo'),
      ),
    ).thenReturn(mockQuery);
    when(
      () => mockQuery.where('status', whereIn: any(named: 'whereIn')),
    ).thenReturn(mockQueryFiltered);
    when(
      () => mockQueryFiltered.orderBy(
        'created_at',
        descending: any(named: 'descending'),
      ),
    ).thenReturn(mockQueryOrdered);

    final mockSnapshot = MockQuerySnapshot();
    final mockDoc = MockQueryDocumentSnapshot();

    when(() => mockDoc.id).thenReturn('issue_2');
    when(() => mockDoc.data()).thenReturn({
      'location_id': 'loc_2',
      'description': 'worker task',
      'image_url': 'img',
      'reporter_id': 'user_1',
      'status': 'Assigned',
      'created_at': Timestamp.fromDate(DateTime(2023, 1, 1)),
      'assigned_worker_id': 'worker_1',
    });

    when(() => mockSnapshot.docs).thenReturn([mockDoc]);

    final streamController =
        StreamController<QuerySnapshot<Map<String, dynamic>>>();
    when(
      () => mockQueryOrdered.snapshots(),
    ).thenAnswer((_) => streamController.stream);

    final stream = issueService.getWorkerTasksStream('worker_1');

    streamController.add(mockSnapshot);

    final tasks = await stream.first;
    expect(tasks.length, 1);
    expect(tasks.first.id, 'issue_2');
    expect(tasks.first.status, 'Assigned');
    expect(tasks.first.assignedWorkerId, 'worker_1');

    streamController.close();
  });

  test(
    'flagIssueAsSpam updates issue state and deducts points from reporter',
    () async {
      final mockTransaction = MockTransaction();
      mockFirestore.mockTransactionInstance = mockTransaction;

      final issueDocRef = MockDocumentReference();
      when(
        () => mockCollectionReference.doc('issue_1'),
      ).thenReturn(issueDocRef);

      final mockIssueDoc = MockDocumentSnapshot<Map<String, dynamic>>();
      when(
        () => mockTransaction.get(issueDocRef),
      ).thenAnswer((_) async => mockIssueDoc);
      when(() => mockIssueDoc.exists).thenReturn(true);
      when(
        () => mockIssueDoc.data(),
      ).thenReturn({'reporter_id': 'user_1', 'status': 'Reported'});

      final userDocRef = MockDocumentReference();
      final mockUserCollection = MockCollectionReference();
      when(
        () => mockFirestore.collection('users'),
      ).thenReturn(mockUserCollection);
      when(() => mockUserCollection.doc('user_1')).thenReturn(userDocRef);

      final mockUserDoc = MockDocumentSnapshot<Map<String, dynamic>>();
      when(
        () => mockTransaction.get(userDocRef),
      ).thenAnswer((_) async => mockUserDoc);
      when(() => mockUserDoc.exists).thenReturn(true);
      when(
        () => mockUserDoc.data(),
      ).thenReturn({'points': 50, 'spam_strikes': 1});

      when(
        () => mockTransaction.update(issueDocRef, any()),
      ).thenReturn(mockTransaction);
      when(
        () => mockTransaction.update(userDocRef, any()),
      ).thenReturn(mockTransaction);

      await issueService.flagIssueAsSpam('issue_1', 'user_1');

      // Capture and verify issue update
      final capturedIssueArgs = verify(
        () => mockTransaction.update(issueDocRef, captureAny()),
      ).captured;
      expect(capturedIssueArgs.length, 1);
      final issueUpdateMap = capturedIssueArgs.first as Map<String, dynamic>;
      expect(issueUpdateMap['status'], 'Flagged');
      expect(issueUpdateMap.containsKey('flagged_at'), isTrue);

      // Verify user update
      verify(
        () => mockTransaction.update(userDocRef, {
          'points': 40,
          'spam_strikes': 2,
        }),
      ).called(1);
    },
  );

  test(
    'flagIssueAsSpam floors points at 0 and flags user at 3 strikes',
    () async {
      final mockTransaction = MockTransaction();
      mockFirestore.mockTransactionInstance = mockTransaction;

      final issueDocRef = MockDocumentReference();
      when(
        () => mockCollectionReference.doc('issue_1'),
      ).thenReturn(issueDocRef);

      final mockIssueDoc = MockDocumentSnapshot<Map<String, dynamic>>();
      when(
        () => mockTransaction.get(issueDocRef),
      ).thenAnswer((_) async => mockIssueDoc);
      when(() => mockIssueDoc.exists).thenReturn(true);
      when(
        () => mockIssueDoc.data(),
      ).thenReturn({'reporter_id': 'user_1', 'status': 'Reported'});

      final userDocRef = MockDocumentReference();
      final mockUserCollection = MockCollectionReference();
      when(
        () => mockFirestore.collection('users'),
      ).thenReturn(mockUserCollection);
      when(() => mockUserCollection.doc('user_1')).thenReturn(userDocRef);

      final mockUserDoc = MockDocumentSnapshot<Map<String, dynamic>>();
      when(
        () => mockTransaction.get(userDocRef),
      ).thenAnswer((_) async => mockUserDoc);
      when(() => mockUserDoc.exists).thenReturn(true);
      when(
        () => mockUserDoc.data(),
      ).thenReturn({'points': 5, 'spam_strikes': 2});

      when(
        () => mockTransaction.update(issueDocRef, any()),
      ).thenReturn(mockTransaction);
      when(
        () => mockTransaction.update(userDocRef, any()),
      ).thenReturn(mockTransaction);

      await issueService.flagIssueAsSpam('issue_1', 'user_1');

      verify(
        () => mockTransaction.update(userDocRef, {
          'points': 0,
          'spam_strikes': 3,
          'is_flagged': true,
        }),
      ).called(1);
    },
  );
}
