// maintenance_notifier.dart
//
// Domain-layer AsyncNotifier for maintenance reminders list.
//
// Design decisions:
//   - Extends FamilyAsyncNotifier<List<MaintenanceReminder>, String> — keyed by
//     userId, mirrors MileageNotifier pattern.
//   - build() fetches all reminders for the current userId on first access.
//   - add/update/deleteReminder call repository then invalidate self to refresh.
//   - Sets AsyncError when the repository throws.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_repository.dart';

/// Manages the reactive list of [MaintenanceReminder] entries for a given userId.
class MaintenanceNotifier
    extends FamilyAsyncNotifier<List<MaintenanceReminder>, String> {
  @override
  Future<List<MaintenanceReminder>> build(String userId) async {
    final repo = ref.watch(maintenanceRepositoryProvider);
    return repo.fetchReminders(userId: userId);
  }

  /// Persist [reminder] via the repository and refresh state.
  Future<void> addReminder(MaintenanceReminder reminder) async {
    final repo = ref.read(maintenanceRepositoryProvider);
    try {
      await repo.addReminder(reminder);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Update [reminder] via the repository and refresh state.
  Future<void> updateReminder(MaintenanceReminder reminder) async {
    final repo = ref.read(maintenanceRepositoryProvider);
    try {
      await repo.updateReminder(reminder);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Delete the reminder with [reminderId] via the repository and refresh state.
  Future<void> deleteReminder(String reminderId) async {
    final repo = ref.read(maintenanceRepositoryProvider);
    try {
      await repo.deleteReminder(reminderId);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
