import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:swachh_mobile/models/campus_location.dart';
import 'package:swachh_mobile/models/user_model.dart';
import 'package:swachh_mobile/providers/auth_provider.dart';
import 'package:swachh_mobile/screens/shared/manual_location_picker.dart';
import 'package:swachh_mobile/services/location_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MockLocationService extends Mock implements LocationService {}

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  late MockLocationService mockLocationService;
  late MockAuthProvider mockAuthProvider;

  setUp(() {
    mockLocationService = MockLocationService();
    mockAuthProvider = MockAuthProvider();

    final testUser = AppUser(
      uid: 'user123',
      email: 'test@example.com',
      role: UserRole.student,
      displayName: 'Test Student',
    );

    when(() => mockAuthProvider.appUser).thenReturn(testUser);
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: mockAuthProvider,
        child: ManualLocationPicker(locationService: mockLocationService),
      ),
    );
  }

  testWidgets('ManualLocationPicker shows loading state and then data', (
    tester,
  ) async {
    final locations = [
      const CampusLocation(
        id: '1',
        qrCodeId: 'QR1',
        name: 'Library',
        description: 'Main Library',
        coordinates: GeoPoint(0, 0),
        restricted: false,
      ),
    ];

    when(() => mockLocationService.getLocations()).thenAnswer((_) async {
      await Future.delayed(const Duration(milliseconds: 100));
      return locations;
    });

    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Main Library'), findsOneWidget);
  });

  testWidgets('ManualLocationPicker filters by search', (tester) async {
    final locations = [
      const CampusLocation(
        id: '1',
        qrCodeId: 'QR1',
        name: 'Library',
        description: 'Main Library',
        coordinates: GeoPoint(0, 0),
        restricted: false,
      ),
      const CampusLocation(
        id: '2',
        qrCodeId: 'QR2',
        name: 'Canteen',
        description: 'Campus Canteen',
        coordinates: GeoPoint(0, 0),
        restricted: false,
      ),
    ];

    when(
      () => mockLocationService.getLocations(),
    ).thenAnswer((_) async => locations);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Canteen'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Cant');
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsNothing);
    expect(find.text('Canteen'), findsOneWidget);
  });

  testWidgets('ManualLocationPicker hides restricted locations for students', (
    tester,
  ) async {
    final locations = [
      const CampusLocation(
        id: '1',
        qrCodeId: 'QR1',
        name: 'Library',
        description: 'Main Library',
        coordinates: GeoPoint(0, 0),
        restricted: false,
      ),
      const CampusLocation(
        id: '2',
        qrCodeId: 'QR2',
        name: 'Faculty Lounge',
        description: 'Secret Room',
        coordinates: GeoPoint(0, 0),
        restricted: true,
      ),
    ];

    when(
      () => mockLocationService.getLocations(),
    ).thenAnswer((_) async => locations);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Faculty Lounge'), findsNothing);
  });
}
