import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/user_model.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/worker/worker_dashboard.dart';
import 'screens/contractor/contractor_dashboard.dart';
import 'screens/shared/settings_screen.dart';
import 'screens/shared/reporter_dashboard.dart';
import 'providers/issue_provider.dart';
import 'config/app_config.dart';
import 'services/issue_service.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const EcoSentinelApp());
}

class EcoSentinelApp extends StatelessWidget {
  const EcoSentinelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        ChangeNotifierProvider(
          create: (context) =>
              AuthProvider(authService: context.read<AuthService>()),
        ),
        ChangeNotifierProvider(create: (_) => IssueProvider(IssueService())),
      ],
      child: MaterialApp(
        title: 'Eco Sentinel',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.green,
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            // Show splash during initial auth check to prevent flicker
            if (auth.isInitializing) {
              return const _SplashScreen();
            }

            Widget currentView;
            if (auth.isAuthenticated) {
              currentView = _DashboardRouter(
                key: const ValueKey('dashboard'),
                auth: auth,
              );
            } else if (auth.authMode == AuthMode.register) {
              currentView = const RegisterScreen(key: ValueKey('register'));
            } else {
              currentView = const LoginScreen(key: ValueKey('login'));
            }

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: currentView,
            );
          },
        ),
      ),
    );
  }
}

/// A dedicated splash screen shown during app initialization.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco, size: 100, color: Colors.green),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}

/// Routes users to their specific dashboard based on their role.
class _DashboardRouter extends StatelessWidget {
  final AuthProvider auth;
  const _DashboardRouter({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    final role = auth.appUser!.role;
    const appTitle = 'Eco Sentinel';

    switch (role) {
      case UserRole.student:
        return const ReporterDashboard(
          key: ValueKey('student_dash'),
          title: appTitle,
        );
      case UserRole.faculty:
        return const ReporterDashboard(
          key: ValueKey('faculty_dash'),
          title: appTitle,
        );
      case UserRole.worker:
        return const WorkerDashboard(key: ValueKey('worker_dash'));
      case UserRole.contractor:
        return const ContractorDashboardScreen(
          key: ValueKey('contractor_dash'),
        );
      case UserRole.admin:
        return const _BaseDashboard(
          key: ValueKey('admin_dash'),
          title: 'Admin Console',
        );
    }
  }
}

/// Basic placeholder for the role-specific screens to be developed in Epic 1.2+
class _BaseDashboard extends StatelessWidget {
  final String title;
  const _BaseDashboard({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().appUser;
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            padding: const EdgeInsets.only(right: 16),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user,
                color: Colors.green,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Hello, ${user?.displayName}!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Role: ${user?.role.name.toUpperCase()}',
              style: TextStyle(
                color: Colors.grey.shade600,
                letterSpacing: 1.2,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Console Access Granted',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
