import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_event.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_repository.dart';
import 'package:mi_changan/features/maintenance/data/offline_first_maintenance_repository.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_repository.dart';

void main() {
  group('OfflineFirstMaintenanceRepository', () {
    test('addReminder enqueues outbox and stays visible if remote fails', () async {
      final remote = _FakeMaintenanceRepository();
      final outbox = _FakeSyncOutboxRepository();
      final repo = OfflineFirstMaintenanceRepository(
        remote: remote,
        outbox: outbox,
        now: () => DateTime.utc(2026, 4, 10, 17, 10),
      );
      remote.addError = Exception('offline');

      final reminder = _reminder(id: 'rem-1', label: 'Aceite');
      await repo.addReminder(reminder);
      final projected = await repo.fetchReminders(userId: 'u1');

      expect(projected, hasLength(1));
      expect(projected.first.id, 'rem-1');
      expect(outbox.enqueued, hasLength(1));
      expect(outbox.enqueued.first.entity, 'maintenance_reminders');
      expect(outbox.enqueued.first.operation, SyncOutboxOperation.upsert);
      expect(outbox.enqueued.first.payload['label'], 'Aceite');
    });

    test('updateReminder updates projected state and enqueues upsert', () async {
      final remote = _FakeMaintenanceRepository([
        _reminder(id: 'rem-1', intervalKm: 5000),
      ]);
      final outbox = _FakeSyncOutboxRepository();
      final repo = OfflineFirstMaintenanceRepository(
        remote: remote,
        outbox: outbox,
        now: () => DateTime.utc(2026, 4, 10, 17, 12),
      );
      remote.updateError = Exception('offline');

      await repo.fetchReminders(userId: 'u1');
      await repo.updateReminder(_reminder(id: 'rem-1', intervalKm: 10000));
      final projected = await repo.fetchReminders(userId: 'u1');

      expect(projected, hasLength(1));
      expect(projected.first.intervalKm, 10000.0);
      expect(outbox.enqueued, hasLength(1));
      expect(outbox.enqueued.first.operation, SyncOutboxOperation.upsert);
      expect(outbox.enqueued.first.payload['interval_km'], 10000.0);
    });
  });
}

class _FakeMaintenanceRepository implements MaintenanceRepository {
  _FakeMaintenanceRepository([List<MaintenanceReminder>? reminders])
      : _reminders = [...?reminders];

  final List<MaintenanceReminder> _reminders;
  Exception? addError;
  Exception? updateError;
  Exception? deleteError;

  @override
  Future<void> addReminder(MaintenanceReminder reminder) async {
    if (addError != null) throw addError!;
    _reminders.add(reminder);
  }

  @override
  Future<void> deleteReminder(String reminderId) async {
    if (deleteError != null) throw deleteError!;
    _reminders.removeWhere((reminder) => reminder.id == reminderId);
  }

  @override
  Future<List<MaintenanceReminder>> fetchReminders({required String userId}) async {
    return _reminders
        .where((reminder) => reminder.userId == userId)
        .toList(growable: false);
  }

  @override
  Future<void> updateReminder(MaintenanceReminder reminder) async {
    if (updateError != null) throw updateError!;
    final index = _reminders.indexWhere((value) => value.id == reminder.id);
    if (index >= 0) {
      _reminders[index] = reminder;
    }
  }
}

class _FakeSyncOutboxRepository implements SyncOutboxRepository {
  final List<SyncOutboxEvent> enqueued = [];

  @override
  Future<void> enqueue(SyncOutboxEvent event) async {
    enqueued.add(event);
  }

  @override
  Future<void> markConflict(String eventId, SyncConflictRecord conflict) async {}

  @override
  Future<void> markFailed(
    String eventId, {
    required String reason,
    DateTime? nextRetryAt,
  }) async {}

  @override
  Future<void> markSynced(String eventId, {required DateTime syncedAt}) async {}

  @override
  Future<List<SyncOutboxEvent>> pullReady({required int limit}) async => const [];
}

MaintenanceReminder _reminder({
  required String id,
  String label = 'Filtro',
  double intervalKm = 5000,
}) {
  return MaintenanceReminder(
    id: id,
    userId: 'u1',
    label: label,
    intervalKm: intervalKm,
    lastServiceKm: 12000,
    lastServiceDate: DateTime.utc(2026, 1, 1),
  );
}
