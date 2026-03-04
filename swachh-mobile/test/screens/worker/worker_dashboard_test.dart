import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:swachh_mobile/models/issue_model.dart';
import 'package:swachh_mobile/providers/issue_provider.dart';
import 'package:swachh_mobile/screens/worker/worker_dashboard.dart';
import 'package:swachh_mobile/providers/auth_provider.dart';
import 'package:swachh_mobile/models/user_model.dart';

class MockIssueProvider extends Mock implements IssueProvider {}

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  late MockIssueProvider mockIssueProvider;
  late MockAuthProvider mockAuthProvider;

  setUp(() {
    mockIssueProvider = MockIssueProvider();
    mockAuthProvider = MockAuthProvider();

    final testWorker = AppUser(
      uid: 'worker123',
      email: 'worker@test.com',
      role: UserRole.worker,
      displayName: 'Suresh',
    );
    when(() => mockAuthProvider.appUser).thenReturn(testWorker);
  });

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ChangeNotifierProvider<IssueProvider>.value(value: mockIssueProvider),
      ],
      child: const MaterialApp(home: WorkerDashboard()),
    );
  }

  testWidgets('WorkerDashboard displays list of assigned tasks', (
    tester,
  ) async {
    final tasks = [
      IssueModel(
        id: '1',
        locationId: 'loc1',
        locationName: 'Washroom A',
        description: 'Leaking tap',
        imageUrl: 'url1',
        reporterId: 'rep1',
        status: 'Assigned',
        createdAt: DateTime.now(),
      ),
    ];

    when(() => mockIssueProvider.isLoading).thenReturn(false);
    when(() => mockIssueProvider.errorMessage).thenReturn(null);
    when(() => mockIssueProvider.workerTasks).thenReturn(tasks);
    when(() => mockIssueProvider.listenToWorkerTasks(any())).thenReturn(null);

    await tester.pumpWidget(buildTestWidget());

    expect(find.text('Washroom A'), findsOneWidget);
    expect(find.text('Leaking tap'), findsOneWidget);
    expect(find.text('Assigned'), findsOneWidget);
  });

  testWidgets('WorkerDashboard displays empty state when no tasks', (
    tester,
  ) async {
    when(() => mockIssueProvider.isLoading).thenReturn(false);
    when(() => mockIssueProvider.errorMessage).thenReturn(null);
    when(() => mockIssueProvider.workerTasks).thenReturn([]);
    when(() => mockIssueProvider.listenToWorkerTasks(any())).thenReturn(null);

    await tester.pumpWidget(buildTestWidget());

    expect(find.text('No tasks assigned'), findsOneWidget);
    expect(find.text('Keep it up!'), findsOneWidget);
  });

  testWidgets('WorkerDashboard displays error message on failure', (
    tester,
  ) async {
    when(() => mockIssueProvider.isLoading).thenReturn(false);
    when(
      () => mockIssueProvider.errorMessage,
    ).thenReturn('Index missing error');
    when(() => mockIssueProvider.workerTasks).thenReturn([]);
    when(() => mockIssueProvider.listenToWorkerTasks(any())).thenReturn(null);

    await tester.pumpWidget(buildTestWidget());

    // Should find the title and the specific message
    expect(find.textContaining('Index missing error'), findsOneWidget);
    expect(find.text('Index missing error'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
