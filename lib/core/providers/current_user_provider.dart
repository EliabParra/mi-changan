// current_user_provider.dart
//
// Provides the currently authenticated user's ID from Supabase session.
//
// Design decisions:
//   - Reads the Supabase client directly (not via auth stream) — this is a
//     synchronous read of the cached session, safe to call at any time after
//     session hydration.
//   - Returns null when no session is active (guarded by auth router).
//   - Used by all feature screens that need to scope queries to the user.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides the current user's UID string, or null when unauthenticated.
///
/// All protected screens should only be reachable when a session exists,
/// so null should never be encountered in practice on protected routes.
final currentUserIdProvider = Provider<String?>((ref) {
  try {
    final client = Supabase.instance.client;
    return client.auth.currentUser?.id;
  } on AssertionError {
    // Test-safe fallback: Supabase not initialized yet.
    return null;
  } on StateError {
    // Defensive fallback for initialization access errors.
    return null;
  }
});
