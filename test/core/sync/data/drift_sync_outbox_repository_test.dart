import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/core/local/db/local_schema_migrator.dart';
import 'package:mi_changan/core/sync/data/drift_sync_outbox_repository.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_event.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('DriftSyncOutboxRepository', () {
    test('pullReady returns pending events in occurredAt order', () async {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      LocalSchemaMigrator.migrateToLatest(db);

      var now = DateTime.utc(2026, 4, 10, 14, 0);
      final repo = DriftSyncOutboxRepository(db, now: () => now);

      await repo.enqueue(_event('evt-2', occurredAt: DateTime.utc(2026, 4, 10, 13, 2)));
      await repo.enqueue(_event('evt-1', occurredAt: DateTime.utc(2026, 4, 10, 13, 1)));
      await repo.enqueue(
        _event(
          'evt-future',
          occurredAt: DateTime.utc(2026, 4, 10, 13, 0),
          nextRetryAt: DateTime.utc(2026, 4, 10, 15, 0),
        ),
      );

      final ready = await repo.pullReady(limit: 10);
      final limited = await repo.pullReady(limit: 1);

      expect(ready.map((e) => e.id).toList(), ['evt-1', 'evt-2']);
      expect(limited.map((e) => e.id).toList(), ['evt-1']);

      now = DateTime.utc(2026, 4, 10, 16, 0);
      final retried = await repo.pullReady(limit: 10);
      expect(retried.map((e) => e.id).toList(), ['evt-future', 'evt-1', 'evt-2']);
    });

    test('markFailed increments attempts and schedules retry back to pending', () async {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      LocalSchemaMigrator.migrateToLatest(db);

      var now = DateTime.utc(2026, 4, 10, 14, 0);
      final repo = DriftSyncOutboxRepository(db, now: () => now);
      await repo.enqueue(_event('evt-1', occurredAt: DateTime.utc(2026, 4, 10, 13, 0)));

      await repo.markFailed(
        'evt-1',
        reason: 'network-timeout',
        nextRetryAt: DateTime.utc(2026, 4, 10, 14, 30),
      );

      final row = db.select(
        'SELECT status, attempts, failure_reason, next_retry_at FROM outbox_events WHERE id = ?',
        ['evt-1'],
      );

      expect(row, hasLength(1));
      expect(row.first['status'], 'pending');
      expect(row.first['attempts'], 1);
      expect(row.first['failure_reason'], 'network-timeout');

      final notReady = await repo.pullReady(limit: 10);
      expect(notReady, isEmpty);

      now = DateTime.utc(2026, 4, 10, 14, 31);
      final ready = await repo.pullReady(limit: 10);
      expect(ready.map((event) => event.id).toList(), ['evt-1']);
    });

    test('markConflict persists conflict log and marks event as conflict', () async {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      LocalSchemaMigrator.migrateToLatest(db);
      final repo = DriftSyncOutboxRepository(db);

      await repo.enqueue(_event('evt-1', occurredAt: DateTime.utc(2026, 4, 10, 13, 0)));
      await repo.markConflict(
        'evt-1',
        SyncConflictRecord(
          eventId: 'evt-1',
          entity: 'mileage_log',
          entityId: 'log-1',
          localUpdatedAt: DateTime.utc(2026, 4, 10, 13, 0),
          remoteUpdatedAt: DateTime.utc(2026, 4, 10, 13, 5),
          resolution: SyncConflictResolution.lastWriteWinsRemote,
          reason: 'remote-won-lww',
          recordedAt: DateTime.utc(2026, 4, 10, 13, 6),
        ),
      );

      final conflictRows = db.select(
        'SELECT event_id, entity_id, resolution, reason FROM sync_conflict_logs WHERE event_id = ?',
        ['evt-1'],
      );
      final eventRows = db.select(
        'SELECT status, failure_reason FROM outbox_events WHERE id = ?',
        ['evt-1'],
      );

      expect(conflictRows, hasLength(1));
      expect(conflictRows.first['resolution'], 'last_write_wins_remote');
      expect(conflictRows.first['reason'], 'remote-won-lww');
      expect(eventRows, hasLength(1));
      expect(eventRows.first['status'], 'conflict');
      expect(eventRows.first['failure_reason'], 'remote-won-lww');
    });
  });
}

SyncOutboxEvent _event(
  String id, {
  required DateTime occurredAt,
  DateTime? nextRetryAt,
}) {
  return SyncOutboxEvent(
    id: id,
    schemaVersion: 1,
    idempotencyKey: 'idem-$id',
    entity: 'mileage_log',
    operation: SyncOutboxOperation.upsert,
    payload: {
      'id': id,
      'updated_at': occurredAt.toIso8601String(),
    },
    occurredAt: occurredAt,
    status: SyncOutboxStatus.pending,
    nextRetryAt: nextRetryAt,
  );
}
