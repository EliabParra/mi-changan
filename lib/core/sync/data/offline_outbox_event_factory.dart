import 'package:mi_changan/core/sync/domain/sync_outbox_event.dart';

typedef OutboxNow = DateTime Function();

class OfflineOutboxEventFactory {
  OfflineOutboxEventFactory({OutboxNow? now}) : _now = now ?? _utcNow;

  final OutboxNow _now;

  SyncOutboxEvent buildUpsert({
    required String entity,
    required String entityId,
    required Map<String, dynamic> payload,
  }) {
    final occurredAt = _now().toUtc();
    const operation = SyncOutboxOperation.upsert;
    return _build(
      entity: entity,
      entityId: entityId,
      operation: operation,
      occurredAt: occurredAt,
      payload: payload,
    );
  }

  SyncOutboxEvent buildDelete({
    required String entity,
    required String entityId,
    required Map<String, dynamic> payload,
  }) {
    final occurredAt = _now().toUtc();
    const operation = SyncOutboxOperation.delete;
    return _build(
      entity: entity,
      entityId: entityId,
      operation: operation,
      occurredAt: occurredAt,
      payload: payload,
    );
  }

  SyncOutboxEvent _build({
    required String entity,
    required String entityId,
    required SyncOutboxOperation operation,
    required DateTime occurredAt,
    required Map<String, dynamic> payload,
  }) {
    final opName = operation == SyncOutboxOperation.upsert ? 'upsert' : 'delete';
    final eventId =
        '$entity-$entityId-$opName-${occurredAt.microsecondsSinceEpoch}';

    return SyncOutboxEvent(
      id: eventId,
      schemaVersion: 1,
      idempotencyKey: '$entity-$entityId-$opName',
      entity: entity,
      operation: operation,
      payload: payload,
      occurredAt: occurredAt,
      status: SyncOutboxStatus.pending,
    );
  }
}

DateTime _utcNow() => DateTime.now().toUtc();
