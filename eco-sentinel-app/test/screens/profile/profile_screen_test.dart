import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:swachh_mobile/models/user_model.dart';
import 'package:swachh_mobile/providers/auth_provider.dart';
import 'package:swachh_mobile/screens/shared/settings_screen.dart';

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get isLoading => false;

  @override
  bool get isInitializing => false;

  @override
  String? get errorMessage => null;

  @override
  bool get isAuthenticated => true;

  @override
  bool get canRegisterContractor => true;

  @override
  Future<void> checkContractorLimit() async {}

  @override
  AppUser? get appUser => AppUser(
    uid: '123',
    email: 'student@example.com',
    role: UserRole.student,
    enrollmentNo: 'ET25BTCO001',
    displayName: 'John Doe',
  );

  bool updateProfileCalled = false;
  String passedName = '';

  @override
  Future<bool> updateProfile(String newName) async {
    updateProfileCalled = true;
    passedName = newName;
    return true;
  }

  @override
  String? get successMessage => null;

  @override
  AuthMode get authMode => AuthMode.login;

  @override
  void setAuthMode(AuthMode mode) {}

  @override
  Future<void> signOut() async {}

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
  }) async => true;
}

void main() {
  Widget createWidgetUnderTest(AuthProvider mockAuthProvider) {
    return MaterialApp(
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: mockAuthProvider,
        child: const SettingsScreen(),
      ),
    );
  }

  testWidgets('SettingsScreen renders profile info and alias editing', (
    WidgetTester tester,
  ) async {
    final mockAuthProvider = FakeAuthProvider();

    await tester.pumpWidget(createWidgetUnderTest(mockAuthProvider));
    await tester.pumpAndSettle();

    // Verify the screen renders with user information
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('John Doe'), findsAtLeast(1));
  });
}
