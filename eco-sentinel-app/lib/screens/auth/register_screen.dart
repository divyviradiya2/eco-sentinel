import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_logo.dart';

/// Registration screen that collects email, password, role, and the
/// corresponding ID (enrollment or worker) before creating the account.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _realNameCtrl = TextEditingController();

  UserRole _selectedRole = UserRole.student;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _realNameCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool get _needsEnrollment => _selectedRole == UserRole.student;

  bool get _needsFacultyId => _selectedRole == UserRole.faculty;

  bool get _needsWorkerId =>
      _selectedRole == UserRole.worker || _selectedRole == UserRole.contractor;

  String get _idLabel {
    if (_needsEnrollment) return 'Enrollment No (e.g. ET25BTCO001)';
    if (_needsFacultyId) return 'Faculty ID (e.g. FID-1234)';
    if (_needsWorkerId) {
      return _selectedRole == UserRole.worker
          ? 'Worker ID (e.g. W-101)'
          : 'Contractor ID (e.g. C-201)';
    }
    return 'ID';
  }

  String? _validateId(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'This field is required';

    if (_needsEnrollment && !AuthService.isValidEnrollment(trimmed)) {
      return 'Invalid format. Expected: ET25BTCO001';
    }
    if (_needsFacultyId && !AuthService.isValidFacultyId(trimmed)) {
      return 'Invalid format. Expected: FID-1234';
    }
    if (_needsWorkerId && !AuthService.isValidWorkerId(trimmed)) {
      return 'Invalid format. Expected: W-101 or C-201';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      role: _selectedRole,
      enrollmentNo: _needsEnrollment ? _idCtrl.text.trim() : null,
      facultyId: _needsFacultyId ? _idCtrl.text.trim() : null,
      workerId: _needsWorkerId ? _idCtrl.text.trim() : null,
      displayName: _nameCtrl.text.trim(),
      realName: _selectedRole == UserRole.faculty
          ? _realNameCtrl.text.trim()
          : null,
    );

    if (!mounted) return;

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registration successful!')));
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Registration failed'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (auth.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Text(
                      auth.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const Center(child: AppLogo(size: 80)),
                const SizedBox(height: 24),

                // --- Display Name ---
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: _selectedRole == UserRole.faculty
                        ? 'Alias (Public)'
                        : 'Display Name (optional)',
                    prefixIcon: const Icon(Icons.person_outline),
                    hintText: _selectedRole == UserRole.faculty
                        ? 'How you appear on leaderboard'
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // --- Real Name (Faculty Only) ---
                if (_selectedRole == UserRole.faculty) ...[
                  TextFormField(
                    controller: _realNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Faculty Name (Official)',
                      prefixIcon: Icon(Icons.assignment_ind_outlined),
                      hintText: 'Your official name for leaderboard',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Official name is required for Faculty'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // --- Email ---
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 16),

                // --- Password ---
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 16),

                // --- Role Selector ---
                DropdownButtonFormField<UserRole>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Select Role',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: UserRole.student,
                      child: Text('Student'),
                    ),
                    DropdownMenuItem(
                      value: UserRole.faculty,
                      child: Text('Faculty'),
                    ),
                    DropdownMenuItem(
                      value: UserRole.worker,
                      child: Text('Worker'),
                    ),
                    DropdownMenuItem(
                      value: UserRole.contractor,
                      child: Text('Contractor'),
                    ),
                  ],
                  validator: (role) {
                    if (role == UserRole.contractor &&
                        !auth.canRegisterContractor) {
                      return 'Maximum number of contractors are registered. You cannot register as a contractor.';
                    }
                    return null;
                  },
                  onChanged: (role) {
                    if (role != null) {
                      setState(() {
                        _selectedRole = role;
                        _idCtrl.clear();
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // --- Role-specific ID ---
                if (_needsEnrollment || _needsFacultyId || _needsWorkerId)
                  TextFormField(
                    controller: _idCtrl,
                    decoration: InputDecoration(
                      labelText: _idLabel,
                      prefixIcon: const Icon(Icons.assignment_ind_outlined),
                    ),
                    validator: _validateId,
                  ),
                const SizedBox(height: 32),

                // --- Submit ---
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _submit,
                    child: auth.isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Register'),
                  ),
                ),
                const SizedBox(height: 16),

                // --- Login Link ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?'),
                    TextButton(
                      onPressed: auth.isLoading
                          ? null
                          : () => auth.setAuthMode(AuthMode.login),
                      child: const Text('Login'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
