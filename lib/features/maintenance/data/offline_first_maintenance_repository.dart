import 'package:mi_changan/core/sync/data/offline_outbox_event_factory.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_repository.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_repository.dart';

class OfflineFirstMaintenanceRepository implements MaintenanceRepository {
  OfflineFirstMaintenanceRepository({
    required MaintenanceRepository remote,
    required SyncOutboxRepository outbox,
    DateTime Function()? now,
  })  : _remote = remote,
        _outbox = outbox,
        _outboxFactory = OfflineOutboxEventFactory(now: now),
        _now = now ?? _utcNow;

  final MaintenanceRepository _remote;
  final SyncOutboxRepository _outbox;
  final OfflineOutboxEventFactory _outboxFactory;
  final DateTime Function() _now;

  final Map<String, List<MaintenanceReminder>> _cacheByUser = {};

  @override
  Future<void> addReminder(MaintenanceReminder reminder) async {
    _upsertProjected(reminder);
    final event = _outboxFactory.buildUpsert(
      entity: 'maintenance_reminders',
      entityId: reminder.id,
      payload: _toPayload(reminder),
    );
    await _outbox.enqueue(event);

    try {
      await _remote.addReminder(reminder);
    } catch (_) {
      // Offline-first: local projection/outbox are SSOT for UI continuity.
    }
  }

  @override
  Future<void> updateReminder(MaintenanceReminder reminder) async {
    _upsertProjected(reminder);
    final event = _outboxFactory.buildUpsert(
      entity: 'maintenance_reminders',
      entityId: reminder.id,
      payload: _toPayload(reminder),
    );
    await _outbox.enqueue(event);

    try {
      await _remote.updateReminder(reminder);
    } catch (_) {
      // Offline-first: local projection/outbox are SSOT for UI continuity.
    }
  }

  @override
  Future<void> deleteReminder(String reminderId) async {
    _deleteProjected(reminderId);
    final event = _outboxFactory.buildDelete(
      entity: 'maintenance_reminders',
      entityId: reminderId,
      payload: {'id': reminderId},
    );
    await _outbox.enqueue(event);

    try {
      await _remote.deleteReminder(reminderId);
    } catch (_) {
      // Offline-first: local projection/outbox are SSOT for UI continuity.
    }
  }

  @override
  Future<List<MaintenanceReminder>> fetchReminders({required String userId}) async {
    final cached = _cacheByUser[userId];
    if (cached != null) {
      return List.unmodifiable(cached);
    }

    final remoteReminders = await _remote.fetchReminders(userId: userId);
    _cacheByUser[userId] = [...remoteReminders];
    return List.unmodifiable(_cacheByUser[userId]!);
  }

  void _upsertProjected(MaintenanceReminder reminder) {
    final current = [...?_cacheByUser[reminder.userId]];
    final index = current.indexWhere((value) => value.id == reminder.id);
    if (index >= 0) {
      current[index] = reminder;
    } else {
      current.add(reminder);
    }
    _cacheByUser[reminder.userId] = current;
  }

  void _deleteProjected(String reminderId) {
    for (final userId in _cacheByUser.keys.toList(growable: false)) {
      final current = [...?_cacheByUser[userId]];
      final initial = current.length;
      current.removeWhere((reminder) => reminder.id == reminderId);
      if (current.length != initial) {
        _cacheByUser[userId] = current;
        break;
      }
    }
  }

  Map<String, dynamic> _toPayload(MaintenanceReminder reminder) {
    return {
      'id': reminder.id,
      'user_id': reminder.userId,
      'label': reminder.label,
      'interval_km': reminder.intervalKm,
      'last_service_km': reminder.lastServiceKm,
      'last_service_date': reminder.lastServiceDate.toUtc().toIso8601String(),
      if (reminder.notes != null) 'notes': reminder.notes,
      'updated_at': _now().toUtc().toIso8601String(),
    };
  }
}

DateTime _utcNow() => DateTime.now().toUtc();
