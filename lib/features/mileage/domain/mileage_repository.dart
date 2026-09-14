// mileage_repository.dart
//
// Abstract interface for mileage data operations.
//
// Design decisions:
//   - Interface-first pattern (same as auth) — production uses Supabase,
//     tests inject FakeMileageRepository without touching the network.
//   - All methods are async — Supabase calls are always awaited.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log.dart';

/// Abstract interface for mileage data operations.
abstract class MileageRepository {
  /// Fetch all mileage logs for the given [userId].
  Future<List<MileageLog>> fetchLogs({required String userId});

  /// Persist a new [log] entry.
  Future<void> addLog(MileageLog log);

  /// Remove the log with [logId].
  Future<void> deleteLog(String logId);
}

/// Riverpod provider for [MileageRepository].
///
/// Overridden in tests with a [FakeMileageRepository].
/// Production value is provided by [supabaseMileageRepositoryProvider].
final mileageRepositoryProvider = Provider<MileageRepository>((ref) {
  throw UnimplementedError(
    'mileageRepositoryProvider must be overridden with a concrete implementation.',
  );
});
