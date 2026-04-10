import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_event.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_repository.dart';
import 'package:mi_changan/features/mileage/data/offline_first_mileage_repository.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/mileage/domain/mileage_repository.dart';

void main() {
  group('OfflineFirstMileageRepository', () {
    test('addLog enqueues outbox and remains visible when remote fails', () async {
      final remote = _FakeMileageRepository();
      final outbox = _FakeSyncOutboxRepository();
      final repo = OfflineFirstMileageRepository(
        remote: remote,
        outbox: outbox,
        now: () => DateTime.utc(2026, 4, 10, 17, 0),
      );
      remote.addError = Exception('offline');

      final log = _log(id: 'log-1', valueKm: 120.0);
      await repo.addLog(log);
      final projected = await repo.fetchLogs(userId: 'u1');

      expect(projected, hasLength(1));
      expect(projected.first.id, 'log-1');
      expect(projected.first.valueKm, 120.0);
      expect(outbox.enqueued, hasLength(1));
      expect(outbox.enqueued.first.entity, 'mileage_logs');
      expect(outbox.enqueued.first.operation, SyncOutboxOperation.upsert);
      expect(outbox.enqueued.first.payload['id'], 'log-1');
    });

    test('deleteLog enqueues delete and hides local item immediately', () async {
      final existing = [_log(id: 'log-keep'), _log(id: 'log-delete')];
      final remote = _FakeMileageRepository(existing);
      final outbox = _FakeSyncOutboxRepository();
      final repo = OfflineFirstMileageRepository(
        remote: remote,
        outbox: outbox,
        now: () => DateTime.utc(2026, 4, 10, 17, 5),
      );
      remote.deleteError = Exception('offline');

      await repo.fetchLogs(userId: 'u1');
      await repo.deleteLog('log-delete');
      final projected = await repo.fetchLogs(userId: 'u1');

      expect(projected.map((log) => log.id), ['log-keep']);
      expect(outbox.enqueued, hasLength(1));
      expect(outbox.enqueued.first.operation, SyncOutboxOperation.delete);
      expect(outbox.enqueued.first.payload['id'], 'log-delete');
    });
  });
}

class _FakeMileageRepository implements MileageRepository {
  _FakeMileageRepository([List<MileageLog>? logs]) : _logs = [...?logs];

  final List<MileageLog> _logs;
  Exception? addError;
  Exception? deleteError;

  @override
  Future<void> addLog(MileageLog log) async {
    if (addError != null) throw addError!;
    _logs.add(log);
  }

  @override
  Future<void> deleteLog(String logId) async {
    if (deleteError != null) throw deleteError!;
    _logs.removeWhere((log) => log.id == logId);
  }

  @override
  Future<List<MileageLog>> fetchLogs({required String userId}) async {
    return _logs.where((log) => log.userId == userId).toList(growable: false);
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

MileageLog _log({
  required String id,
  double valueKm = 100,
}) {
  return MileageLog(
    id: id,
    userId: 'u1',
    entryType: MileageEntryType.total,
    valueKm: valueKm,
    recordedAt: DateTime.utc(2026, 4, 10, 12, 0),
  );
}
