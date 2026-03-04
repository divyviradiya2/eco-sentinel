import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swachh_mobile/models/campus_location.dart';
import 'package:swachh_mobile/screens/shared/manual_location_picker.dart';
import 'package:swachh_mobile/services/location_service.dart';
import 'package:provider/provider.dart';
import 'package:swachh_mobile/models/user_model.dart';
import 'package:swachh_mobile/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MockLocationService extends Mock implements LocationService {}

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  late MockLocationService mockLocationService;
  late MockAuthProvider mockAuthProvider;

  final List<CampusLocation> testLocations = [
    const CampusLocation(
      id: 'loc_pub',
      qrCodeId: 'qr_pub',
      name: 'Main Gate',
      description: 'Public entrance',
      coordinates: GeoPoint(0, 0),
      restricted: false,
    ),
    const CampusLocation(
      id: 'loc_sec',
      qrCodeId: 'qr_sec',
      name: 'Labs',
      description: 'Authorized only',
      coordinates: GeoPoint(0, 0),
      restricted: true,
    ),
  ];

  setUp(() {
    mockLocationService = MockLocationService();
    mockAuthProvider = MockAuthProvider();

    when(
      () => mockLocationService.getLocations(),
    ).thenAnswer((_) async => testLocations);
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: mockAuthProvider,
        child: ManualLocationPicker(locationService: mockLocationService),
      ),
    );
  }

  testWidgets('Students should see 1 location (public)', (tester) async {
    when(
      () => mockAuthProvider.appUser,
    ).thenReturn(AppUser(uid: 'u1', email: 'e@t.com', role: UserRole.student));

    await tester.pumpWidget(buildTestWidget());
    await tester.pump(); // Trigger fetch
    await tester.pumpAndSettle(); // Settle animation

    expect(find.text('Main Gate'), findsOneWidget);
    expect(find.text('Labs'), findsNothing);
  });

  testWidgets('Faculty should see 2 locations (all)', (tester) async {
    when(
      () => mockAuthProvider.appUser,
    ).thenReturn(AppUser(uid: 'u1', email: 'e@t.com', role: UserRole.faculty));

    await tester.pumpWidget(buildTestWidget());
    await tester.pump(); // Trigger fetch
    await tester.pumpAndSettle(); // Settle animation

    expect(find.text('Main Gate'), findsOneWidget);
    expect(find.text('Labs'), findsOneWidget);
  });
}
