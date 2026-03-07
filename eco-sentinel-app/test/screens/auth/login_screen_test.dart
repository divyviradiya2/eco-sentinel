import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:swachh_mobile/models/user_model.dart';
import 'package:swachh_mobile/providers/auth_provider.dart';
import 'package:swachh_mobile/screens/auth/login_screen.dart';

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get isLoading => false;

  @override
  bool get isInitializing => false;

  @override
  bool get isAuthenticated => false;

  @override
  String? get errorMessage => null;

  @override
  AppUser? get appUser => null;

  @override
  bool get canRegisterContractor => true;

  @override
  Future<void> checkContractorLimit() async {}

  @override
  Future<bool> login(String email, String password) async => true;

  @override
  Future<bool> register({
    required String email,
    required String password,
    required UserRole role,
    String? enrollmentNo,
    String? facultyId,
    String? workerId,
    String displayName = '',
    String? realName,
    String? invitationCode,
  }) async => true;

  @override
  AuthMode get authMode => AuthMode.login;

  @override
  String? get successMessage => null;

  @override
  void setAuthMode(AuthMode mode) {}

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> updateProfile(String newName) async => true;
}

void main() {
  Widget createWidgetUnderTest(AuthProvider mockAuthProvider) {
    return MaterialApp(
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: mockAuthProvider,
        child: const LoginScreen(),
      ),
    );
  }

  testWidgets('LoginScreen renders email and password fields', (
    WidgetTester tester,
  ) async {
    final mockAuthProvider = FakeAuthProvider();

    await tester.pumpWidget(createWidgetUnderTest(mockAuthProvider));

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Login'), findsWidgets); // Found in Button
    expect(find.text('Email'), findsOneWidget); // Found in decoration label
    expect(find.text('Password'), findsOneWidget); // Found in decoration label
  });

  testWidgets('LoginScreen shows validation errors for empty fields', (
    WidgetTester tester,
  ) async {
    final mockAuthProvider = FakeAuthProvider();

    await tester.pumpWidget(createWidgetUnderTest(mockAuthProvider));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump();

    // Verify validation errors are shown
    expect(find.text('Please enter a valid email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
  });
}
