// main.dart
//
// Entry point for Mi Changan app.
//
// Boot sequence:
//   1. WidgetsFlutterBinding.ensureInitialized()     — required before any async
//   2. Supabase.initialize(url, anonKey)             — connect to Supabase backend
//   3. runApp(ProviderScope(overrides: [...], child: App()))
//      - productionOverrides binds abstract repos to Supabase implementations
//
// Secrets are injected at compile time via --dart-define-from-file=.env.json (AD3).
// No secrets are loaded from files at runtime.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mi_changan/app.dart';
import 'package:mi_changan/core/constants/app_secrets.dart';
import 'package:mi_changan/core/providers/production_overrides.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppSecrets.supabaseUrl,
    anonKey: AppSecrets.supabaseAnonKey,
  );

  runApp(
    ProviderScope(
      overrides: productionOverrides,
      child: const App(),
    ),
  );
}
