// ignore_for_file: unused_import
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swachh_mobile/models/campus_location.dart';
import 'package:swachh_mobile/screens/shared/qr_scanner_screen.dart';
import 'package:swachh_mobile/services/location_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:provider/provider.dart';
import 'package:swachh_mobile/models/user_model.dart';
import 'package:swachh_mobile/providers/auth_provider.dart';

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
    );
    when(() => mockAuthProvider.appUser).thenReturn(testUser);
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: mockAuthProvider,
        child: QrScannerScreen(locationService: mockLocationService),
      ),
    );
  }

  testWidgets('renders QrScannerScreen with manual entry button', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());

    expect(find.text('Scan Location QR'), findsOneWidget);
    expect(find.text('Select Location Manually'), findsOneWidget);
  });

  testWidgets('manual select button navigates to manual picker', (
    tester,
  ) async {
    when(() => mockLocationService.getLocations()).thenAnswer((_) async => []);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final manualButtonFinder = find
        .widgetWithText(ElevatedButton, 'Select Location Manually')
        .first;

    // We can't tap it easily due to MobileScanner layer, so invoke onPressed directly
    final manualButton = tester.widget<ElevatedButton>(manualButtonFinder);
    manualButton.onPressed!();

    await tester.pumpAndSettle();

    expect(find.text('Select Location'), findsOneWidget);
  });
}
