import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized, production-grade configuration that reads all secrets from
/// the `.env` file via [flutter_dotenv].
///
/// Call [AppConfig.load] once in `main()` before `runApp()`.
/// Then access any value through the static getters.
///
/// This keeps every secret out of source control and provides a single
/// point-of-truth that is easy to audit.
abstract final class AppConfig {
  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  /// Loads the `.env` asset. Must be awaited before accessing any getter.
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  // -----------------------------------------------------------------------
  // ImgBB
  // -----------------------------------------------------------------------

  /// ImgBB image-hosting API key.
  static String get imgBbApiKey =>
      dotenv.env['IMGBB_API_KEY'] ?? _missing('IMGBB_API_KEY');

  // -----------------------------------------------------------------------
  // Firebase
  // -----------------------------------------------------------------------

  /// Firebase Web / Android API key.
  static String get firebaseApiKey =>
      dotenv.env['FIREBASE_API_KEY'] ?? _missing('FIREBASE_API_KEY');

  /// Firebase App ID for the current platform.
  static String get firebaseAppId =>
      dotenv.env['FIREBASE_APP_ID'] ?? _missing('FIREBASE_APP_ID');

  /// Firebase Cloud Messaging sender ID.
  static String get firebaseMessagingSenderId =>
      dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ??
      _missing('FIREBASE_MESSAGING_SENDER_ID');

  /// Firebase project ID (e.g. `swachh-campus-360`).
  static String get firebaseProjectId =>
      dotenv.env['FIREBASE_PROJECT_ID'] ?? _missing('FIREBASE_PROJECT_ID');

  /// Firebase Storage bucket URL.
  static String get firebaseStorageBucket =>
      dotenv.env['FIREBASE_STORAGE_BUCKET'] ??
      _missing('FIREBASE_STORAGE_BUCKET');

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Throws a clear error when a required env variable is not set,
  /// making misconfiguration immediately visible during development.
  static Never _missing(String key) {
    throw StateError(
      'Environment variable "$key" is not set. '
      'Please add it to your .env file. See .env.example for reference.',
    );
  }
}
