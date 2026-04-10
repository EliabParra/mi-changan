// maintenance_providers.dart
//
// Riverpod providers for the maintenance data layer.
//
// Provider graph:
//   supabaseClientProvider
//         │
//         ▼
//   supabaseMaintenanceRepositoryProvider  (SupabaseMaintenanceRepository)
//         │
//         ▼
//   maintenanceRepositoryProvider          (overridden here to bind Supabase impl)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/core/providers/supabase_provider.dart';
import 'package:mi_changan/core/sync/data/sync_providers.dart';
import 'package:mi_changan/features/maintenance/data/offline_first_maintenance_repository.dart';
import 'package:mi_changan/features/maintenance/data/supabase_maintenance_repository.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_repository.dart';

/// Provides the Supabase-backed [MaintenanceRepository].
///
/// Override in tests with a FakeMaintenanceRepository.
final supabaseMaintenanceRepositoryProvider =
    Provider<MaintenanceRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseMaintenanceRepository(client);
});

final offlineFirstMaintenanceRepositoryProvider =
    Provider<MaintenanceRepository>((ref) {
  final remote = ref.watch(supabaseMaintenanceRepositoryProvider);
  final outbox = ref.watch(syncOutboxRepositoryProvider);
  return OfflineFirstMaintenanceRepository(remote: remote, outbox: outbox);
});
