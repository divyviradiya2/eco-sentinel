import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swachh_mobile/models/campus_location.dart';
import 'package:swachh_mobile/screens/shared/qr_scanner_screen.dart';
import 'package:swachh_mobile/services/location_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide GeoPoint;
import 'package:provider/provider.dart';
import 'package:swachh_mobile/models/user_model.dart';
import 'package:swachh_mobile/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MockLocationService extends Mock implements LocationService {}

class MockAuthProvider extends Mock implements AuthProvider {}

class MockBarcodeCapture extends Mock implements BarcodeCapture {}

class MockBarcode extends Mock implements Barcode {}

void main() {
  late MockLocationService mockLocationService;
  late MockAuthProvider mockAuthProvider;

  setUp(() {
    mockLocationService = MockLocationService();
    mockAuthProvider = MockAuthProvider();

    registerFallbackValue(const Offset(0, 0));
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: mockAuthProvider,
        child: QrScannerScreen(locationService: mockLocationService),
      ),
    );
  }

  testWidgets('Blocks Students from scanning restricted locations', (
    tester,
  ) async {
    // 1. Setup Student User
    final testUser = AppUser(
      uid: 'student123',
      email: 'student@test.com',
      role: UserRole.student,
    );
    when(() => mockAuthProvider.appUser).thenReturn(testUser);

    // 2. Setup Restricted Location
    const restrictedLocation = CampusLocation(
      id: 'loc_secret',
      qrCodeId: 'qr_secret',
      name: 'Faculty Lounge',
      description: 'Restricted area',
      coordinates: GeoPoint(12.34, 56.78),
      restricted: true,
    );

    when(
      () => mockLocationService.getLocationByQrCodeId('qr_secret'),
    ).thenAnswer((_) async => restrictedLocation);

    // 3. Build Widget
    await tester.pumpWidget(buildTestWidget());

    // 4. Manually trigger internal handleBarcode logic
    // Since we can't easily simulate a scan with MobileScanner in tests,
    // we find the state and call the private handler if possible,
    // OR we rely on the fact that we're about to implement this.
    // For now, let's try to find the MobileScanner and see if we can get the onDetect.

    final scannerFinder = find.byType(MobileScanner);
    expect(scannerFinder, findsOneWidget);

    final MobileScanner scanner = tester.widget(scannerFinder);

    final mockBarcode = MockBarcode();
    when(() => mockBarcode.rawValue).thenReturn('qr_secret');

    final mockCapture = MockBarcodeCapture();
    when(() => mockCapture.barcodes).thenReturn([mockBarcode]);

    // Invoke the handler
    scanner.onDetect?.call(mockCapture);

    await tester.pump(); // Start execution
    await tester.pump(
      const Duration(seconds: 1),
    ); // Wait for async logic and snackbar animation

    // 5. Verify navigation DID NOT occur and SnackBar is shown
    // If it naved, we'd see 'Report Issue' or similar from the next screen.
    // We expect a SnackBar with specific text.
    expect(
      find.text('This location is restricted to Faculty reports only.'),
      findsOneWidget,
    );
    expect(
      find.text('Faculty Lounge'),
      findsNothing,
    ); // Should not have popped to report screen
  });
}
