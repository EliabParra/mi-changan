// service_notifier.dart
//
// Domain-layer AsyncNotifier for service records list.
//
// Design decisions:
//   - Extends FamilyAsyncNotifier<List<ServiceRecord>, String> — keyed by
//     userId, mirrors MileageNotifier pattern.
//   - addRecord() also resets the linked MaintenanceReminder's baseline
//     by calling maintenanceRepositoryProvider.updateReminder() with
//     the new lastServiceKm set to record.odometerKm.
//   - If the linked reminder is not found (edge case), the service record
//     is still saved — reminder reset is best-effort.
//   - Sets AsyncError when serviceRepositoryProvider throws.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/maintenance/domain/maintenance_repository.dart';
import 'package:mi_changan/features/services/domain/service_record.dart';
import 'package:mi_changan/features/services/domain/service_repository.dart';

/// Manages the reactive list of [ServiceRecord] entries for a given userId.
class ServiceNotifier
    extends FamilyAsyncNotifier<List<ServiceRecord>, String> {
  @override
  Future<List<ServiceRecord>> build(String userId) async {
    final repo = ref.watch(serviceRepositoryProvider);
    return repo.fetchRecords(userId: userId);
  }

  /// Persist [record] and reset the linked reminder's baseline.
  Future<void> addRecord(ServiceRecord record) async {
    final svcRepo = ref.read(serviceRepositoryProvider);
    try {
      await svcRepo.addRecord(record);
      await _resetReminderBaseline(record);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Delete the record with [recordId] from the repository and refresh state.
  Future<void> deleteRecord(String recordId) async {
    final repo = ref.read(serviceRepositoryProvider);
    try {
      await repo.deleteRecord(recordId);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  // ── Private: reminder baseline reset ────────────────────────────────────

  /// Finds the linked reminder and updates its lastServiceKm to [record.odometerKm].
  ///
  /// Best-effort: if the reminder is not found, this is a no-op.
  Future<void> _resetReminderBaseline(ServiceRecord record) async {
    final maintRepo = ref.read(maintenanceRepositoryProvider);
    final reminders =
        await maintRepo.fetchReminders(userId: record.userId);
    final reminder = reminders
        .where((r) => r.id == record.reminderId)
        .firstOrNull;

    if (reminder == null) return;

    final updated = reminder.updateBaseline(
      newLastServiceKm: record.odometerKm,
      newLastServiceDate: record.serviceDate,
    );
    await maintRepo.updateReminder(updated);
  }
}
