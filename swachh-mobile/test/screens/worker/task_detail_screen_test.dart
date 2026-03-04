import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swachh_mobile/models/issue_model.dart';
import 'package:swachh_mobile/models/campus_location.dart';
import 'package:swachh_mobile/models/user_model.dart';
import 'package:swachh_mobile/screens/shared/issue_detail_screen.dart';
import 'package:swachh_mobile/services/location_service.dart';
import 'package:swachh_mobile/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MockLocationService extends Mock implements LocationService {}

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockLocationService mockLocationService;
  late MockAuthService mockAuthService;
  late IssueModel testTask;
  late CampusLocation testLocation;

  setUp(() {
    mockLocationService = MockLocationService();
    mockAuthService = MockAuthService();
    testTask = IssueModel(
      id: 'task123',
      locationId: 'loc123',
      locationName: 'Main Block Washroom',
      description: 'The floor is wet and slippery.',
      imageUrl: 'https://test.com/image.jpg',
      reporterId: 'user123',
      status: 'Assigned',
      createdAt: DateTime(2026, 3, 1, 10, 30),
    );

    testLocation = CampusLocation(
      id: 'loc123',
      name: 'Main Block Washroom',
      coordinates: const GeoPoint(12.9716, 77.5946),
      description: 'Second floor, near elevator',
      qrCodeId: 'qr123',
    );

    when(
      () => mockLocationService.getLocationById(any()),
    ).thenAnswer((_) async => testLocation);

    when(
      () => mockAuthService.getUserById(any()),
    ).thenAnswer((_) async => null);
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: IssueDetailScreen(
        issue: testTask,
        userRole: UserRole.worker,
        locationService: mockLocationService,
        authService: mockAuthService,
      ),
    );
  }

  testWidgets('IssueDetailScreen displays task details correctly', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Main Block Washroom'), findsAtLeast(1));
    expect(find.text('The floor is wet and slippery.'), findsOneWidget);
  });

  testWidgets('IssueDetailScreen shows location information after loading', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Second floor, near elevator'), findsOneWidget);
    expect(find.text('GET DIRECTIONS'), findsOneWidget);
  });

  testWidgets('IssueDetailScreen shows completion button for Assigned tasks', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('COMPLETE TASK'), findsOneWidget);
  });

  testWidgets('IssueDetailScreen handles Closed status correctly', (
    tester,
  ) async {
    final closedTask = IssueModel(
      id: 'task123',
      locationId: 'loc123',
      locationName: 'Main Block Washroom',
      description: 'The floor is wet and slippery.',
      imageUrl: '',
      reporterId: 'user123',
      status: 'Closed',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: IssueDetailScreen(
          issue: closedTask,
          userRole: UserRole.worker,
          locationService: mockLocationService,
          authService: mockAuthService,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Closed issues should show a disabled COMPLETE TASK button
    expect(find.text('COMPLETE TASK'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'COMPLETE TASK'),
    );
    expect(button.onPressed, isNull); // Button is disabled
  });
}
