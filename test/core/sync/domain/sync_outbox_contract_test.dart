import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_event.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_repository.dart';

void main() {
  group('SyncOutboxEvent', () {
    test('stores version and conflict metadata fields', () {
      final event = SyncOutboxEvent(
        id: 'evt-1',
        schemaVersion: 1,
        idempotencyKey: 'idem-1',
        entity: 'mileage_log',
        operation: SyncOutboxOperation.upsert,
        payload: const {'id': 'log-1', 'value_km': 120.0},
        occurredAt: DateTime.utc(2026, 4, 1, 10),
        status: SyncOutboxStatus.pending,
      );

      expect(event.schemaVersion, 1);
      expect(event.idempotencyKey, 'idem-1');
      expect(event.operation, SyncOutboxOperation.upsert);
      expect(event.status, SyncOutboxStatus.pending);
    });
  });

  group('SyncOutboxRepository contract', () {
    test('marks conflict with persisted conflict record', () async {
      final repo = _FakeSyncOutboxRepository();
      final record = SyncConflictRecord(
        eventId: 'evt-1',
        entity: 'mileage_log',
        entityId: 'log-1',
        localUpdatedAt: DateTime.utc(2026, 4, 1, 10),
        remoteUpdatedAt: DateTime.utc(2026, 4, 1, 11),
        resolution: SyncConflictResolution.lastWriteWinsRemote,
        reason: 'remote-won-lww',
        recordedAt: DateTime.utc(2026, 4, 1, 11, 5),
      );

      await repo.markConflict('evt-1', record);

      expect(repo.markedConflictEventId, 'evt-1');
      expect(repo.savedConflict?.entityId, 'log-1');
      expect(
        repo.savedConflict?.resolution,
        SyncConflictResolution.lastWriteWinsRemote,
      );
    });
  });
}

class _FakeSyncOutboxRepository implements SyncOutboxRepository {
  String? markedConflictEventId;
  SyncConflictRecord? savedConflict;

  @override
  Future<void> enqueue(SyncOutboxEvent event) async {}

  @override
  Future<void> markConflict(String eventId, SyncConflictRecord conflict) async {
    markedConflictEventId = eventId;
    savedConflict = conflict;
  }

  @override
  Future<void> markFailed(
    String eventId, {
    required String reason,
    DateTime? nextRetryAt,
  }) async {}

  @override
  Future<void> markSynced(String eventId, {required DateTime syncedAt}) async {}

  @override
  Future<List<SyncOutboxEvent>> pullReady({required int limit}) async {
    return const [];
  }
}
