// mileage_notifier.dart
//
// Domain-layer AsyncNotifier for mileage logs list.
//
// Design decisions:
//   - Extends AsyncNotifier<List<MileageLog>> — list is the SSOT.
//   - build() fetches all logs for the current userId on first access.
//   - addLog/deleteLog call repository then refresh state to keep in sync.
//   - Sets AsyncError when the repository throws.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/mileage/domain/mileage_repository.dart';

/// Manages the reactive list of [MileageLog] entries for a given userId.
class MileageNotifier extends FamilyAsyncNotifier<List<MileageLog>, String> {
  @override
  Future<List<MileageLog>> build(String userId) async {
    final repo = ref.watch(mileageRepositoryProvider);
    return repo.fetchLogs(userId: userId);
  }

  /// Persist [log] via the repository and refresh state.
  Future<void> addLog(MileageLog log) async {
    final repo = ref.read(mileageRepositoryProvider);
    try {
      await repo.addLog(log);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Delete the log with [logId] via the repository and refresh state.
  Future<void> deleteLog(String logId) async {
    final repo = ref.read(mileageRepositoryProvider);
    try {
      await repo.deleteLog(logId);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
