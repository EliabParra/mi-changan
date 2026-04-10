import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_event.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_repository.dart';
import 'package:mi_changan/features/services/data/offline_first_service_repository.dart';
import 'package:mi_changan/features/services/domain/service_record.dart';
import 'package:mi_changan/features/services/domain/service_repository.dart';

void main() {
  group('OfflineFirstServiceRepository', () {
    test('addRecord enqueues outbox and remains visible if remote fails', () async {
      final remote = _FakeServiceRepository();
      final outbox = _FakeSyncOutboxRepository();
      final repo = OfflineFirstServiceRepository(
        remote: remote,
        outbox: outbox,
        now: () => DateTime.utc(2026, 4, 10, 17, 20),
      );
      remote.addError = Exception('offline');

      final record = _record(id: 'svc-1', odometerKm: 18000);
      await repo.addRecord(record);
      final projected = await repo.fetchRecords(userId: 'u1');

      expect(projected, hasLength(1));
      expect(projected.first.id, 'svc-1');
      expect(projected.first.odometerKm, 18000.0);
      expect(outbox.enqueued, hasLength(1));
      expect(outbox.enqueued.first.entity, 'service_records');
      expect(outbox.enqueued.first.operation, SyncOutboxOperation.upsert);
      expect(outbox.enqueued.first.payload['id'], 'svc-1');
    });

    test('deleteRecord enqueues delete and removes projected state immediately', () async {
      final remote = _FakeServiceRepository([
        _record(id: 'svc-keep'),
        _record(id: 'svc-delete'),
      ]);
      final outbox = _FakeSyncOutboxRepository();
      final repo = OfflineFirstServiceRepository(
        remote: remote,
        outbox: outbox,
        now: () => DateTime.utc(2026, 4, 10, 17, 25),
      );
      remote.deleteError = Exception('offline');

      await repo.fetchRecords(userId: 'u1');
      await repo.deleteRecord('svc-delete');
      final projected = await repo.fetchRecords(userId: 'u1');

      expect(projected.map((record) => record.id), ['svc-keep']);
      expect(outbox.enqueued, hasLength(1));
      expect(outbox.enqueued.first.operation, SyncOutboxOperation.delete);
      expect(outbox.enqueued.first.payload['id'], 'svc-delete');
    });
  });
}

class _FakeServiceRepository implements ServiceRepository {
  _FakeServiceRepository([List<ServiceRecord>? records]) : _records = [...?records];

  final List<ServiceRecord> _records;
  Exception? addError;
  Exception? deleteError;

  @override
  Future<void> addRecord(ServiceRecord record) async {
    if (addError != null) throw addError!;
    _records.add(record);
  }

  @override
  Future<void> deleteRecord(String recordId) async {
    if (deleteError != null) throw deleteError!;
    _records.removeWhere((record) => record.id == recordId);
  }

  @override
  Future<List<ServiceRecord>> fetchRecords({required String userId}) async {
    return _records
        .where((record) => record.userId == userId)
        .toList(growable: false);
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

ServiceRecord _record({
  required String id,
  double odometerKm = 15000,
}) {
  return ServiceRecord(
    id: id,
    userId: 'u1',
    reminderId: 'rem-1',
    reminderLabel: 'Aceite',
    odometerKm: odometerKm,
    costUsd: 32.5,
    serviceDate: DateTime.utc(2026, 4, 1),
  );
}
