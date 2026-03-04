import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:swachh_mobile/models/issue_model.dart';
import 'package:swachh_mobile/models/user_model.dart';
import 'package:swachh_mobile/providers/auth_provider.dart';
import 'package:swachh_mobile/providers/issue_provider.dart';
import 'package:swachh_mobile/screens/shared/my_reports_screen.dart';
import 'package:swachh_mobile/services/issue_service.dart';
import 'package:swachh_mobile/widgets/issue_card.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockIssueService extends Mock implements IssueService {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockIssueService mockIssueService;
  late IssueProvider issueProvider;

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockIssueService = MockIssueService();
    issueProvider = IssueProvider(mockIssueService);

    when(() => mockAuthProvider.appUser).thenReturn(
      AppUser(uid: 'user_123', email: 'test@test.com', role: UserRole.student),
    );
  });

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ChangeNotifierProvider<IssueProvider>.value(value: issueProvider),
      ],
      child: const MaterialApp(home: MyReportsScreen()),
    );
  }

  testWidgets('MyReportsScreen displays loading and then data', (
    WidgetTester tester,
  ) async {
    final streamController = StreamController<List<IssueModel>>();
    when(
      () => mockIssueService.getMyIssuesStream('user_123'),
    ).thenAnswer((_) => streamController.stream);

    await tester.pumpWidget(buildTestWidget());

    // initially wait for the post frame callback to dispatch the provider change
    await tester.pump();

    // Initially loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final mockIssue = IssueModel(
      id: 'issue_1',
      locationId: 'loc_1',
      locationName: 'Cafeteria',
      description: 'Water leak',
      imageUrl: '',
      reporterId: 'user_123',
      status: 'Reported',
      createdAt: DateTime.now(),
    );

    // Emit data
    streamController.add([mockIssue]);
    await tester.pumpAndSettle(); // Allow stream to update Provider

    expect(find.text('Water leak'), findsOneWidget);
    expect(find.byType(IssueCard), findsOneWidget);

    streamController.close();
  });
}
