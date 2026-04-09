// main.dart
//
// Entry point for Mi Changan app.
//
// Boot sequence:
//   1. WidgetsFlutterBinding.ensureInitialized()     — required before any async
//   2. Supabase.initialize(url, anonKey)             — connect to Supabase backend
//   3. runApp(ProviderScope(child: App()))           — mount Riverpod + widget tree
//
// Secrets are injected at compile time via --dart-define-from-file=.env.json (AD3).
// No secrets are loaded from files at runtime.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mi_changan/app.dart';
import 'package:mi_changan/core/constants/app_secrets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppSecrets.supabaseUrl,
    anonKey: AppSecrets.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
