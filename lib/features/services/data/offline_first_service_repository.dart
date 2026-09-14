import 'package:mi_changan/core/sync/data/offline_outbox_event_factory.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_repository.dart';
import 'package:mi_changan/features/services/domain/service_record.dart';
import 'package:mi_changan/features/services/domain/service_repository.dart';

class OfflineFirstServiceRepository implements ServiceRepository {
  OfflineFirstServiceRepository({
    required ServiceRepository remote,
    required SyncOutboxRepository outbox,
    DateTime Function()? now,
  })  : _remote = remote,
        _outbox = outbox,
        _outboxFactory = OfflineOutboxEventFactory(now: now),
        _now = now ?? _utcNow;

  final ServiceRepository _remote;
  final SyncOutboxRepository _outbox;
  final OfflineOutboxEventFactory _outboxFactory;
  final DateTime Function() _now;

  final Map<String, List<ServiceRecord>> _cacheByUser = {};

  @override
  Future<void> addRecord(ServiceRecord record) async {
    _upsertProjected(record);
    final event = _outboxFactory.buildUpsert(
      entity: 'service_records',
      entityId: record.id,
      payload: _toPayload(record),
    );
    await _outbox.enqueue(event);

    try {
      await _remote.addRecord(record);
    } catch (_) {
      // Offline-first: local projection/outbox are SSOT for UI continuity.
    }
  }

  @override
  Future<void> deleteRecord(String recordId) async {
    _deleteProjected(recordId);
    final event = _outboxFactory.buildDelete(
      entity: 'service_records',
      entityId: recordId,
      payload: {'id': recordId},
    );
    await _outbox.enqueue(event);

    try {
      await _remote.deleteRecord(recordId);
    } catch (_) {
      // Offline-first: local projection/outbox are SSOT for UI continuity.
    }
  }

  @override
  Future<List<ServiceRecord>> fetchRecords({required String userId}) async {
    final cached = _cacheByUser[userId];
    if (cached != null) {
      return List.unmodifiable(cached);
    }

    final remoteRecords = await _remote.fetchRecords(userId: userId);
    _cacheByUser[userId] = [...remoteRecords];
    return List.unmodifiable(_cacheByUser[userId]!);
  }

  void _upsertProjected(ServiceRecord record) {
    final current = [...?_cacheByUser[record.userId]];
    final index = current.indexWhere((value) => value.id == record.id);
    if (index >= 0) {
      current[index] = record;
    } else {
      current.add(record);
    }
    _cacheByUser[record.userId] = current;
  }

  void _deleteProjected(String recordId) {
    for (final userId in _cacheByUser.keys.toList(growable: false)) {
      final current = [...?_cacheByUser[userId]];
      final initial = current.length;
      current.removeWhere((record) => record.id == recordId);
      if (current.length != initial) {
        _cacheByUser[userId] = current;
        break;
      }
    }
  }

  Map<String, dynamic> _toPayload(ServiceRecord record) {
    return {
      'id': record.id,
      'user_id': record.userId,
      'reminder_id': record.reminderId,
      'reminder_label': record.reminderLabel,
      'odometer_km': record.odometerKm,
      'cost_usd': record.costUsd,
      'service_date': record.serviceDate.toUtc().toIso8601String(),
      if (record.workshopName != null) 'workshop_name': record.workshopName,
      if (record.notes != null) 'notes': record.notes,
      'updated_at': _now().toUtc().toIso8601String(),
    };
  }
}

DateTime _utcNow() => DateTime.now().toUtc();
