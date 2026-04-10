// mileage_providers.dart
//
// Riverpod providers for the mileage data layer.
//
// Provider graph:
//   supabaseClientProvider
//         │
//         ▼
//   supabaseMileageRepositoryProvider  (SupabaseMileageRepository)
//         │
//         ▼
//   mileageRepositoryProvider          (overridden here to bind Supabase impl)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/core/providers/supabase_provider.dart';
import 'package:mi_changan/features/mileage/data/supabase_mileage_repository.dart';
import 'package:mi_changan/features/mileage/domain/mileage_repository.dart';

/// Provides the Supabase-backed [MileageRepository].
///
/// Override in tests with a FakeMileageRepository.
final supabaseMileageRepositoryProvider = Provider<MileageRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseMileageRepository(client);
});
