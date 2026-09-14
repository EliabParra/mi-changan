import 'package:mi_changan/core/sync/data/offline_outbox_event_factory.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_repository.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/mileage/domain/mileage_repository.dart';

class OfflineFirstMileageRepository implements MileageRepository {
  OfflineFirstMileageRepository({
    required MileageRepository remote,
    required SyncOutboxRepository outbox,
    DateTime Function()? now,
  })  : _remote = remote,
        _outbox = outbox,
        _outboxFactory = OfflineOutboxEventFactory(now: now);

  final MileageRepository _remote;
  final SyncOutboxRepository _outbox;
  final OfflineOutboxEventFactory _outboxFactory;

  final Map<String, List<MileageLog>> _cacheByUser = {};

  @override
  Future<void> addLog(MileageLog log) async {
    _upsertProjected(log);
    final event = _outboxFactory.buildUpsert(
      entity: 'mileage_logs',
      entityId: log.id,
      payload: _toPayload(log),
    );
    await _outbox.enqueue(event);

    try {
      await _remote.addLog(log);
    } catch (_) {
      // Offline-first: local projection/outbox are SSOT for UI continuity.
    }
  }

  @override
  Future<void> deleteLog(String logId) async {
    _deleteProjected(logId);
    final event = _outboxFactory.buildDelete(
      entity: 'mileage_logs',
      entityId: logId,
      payload: {'id': logId},
    );
    await _outbox.enqueue(event);

    try {
      await _remote.deleteLog(logId);
    } catch (_) {
      // Offline-first: local projection/outbox are SSOT for UI continuity.
    }
  }

  @override
  Future<List<MileageLog>> fetchLogs({required String userId}) async {
    final cached = _cacheByUser[userId];
    if (cached != null) {
      return List.unmodifiable(cached);
    }

    final remoteLogs = await _remote.fetchLogs(userId: userId);
    _cacheByUser[userId] = [...remoteLogs];
    return List.unmodifiable(_cacheByUser[userId]!);
  }

  void _upsertProjected(MileageLog log) {
    final current = [...?_cacheByUser[log.userId]];
    final index = current.indexWhere((value) => value.id == log.id);
    if (index >= 0) {
      current[index] = log;
    } else {
      current.add(log);
    }
    _cacheByUser[log.userId] = current;
  }

  void _deleteProjected(String logId) {
    for (final userId in _cacheByUser.keys.toList(growable: false)) {
      final current = [...?_cacheByUser[userId]];
      final initial = current.length;
      current.removeWhere((log) => log.id == logId);
      if (current.length != initial) {
        _cacheByUser[userId] = current;
        break;
      }
    }
  }

  Map<String, dynamic> _toPayload(MileageLog log) {
    return {
      'id': log.id,
      'user_id': log.userId,
      'entry_type': log.entryType == MileageEntryType.total ? 'total' : 'distance',
      'value_km': log.valueKm,
      'recorded_at': log.recordedAt.toUtc().toIso8601String(),
      if (log.notes != null) 'notes': log.notes,
      'updated_at': log.recordedAt.toUtc().toIso8601String(),
    };
  }
}
