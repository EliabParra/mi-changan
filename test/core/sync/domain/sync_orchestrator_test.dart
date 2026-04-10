import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/core/sync/domain/sync_orchestrator.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_event.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_repository.dart';

void main() {
  group('SyncOrchestrator', () {
    test('drains ready events in order and marks synced', () async {
      final repo = _FakeOutboxRepository(
        ready: [
          _event('evt-1', occurredAt: DateTime.utc(2026, 4, 10, 12, 0)),
          _event('evt-2', occurredAt: DateTime.utc(2026, 4, 10, 12, 1)),
        ],
      );
      final remote = _FakeSyncRemoteClient();
      final orchestrator = SyncOrchestrator(
        outboxRepository: repo,
        remoteClient: remote,
        now: () => DateTime.utc(2026, 4, 10, 13, 0),
      );

      final report = await orchestrator.drain(limit: 10);

      expect(remote.appliedEventIds, ['evt-1', 'evt-2']);
      expect(repo.syncedEventIds, ['evt-1', 'evt-2']);
      expect(report.processed, 2);
      expect(report.synced, 2);
      expect(report.failed, 0);
      expect(report.conflicts, 0);
    });

    test('marks failed with exponential backoff for transient errors', () async {
      final failedEvent = _event(
        'evt-1',
        occurredAt: DateTime.utc(2026, 4, 10, 12, 0),
        attempts: 2,
      );
      final repo = _FakeOutboxRepository(ready: [failedEvent]);
      final remote = _FakeSyncRemoteClient(
        errorByEventId: {'evt-1': const SyncApplyTransientFailure('timeout')},
      );
      final now = DateTime.utc(2026, 4, 10, 13, 0);
      final orchestrator = SyncOrchestrator(
        outboxRepository: repo,
        remoteClient: remote,
        now: () => now,
      );

      final report = await orchestrator.drain(limit: 10);

      expect(repo.failedCalls, hasLength(1));
      expect(repo.failedCalls.first.eventId, 'evt-1');
      expect(repo.failedCalls.first.reason, 'timeout');
      expect(
        repo.failedCalls.first.nextRetryAt,
        now.add(const Duration(minutes: 4)),
      );
      expect(report.processed, 1);
      expect(report.failed, 1);
      expect(report.synced, 0);
      expect(report.conflicts, 0);
    });

    test('applies LWW conflict resolution and records conflict log', () async {
      final localWins = _event(
        'evt-local-wins',
        occurredAt: DateTime.utc(2026, 4, 10, 12, 0),
        payload: {
          'id': 'log-1',
          'updated_at': DateTime.utc(2026, 4, 10, 12, 10).toIso8601String(),
        },
      );
      final remoteWins = _event(
        'evt-remote-wins',
        occurredAt: DateTime.utc(2026, 4, 10, 12, 1),
        payload: {
          'id': 'log-2',
          'updated_at': DateTime.utc(2026, 4, 10, 12, 5).toIso8601String(),
        },
      );
      final repo = _FakeOutboxRepository(ready: [localWins, remoteWins]);
      final remote = _FakeSyncRemoteClient(
        errorByEventId: {
          'evt-local-wins': SyncApplyConflict(
            remoteUpdatedAt: DateTime.utc(2026, 4, 10, 12, 0),
            reason: 'version-conflict',
          ),
          'evt-remote-wins': SyncApplyConflict(
            remoteUpdatedAt: DateTime.utc(2026, 4, 10, 12, 30),
            reason: 'version-conflict',
          ),
        },
      );
      final now = DateTime.utc(2026, 4, 10, 13, 0);
      final orchestrator = SyncOrchestrator(
        outboxRepository: repo,
        remoteClient: remote,
        now: () => now,
      );

      final report = await orchestrator.drain(limit: 10);

      expect(remote.resolvePreferLocalCalls, ['evt-local-wins']);
      expect(repo.syncedEventIds, contains('evt-local-wins'));
      expect(repo.conflicts, hasLength(2));
      expect(
        repo.conflicts.first.record.resolution,
        SyncConflictResolution.lastWriteWinsLocal,
      );
      expect(
        repo.conflicts.last.record.resolution,
        SyncConflictResolution.lastWriteWinsRemote,
      );
      expect(report.processed, 2);
      expect(report.conflicts, 2);
      expect(report.synced, 1);
      expect(report.failed, 0);
    });
  });
}

class _FakeOutboxRepository implements SyncOutboxRepository {
  _FakeOutboxRepository({required this.ready});

  final List<SyncOutboxEvent> ready;
  final List<String> syncedEventIds = [];
  final List<_FailedCall> failedCalls = [];
  final List<_ConflictCall> conflicts = [];

  @override
  Future<void> enqueue(SyncOutboxEvent event) async {}

  @override
  Future<void> markConflict(String eventId, SyncConflictRecord conflict) async {
    conflicts.add(_ConflictCall(eventId: eventId, record: conflict));
  }

  @override
  Future<void> markFailed(
    String eventId, {
    required String reason,
    DateTime? nextRetryAt,
  }) async {
    failedCalls.add(
      _FailedCall(eventId: eventId, reason: reason, nextRetryAt: nextRetryAt),
    );
  }

  @override
  Future<void> markSynced(String eventId, {required DateTime syncedAt}) async {
    syncedEventIds.add(eventId);
  }

  @override
  Future<List<SyncOutboxEvent>> pullReady({required int limit}) async {
    return ready.take(limit).toList(growable: false);
  }
}

class _FailedCall {
  const _FailedCall({
    required this.eventId,
    required this.reason,
    required this.nextRetryAt,
  });

  final String eventId;
  final String reason;
  final DateTime? nextRetryAt;
}

class _ConflictCall {
  const _ConflictCall({required this.eventId, required this.record});

  final String eventId;
  final SyncConflictRecord record;
}

class _FakeSyncRemoteClient implements SyncRemoteClient {
  _FakeSyncRemoteClient({Map<String, Exception>? errorByEventId})
      : _errorByEventId = errorByEventId ?? {};

  final Map<String, Exception> _errorByEventId;
  final List<String> appliedEventIds = [];
  final List<String> resolvePreferLocalCalls = [];

  @override
  Future<void> apply(SyncOutboxEvent event) async {
    final error = _errorByEventId[event.id];
    if (error != null) {
      throw error;
    }
    appliedEventIds.add(event.id);
  }

  @override
  Future<void> resolveConflictPreferLocal(SyncOutboxEvent event) async {
    resolvePreferLocalCalls.add(event.id);
  }
}

SyncOutboxEvent _event(
  String id, {
  required DateTime occurredAt,
  int attempts = 0,
  Map<String, dynamic>? payload,
}) {
  return SyncOutboxEvent(
    id: id,
    schemaVersion: 1,
    idempotencyKey: 'idem-$id',
    entity: 'mileage_log',
    operation: SyncOutboxOperation.upsert,
    payload: payload ?? {'id': id, 'updated_at': occurredAt.toIso8601String()},
    occurredAt: occurredAt,
    status: SyncOutboxStatus.pending,
    attempts: attempts,
  );
}
