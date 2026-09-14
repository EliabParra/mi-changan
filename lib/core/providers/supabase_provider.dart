// supabase_provider.dart
//
// Riverpod provider exposing the Supabase client singleton (AD5 + AD3).
// Supabase.initialize() is called in main.dart BEFORE runApp().
// This provider simply exposes the already-initialized client.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides the initialized [SupabaseClient] instance.
///
/// Usage:
/// ```dart
/// final client = ref.watch(supabaseClientProvider);
/// ```
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
