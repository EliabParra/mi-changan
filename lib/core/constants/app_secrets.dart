// app_secrets.dart
//
// Secrets are injected at compile time via --dart-define-from-file=.env.json
// They are NEVER loaded from a file at runtime — no asset bundling.
//
// Local dev:
//   flutter run --dart-define-from-file=.env.json
//
// CI (PR): no secrets needed — analyze + test only
// CI (Release): secrets written ephemerally from GitHub Secrets in workflow
//
// See: .env.json.example for the expected structure

// ignore_for_file: avoid_classes_with_only_static_members

class AppSecrets {
  const AppSecrets._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
}
