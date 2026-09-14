// service_repository.dart
//
// Abstract interface for service record data operations.
//
// Design decisions:
//   - Interface-first pattern (mirrors MileageRepository).
//   - No update needed — service records are immutable once logged;
//     delete + re-add covers corrections.
//   - All methods are async — Supabase calls are always awaited.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_changan/features/services/domain/service_record.dart';

/// Abstract interface for service record data operations.
abstract class ServiceRepository {
  /// Fetch all service records for the given [userId].
  Future<List<ServiceRecord>> fetchRecords({required String userId});

  /// Persist a new [record].
  Future<void> addRecord(ServiceRecord record);

  /// Remove the record with [recordId].
  Future<void> deleteRecord(String recordId);
}

/// Riverpod provider for [ServiceRepository].
///
/// Overridden in tests with a [FakeServiceRepository].
/// Production value is provided by [supabaseServiceRepositoryProvider].
final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  throw UnimplementedError(
    'serviceRepositoryProvider must be overridden with a concrete implementation.',
  );
});
