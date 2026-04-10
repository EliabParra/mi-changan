// auth_providers.dart
//
// Riverpod providers for the auth data layer (AD-H2-4).
//
// Provider graph:
//   supabaseClientProvider  (core/providers/supabase_provider.dart)
//         │
//         ▼
//   authClientProvider  (SupabaseAuthAdapter wrapping GoTrueClient)
//         │
//         ▼
//   authRepositoryProvider  (AuthRepository wrapping AuthClient)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/core/providers/supabase_provider.dart';
import 'package:mi_changan/features/auth/data/auth_repository.dart';

/// Provides the [AuthClient] adapter backed by the live Supabase auth client.
///
/// Override this provider in tests to inject a fake auth client without
/// initialising Supabase.
final authClientProvider = Provider<AuthClient>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return SupabaseAuthAdapter(supabase.auth);
});

/// Provides the [AuthRepository] — the SSOT for auth operations.
///
/// Depends on [authClientProvider] so tests can override only the client.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(authClientProvider));
});
