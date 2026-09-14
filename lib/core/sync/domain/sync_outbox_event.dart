enum SyncOutboxOperation { upsert, delete }

enum SyncOutboxStatus { pending, synced, failed, conflict }

class SyncOutboxEvent {
  const SyncOutboxEvent({
    required this.id,
    required this.schemaVersion,
    required this.idempotencyKey,
    required this.entity,
    required this.operation,
    required this.payload,
    required this.occurredAt,
    required this.status,
    this.attempts = 0,
    this.nextRetryAt,
  });

  final String id;
  final int schemaVersion;
  final String idempotencyKey;
  final String entity;
  final SyncOutboxOperation operation;
  final Map<String, dynamic> payload;
  final DateTime occurredAt;
  final SyncOutboxStatus status;
  final int attempts;
  final DateTime? nextRetryAt;
}

enum SyncConflictResolution { lastWriteWinsRemote, lastWriteWinsLocal }

class SyncConflictRecord {
  const SyncConflictRecord({
    required this.eventId,
    required this.entity,
    required this.entityId,
    required this.localUpdatedAt,
    required this.remoteUpdatedAt,
    required this.resolution,
    required this.reason,
    required this.recordedAt,
  });

  final String eventId;
  final String entity;
  final String entityId;
  final DateTime localUpdatedAt;
  final DateTime remoteUpdatedAt;
  final SyncConflictResolution resolution;
  final String reason;
  final DateTime recordedAt;
}
