import 'dart:convert';

import 'package:mi_changan/core/sync/domain/sync_outbox_event.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_repository.dart';
import 'package:sqlite3/sqlite3.dart';

typedef Clock = DateTime Function();

class DriftSyncOutboxRepository implements SyncOutboxRepository {
  DriftSyncOutboxRepository(this._db, {Clock? now}) : _now = now ?? _utcNow;

  final Database _db;
  final Clock _now;

  @override
  Future<void> enqueue(SyncOutboxEvent event) async {
    _db.execute(
      '''
      INSERT OR REPLACE INTO outbox_events(
        id, schema_version, idempotency_key, entity, operation, payload_json,
        occurred_at, status, attempts, next_retry_at, synced_at, failure_reason
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        event.id,
        event.schemaVersion,
        event.idempotencyKey,
        event.entity,
        _operationToDb(event.operation),
        jsonEncode(event.payload),
        event.occurredAt.toUtc().toIso8601String(),
        _statusToDb(event.status),
        event.attempts,
        event.nextRetryAt?.toUtc().toIso8601String(),
        null,
        null,
      ],
    );
  }

  @override
  Future<List<SyncOutboxEvent>> pullReady({required int limit}) async {
    final nowIso = _now().toUtc().toIso8601String();
    final rows = _db.select(
      '''
      SELECT
        id, schema_version, idempotency_key, entity, operation, payload_json,
        occurred_at, status, attempts, next_retry_at
      FROM outbox_events
      WHERE status = ?
        AND (next_retry_at IS NULL OR next_retry_at <= ?)
      ORDER BY occurred_at ASC
      LIMIT ?
      ''',
      ['pending', nowIso, limit],
    );

    return rows.map(_eventFromRow).toList(growable: false);
  }

  @override
  Future<void> markSynced(String eventId, {required DateTime syncedAt}) async {
    _db.execute(
      '''
      UPDATE outbox_events
      SET status = ?, synced_at = ?, next_retry_at = NULL, failure_reason = NULL
      WHERE id = ?
      ''',
      ['synced', syncedAt.toUtc().toIso8601String(), eventId],
    );
  }

  @override
  Future<void> markFailed(
    String eventId, {
    required String reason,
    DateTime? nextRetryAt,
  }) async {
    _db.execute(
      '''
      UPDATE outbox_events
      SET
        status = ?,
        attempts = attempts + 1,
        next_retry_at = ?,
        failure_reason = ?
      WHERE id = ?
      ''',
      [
        'pending',
        nextRetryAt?.toUtc().toIso8601String(),
        reason,
        eventId,
      ],
    );
  }

  @override
  Future<void> markConflict(String eventId, SyncConflictRecord conflict) async {
    _db.execute(
      '''
      INSERT INTO sync_conflict_logs(
        event_id, entity, entity_id, local_updated_at, remote_updated_at,
        resolution, reason, recorded_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        conflict.eventId,
        conflict.entity,
        conflict.entityId,
        conflict.localUpdatedAt.toUtc().toIso8601String(),
        conflict.remoteUpdatedAt.toUtc().toIso8601String(),
        _resolutionToDb(conflict.resolution),
        conflict.reason,
        conflict.recordedAt.toUtc().toIso8601String(),
      ],
    );

    _db.execute(
      '''
      UPDATE outbox_events
      SET status = ?, failure_reason = ?
      WHERE id = ?
      ''',
      ['conflict', conflict.reason, eventId],
    );
  }

  SyncOutboxEvent _eventFromRow(Row row) {
    return SyncOutboxEvent(
      id: row['id'] as String,
      schemaVersion: row['schema_version'] as int,
      idempotencyKey: row['idempotency_key'] as String,
      entity: row['entity'] as String,
      operation: _operationFromDb(row['operation'] as String),
      payload: jsonDecode(row['payload_json'] as String) as Map<String, dynamic>,
      occurredAt: DateTime.parse(row['occurred_at'] as String).toUtc(),
      status: _statusFromDb(row['status'] as String),
      attempts: row['attempts'] as int,
      nextRetryAt: row['next_retry_at'] == null
          ? null
          : DateTime.parse(row['next_retry_at'] as String).toUtc(),
    );
  }
}

DateTime _utcNow() => DateTime.now().toUtc();

String _operationToDb(SyncOutboxOperation operation) {
  switch (operation) {
    case SyncOutboxOperation.upsert:
      return 'upsert';
    case SyncOutboxOperation.delete:
      return 'delete';
  }
}

SyncOutboxOperation _operationFromDb(String raw) {
  switch (raw) {
    case 'upsert':
      return SyncOutboxOperation.upsert;
    case 'delete':
      return SyncOutboxOperation.delete;
  }
  throw ArgumentError.value(raw, 'raw', 'Unknown outbox operation');
}

String _statusToDb(SyncOutboxStatus status) {
  switch (status) {
    case SyncOutboxStatus.pending:
      return 'pending';
    case SyncOutboxStatus.synced:
      return 'synced';
    case SyncOutboxStatus.failed:
      return 'failed';
    case SyncOutboxStatus.conflict:
      return 'conflict';
  }
}

SyncOutboxStatus _statusFromDb(String raw) {
  switch (raw) {
    case 'pending':
      return SyncOutboxStatus.pending;
    case 'synced':
      return SyncOutboxStatus.synced;
    case 'failed':
      return SyncOutboxStatus.failed;
    case 'conflict':
      return SyncOutboxStatus.conflict;
  }
  throw ArgumentError.value(raw, 'raw', 'Unknown outbox status');
}

String _resolutionToDb(SyncConflictResolution resolution) {
  switch (resolution) {
    case SyncConflictResolution.lastWriteWinsRemote:
      return 'last_write_wins_remote';
    case SyncConflictResolution.lastWriteWinsLocal:
      return 'last_write_wins_local';
  }
}
