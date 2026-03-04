import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Provides reactive authentication state to the widget tree via [Provider].
///
/// Consumers can listen to [isLoading], [errorMessage], and [appUser] to
/// drive UI decisions like showing spinners, error banners, and role-based
/// dashboard routing.
enum AuthMode { login, register }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  bool _isLoading = false;
  bool _isInitializing = true;
  bool _isRegistering = false;
  bool _canRegisterContractor = true;
  String? _errorMessage;
  AppUser? _appUser;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<AppUser?>? _userDocSubscription;
  StreamSubscription<bool>? _availabilitySubscription;

  AuthMode _authMode = AuthMode.login;
  String? _successMessage;

  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService() {
    _listenToAuthChanges();
    _listenToAvailability();
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  AppUser? get appUser => _appUser;
  bool get isAuthenticated => _appUser != null;
  bool get canRegisterContractor => _canRegisterContractor;
  AuthMode get authMode => _authMode;

  void setAuthMode(AuthMode mode) {
    _authMode = mode;
    _clearError();
    _successMessage = null;
    if (mode == AuthMode.register) {
      checkContractorLimit();
    }
    notifyListeners();
  }

  /// Refreshes the local flag for whether more contractors can register.
  Future<void> checkContractorLimit() async {
    _canRegisterContractor = await _authService
        .isContractorRegistrationAllowed();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Auth state listener
  // ---------------------------------------------------------------------------

  void _listenToAuthChanges() {
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _userDocSubscription?.cancel();

      // Prevent dashboard flicker during registration auto-logout flow
      if (_isRegistering && user != null) return;

      if (user == null) {
        _appUser = null;
        if (_isInitializing) {
          _isInitializing = false;
        }
        notifyListeners();
        return;
      }

      // User exists, wait for Firestore data before revealing Dashboard
      _userDocSubscription = _authService
          .userDocStream(user.uid)
          .listen(
            (userData) {
              _appUser = userData;
              if (_isInitializing) {
                _isInitializing = false;
              }
              notifyListeners();
            },
            onError: (e) {
              debugPrint('Firestore Init Error: $e');
              if (_isInitializing) {
                _isInitializing = false;
              }
              notifyListeners();
            },
          );
    });
  }

  void _listenToAvailability() {
    _availabilitySubscription?.cancel();
    _availabilitySubscription = _authService
        .contractorAvailabilityStream()
        .listen((allowed) {
          _canRegisterContractor = allowed;
          notifyListeners();
        });
  }

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Triggers user registration and updates internal state accordingly.
  Future<bool> register({
    required String email,
    required String password,
    required UserRole role,
    String? enrollmentNo,
    String? facultyId,
    String? workerId,
    String displayName = '',
  }) async {
    _setLoading(true);
    _clearError();
    _isRegistering = true; // Block auth listener from revealing dashboard

    try {
      await _authService.registerUser(
        email: email,
        password: password,
        role: role,
        enrollmentNo: enrollmentNo,
        facultyId: facultyId,
        workerId: workerId,
        displayName: displayName,
      );

      // Auto sign out after registration to force manual login (Production best practice)
      await _authService.signOut();

      _successMessage = 'Account created successfully! Please sign in.';
      _authMode = AuthMode.login;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException [${e.code}]: ${e.message}');
      _errorMessage = '${_mapAuthError(e.code)} (${e.code})';
      return false;
    } catch (e, stackTrace) {
      debugPrint('Generic Exception: $e\\n$stackTrace');
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isRegistering = false;
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Login
  // ---------------------------------------------------------------------------

  /// Attempts to sign in an existing user.
  /// Returns `true` if successful, or sets `errorMessage` and returns `false`.
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.loginWithEmail(email, password);
      // userDocStream will pick up the sign-in implicitly in _listenToAuthChanges.
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    await _authService.signOut();
    _appUser = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  /// Updates the user's display name.
  Future<bool> updateProfile(String newName) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      _errorMessage = 'Display name cannot be empty.';
      notifyListeners();
      return false;
    }

    if (trimmedName.length > 25) {
      _errorMessage = 'Display name cannot exceed 25 characters.';
      notifyListeners();
      return false;
    }

    if (trimmedName.length < 3) {
      _errorMessage = 'Display name must be at least 3 characters.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      await _authService.updateDisplayName(trimmedName);
      // The userDocStream will automatically pick up the change and notifyListeners.
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update profile. Please try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  /// Maps Firebase error codes to user-friendly messages.
  String _mapAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided for that user.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled in the Firebase Console.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        debugPrint('Unhandled Firebase Auth code: $code');
        return 'Authentication failed ($code). Please try again.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userDocSubscription?.cancel();
    _availabilitySubscription?.cancel();
    super.dispose();
  }
}
