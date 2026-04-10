// service_providers.dart
//
// Riverpod providers for the services data layer.
//
// Provider graph:
//   supabaseClientProvider
//         │
//         ▼
//   supabaseServiceRepositoryProvider  (SupabaseServiceRepository)
//         │
//         ▼
//   serviceRepositoryProvider          (overridden here to bind Supabase impl)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/core/providers/supabase_provider.dart';
import 'package:mi_changan/features/services/data/supabase_service_repository.dart';
import 'package:mi_changan/features/services/domain/service_repository.dart';

/// Provides the Supabase-backed [ServiceRepository].
///
/// Override in tests with a FakeServiceRepository.
final supabaseServiceRepositoryProvider =
    Provider<ServiceRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseServiceRepository(client);
});
