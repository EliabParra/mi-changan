import 'package:mi_changan/core/sync/domain/sync_outbox_event.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_repository.dart';

typedef SyncClock = DateTime Function();

abstract class SyncRemoteClient {
  Future<void> apply(SyncOutboxEvent event);
  Future<void> resolveConflictPreferLocal(SyncOutboxEvent event);
}

class SyncApplyTransientFailure implements Exception {
  const SyncApplyTransientFailure(this.reason);

  final String reason;
}

class SyncApplyConflict implements Exception {
  const SyncApplyConflict({required this.remoteUpdatedAt, required this.reason});

  final DateTime remoteUpdatedAt;
  final String reason;
}

class SyncDrainReport {
  const SyncDrainReport({
    required this.processed,
    required this.synced,
    required this.failed,
    required this.conflicts,
  });

  final int processed;
  final int synced;
  final int failed;
  final int conflicts;
}

class SyncOrchestrator {
  SyncOrchestrator({
    required SyncOutboxRepository outboxRepository,
    required SyncRemoteClient remoteClient,
    SyncClock? now,
  })  : _outboxRepository = outboxRepository,
        _remoteClient = remoteClient,
        _now = now ?? _utcNow;

  final SyncOutboxRepository _outboxRepository;
  final SyncRemoteClient _remoteClient;
  final SyncClock _now;

  Future<SyncDrainReport> drain({required int limit}) async {
    final events = await _outboxRepository.pullReady(limit: limit);
    var synced = 0;
    var failed = 0;
    var conflicts = 0;

    for (final event in events) {
      try {
        await _remoteClient.apply(event);
        await _outboxRepository.markSynced(event.id, syncedAt: _now());
        synced += 1;
      } on SyncApplyConflict catch (conflict) {
        conflicts += 1;
        final localUpdatedAt = _extractLocalUpdatedAt(event, fallback: event.occurredAt);

        if (!localUpdatedAt.isBefore(conflict.remoteUpdatedAt.toUtc())) {
          await _remoteClient.resolveConflictPreferLocal(event);
          await _outboxRepository.markSynced(event.id, syncedAt: _now());
          final record = SyncConflictRecord(
            eventId: event.id,
            entity: event.entity,
            entityId: _extractEntityId(event),
            localUpdatedAt: localUpdatedAt,
            remoteUpdatedAt: conflict.remoteUpdatedAt.toUtc(),
            resolution: SyncConflictResolution.lastWriteWinsLocal,
            reason: conflict.reason,
            recordedAt: _now(),
          );
          await _outboxRepository.markConflict(event.id, record);
          synced += 1;
          continue;
        }

        final record = SyncConflictRecord(
          eventId: event.id,
          entity: event.entity,
          entityId: _extractEntityId(event),
          localUpdatedAt: localUpdatedAt,
          remoteUpdatedAt: conflict.remoteUpdatedAt.toUtc(),
          resolution: SyncConflictResolution.lastWriteWinsRemote,
          reason: conflict.reason,
          recordedAt: _now(),
        );
        await _outboxRepository.markConflict(event.id, record);
      } on SyncApplyTransientFailure catch (failure) {
        failed += 1;
        final delay = _backoffForAttempt(event.attempts + 1);
        await _outboxRepository.markFailed(
          event.id,
          reason: failure.reason,
          nextRetryAt: _now().add(delay),
        );
      }
    }

    return SyncDrainReport(
      processed: events.length,
      synced: synced,
      failed: failed,
      conflicts: conflicts,
    );
  }
}

DateTime _utcNow() => DateTime.now().toUtc();

Duration _backoffForAttempt(int attempts) {
  final exponent = attempts <= 1 ? 0 : attempts - 1;
  final minutes = 1 << exponent;
  return Duration(minutes: minutes);
}

DateTime _extractLocalUpdatedAt(
  SyncOutboxEvent event, {
  required DateTime fallback,
}) {
  final raw = event.payload['updated_at'];
  if (raw is! String) {
    return fallback.toUtc();
  }

  try {
    return DateTime.parse(raw).toUtc();
  } on FormatException {
    return fallback.toUtc();
  }
}

String _extractEntityId(SyncOutboxEvent event) {
  final id = event.payload['id'];
  if (id is String && id.isNotEmpty) {
    return id;
  }
  return event.id;
}
