import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/core/sync/domain/sync_orchestrator.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_event.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_repository.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';
import 'package:mi_changan/features/mileage/data/offline_first_mileage_repository.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log_queries.dart';
import 'package:mi_changan/features/mileage/domain/mileage_repository.dart';
import 'package:mi_changan/features/mileage/domain/mileage_temporal_validator.dart';
import 'package:mi_changan/features/projections/domain/projection_maintenance_composer.dart';
import 'package:mi_changan/features/projections/domain/projection_point.dart';
import 'package:mi_changan/features/services/domain/service_record.dart';
import 'package:mi_changan/features/settings/domain/export_import_service.dart';
import 'package:mi_changan/features/settings/domain/export_schema_migrator.dart';
import 'package:mi_changan/features/settings/domain/vehicle_settings_notifier.dart';
import 'package:mi_changan/features/tracker/data/local_tracking_session_repository.dart';
import 'package:mi_changan/features/tracker/domain/gps_point.dart';
import 'package:mi_changan/features/tracker/domain/tracking_session_state.dart';

void main() {
  group('PRD-100 closure acceptance matrix', () {
    test(
      'gps-real-time-tracking :: Start trip and live map (first point <=5s, intervals <=10s)',
      () async {
        final repository = LocalTrackingSessionRepository();
        final startedAt = DateTime.now().toUtc();

        await repository.start(startedAt);
        await repository.append(
          GpsPoint(
            lat: 10.48,
            lng: -66.90,
            recordedAt: startedAt.add(const Duration(seconds: 4)),
          ),
        );
        await repository.append(
          GpsPoint(
            lat: 10.49,
            lng: -66.91,
            recordedAt: startedAt.add(const Duration(seconds: 10)),
          ),
        );
        await repository.append(
          GpsPoint(
            lat: 10.50,
            lng: -66.92,
            recordedAt: startedAt.add(const Duration(seconds: 20)),
          ),
        );

        final restored = await repository.restoreIfFresh(const Duration(hours: 2));
        final points = restored.points;

        expect(restored.status, TrackingSessionStatus.tracking);
        expect(points, hasLength(3));
        expect(
          points.first.recordedAt.difference(startedAt).inSeconds,
          lessThanOrEqualTo(5),
        );

        for (var index = 1; index < points.length; index++) {
          final delta = points[index].recordedAt
              .difference(points[index - 1].recordedAt)
              .inSeconds;
          expect(delta, lessThanOrEqualTo(10));
        }
      },
    );

    test(
      'gps-real-time-tracking :: Stop summary is immutable and interrupted session resumes with same trip id',
      () async {
        final repository = LocalTrackingSessionRepository();
        final startedAt = DateTime.now().toUtc();

        await repository.start(startedAt);
        await repository.append(
          GpsPoint(
            lat: 10.48,
            lng: -66.90,
            recordedAt: startedAt.add(const Duration(seconds: 5)),
          ),
        );
        await repository.append(
          GpsPoint(
            lat: 10.51,
            lng: -66.90,
            recordedAt: startedAt.add(const Duration(minutes: 12)),
          ),
        );

        final stopped = await repository.stop(
          userId: 'u1',
          now: startedAt.add(const Duration(minutes: 12)),
        );

        expect(stopped, isNotNull);
        expect(stopped!.distanceKm, greaterThan(0));
        expect(stopped.duration, const Duration(minutes: 12));
        expect(stopped.pointsCount, 2);

        final afterStop = await repository.restoreIfFresh(const Duration(hours: 2));
        expect(afterStop.status, TrackingSessionStatus.stopped);
        expect(afterStop.tripId, stopped.tripId);
        expect(afterStop.points, hasLength(stopped.pointsCount));

        final interrupted = LocalTrackingSessionRepository();
        await interrupted.start(startedAt);
        final first = await interrupted.restoreIfFresh(const Duration(hours: 2));
        await interrupted.start(startedAt.add(const Duration(minutes: 30)));
        final resumed = await interrupted.restoreIfFresh(const Duration(hours: 2));

        expect(first.tripId, isNotNull);
        expect(resumed.tripId, first.tripId);
      },
    );

    test(
      'manual-mileage-date-entry :: Save selected timestamp and keep history ordered by timestamp',
      () {
        final selectedTimestamp = DateTime.utc(2026, 4, 9, 9, 30);
        final logs = [
          MileageLog(
            id: 'late',
            userId: 'u1',
            entryType: MileageEntryType.total,
            valueKm: 12000,
            recordedAt: DateTime.utc(2026, 4, 10, 8, 0),
          ),
          MileageLog(
            id: 'selected',
            userId: 'u1',
            entryType: MileageEntryType.total,
            valueKm: 11800,
            recordedAt: selectedTimestamp,
          ),
        ];

        final ordered = orderMileageLogsByTimestamp(logs, newestFirst: false);

        expect(
          ordered.map((log) => log.id).toList(growable: false),
          ['selected', 'late'],
        );
        expect(ordered.first.recordedAt, selectedTimestamp);
      },
    );

    test(
      'manual-mileage-date-entry :: Reject >5m future and require confirmation for lower odometer',
      () {
        const validator = MileageTemporalValidator();
        final now = DateTime.utc(2026, 4, 10, 12, 0, 0);

        final futureInvalid = validator.validate(
          entryType: MileageEntryType.total,
          valueKm: 35000,
          selectedAtUtc: now.add(const Duration(minutes: 6)),
          nowUtc: now,
          latestTotalOdometerKm: 34900,
        );
        expect(futureInvalid.isValid, isFalse);

        final lowerNeedsConfirmation = validator.validate(
          entryType: MileageEntryType.total,
          valueKm: 34999,
          selectedAtUtc: now,
          nowUtc: now,
          latestTotalOdometerKm: 35000,
        );
        expect(lowerNeedsConfirmation.isValid, isTrue);
        expect(lowerNeedsConfirmation.requiresLowerOdometerConfirmation, isTrue);
      },
    );

    test(
      'comprehensive-json-backup :: Export contains schema metadata and exact entity counts',
      () {
        final exported = ExportImportService.exportToJson(
          mileageLogs: [
            MileageLog(
              id: 'log-1',
              userId: 'u1',
              entryType: MileageEntryType.distance,
              valueKm: 20,
              recordedAt: DateTime.utc(2026, 4, 1),
            ),
          ],
          reminders: [
            MaintenanceReminder(
              id: 'rem-1',
              userId: 'u1',
              label: 'Aceite',
              intervalKm: 5000,
              lastServiceKm: 10000,
              lastServiceDate: DateTime.utc(2026, 1, 1),
            ),
          ],
          serviceRecords: [
            ServiceRecord(
              id: 'srv-1',
              userId: 'u1',
              reminderId: 'rem-1',
              reminderLabel: 'Aceite',
              odometerKm: 15000,
              costUsd: 20,
              serviceDate: DateTime.utc(2026, 2, 1),
            ),
          ],
          settings: const VehicleSettings(
            initialKm: 5000,
            nextServiceKm: 18000,
          ),
        );

        final imported = ExportImportService.importFromJson(exported);

        expect(imported.schemaVersion, kCurrentExportSchemaVersion);
        expect(imported.mileageLogs, hasLength(1));
        expect(imported.reminders, hasLength(1));
        expect(imported.serviceRecords, hasLength(1));
        expect(imported.settings, isNotNull);
      },
    );

    test(
      'comprehensive-json-backup :: Import restores legacy payload compatibility without dropping fields',
      () {
        const legacyPayload = '''
{
  "schema_version": 1,
  "exported_at": "2026-04-10T10:00:00.000Z",
  "mileage_logs": [
    {
      "id": "log-legacy-1",
      "user_id": "u1",
      "entry_type": "total",
      "value_km": 10000,
      "recorded_at": "2026-01-01T00:00:00.000Z"
    }
  ],
  "maintenance_reminders": [
    {
      "id": "rem-legacy-1",
      "user_id": "u1",
      "label": "Filtro",
      "interval_km": 5000,
      "last_service_km": 8000,
      "last_service_date": "2025-12-31T00:00:00.000Z"
    }
  ],
  "service_records": [
    {
      "id": "srv-legacy-1",
      "user_id": "u1",
      "reminder_id": "rem-legacy-1",
      "reminder_label": "Filtro",
      "odometer_km": 9000,
      "cost_usd": 12.5,
      "service_date": "2026-01-03T00:00:00.000Z"
    }
  ],
  "vehicle_settings": {
    "initialKm": 7000,
    "nextServiceKm": 13000
  }
}
''';

        final imported = ExportImportService.importFromJson(legacyPayload);

        expect(imported.schemaVersion, kCurrentExportSchemaVersion);
        expect(imported.mileageLogs.single.id, 'log-legacy-1');
        expect(imported.reminders.single.label, 'Filtro');
        expect(imported.serviceRecords.single.id, 'srv-legacy-1');
        expect(imported.settings!.initialKm, 7000);
      },
    );

    test(
      'maintenance-aware-projections :: Projection shows due and near-due markers',
      () {
        final model = ProjectionMaintenanceComposer.compose(
          points: [
            ProjectionPoint(month: DateTime.utc(2026, 4, 1), estimatedKm: 12000),
            ProjectionPoint(month: DateTime.utc(2026, 5, 1), estimatedKm: 12600),
          ],
          reminders: [
            MaintenanceReminder(
              id: 'due',
              userId: 'u1',
              label: 'Aceite',
              intervalKm: 5000,
              lastServiceKm: 7000,
              lastServiceDate: DateTime.utc(2026, 1, 1),
              currentKm: 12000,
            ),
            MaintenanceReminder(
              id: 'near',
              userId: 'u1',
              label: 'Filtro',
              intervalKm: 5000,
              lastServiceKm: 7000,
              lastServiceDate: DateTime.utc(2026, 1, 1),
              currentKm: 11600,
            ),
          ],
          now: DateTime.utc(2026, 4, 10),
        );

        expect(
          model.maintenanceMarkers.map((marker) => marker.status),
          containsAll([
            MaintenanceMarkerStatus.due,
            MaintenanceMarkerStatus.nearDue,
          ]),
        );
      },
    );

    test(
      'maintenance-aware-projections :: Refresh updates markers and removes outdated entries',
      () {
        final points = [
          ProjectionPoint(
            month: DateTime.utc(2026, 4, 1),
            estimatedKm: 12000,
          ),
        ];

        final before = ProjectionMaintenanceComposer.compose(
          points: points,
          reminders: [
            MaintenanceReminder(
              id: 'r1',
              userId: 'u1',
              label: 'Aceite',
              intervalKm: 5000,
              lastServiceKm: 7000,
              lastServiceDate: DateTime.utc(2026, 1, 1),
              currentKm: 12000,
            ),
          ],
          now: DateTime.utc(2026, 4, 10),
        );
        expect(before.maintenanceMarkers, hasLength(1));

        final after = ProjectionMaintenanceComposer.compose(
          points: points,
          reminders: [
            MaintenanceReminder(
              id: 'r1',
              userId: 'u1',
              label: 'Aceite',
              intervalKm: 5000,
              lastServiceKm: 12000,
              lastServiceDate: DateTime.utc(2026, 4, 10),
              currentKm: 12000,
            ),
          ],
          now: DateTime.utc(2026, 4, 11),
        );

        expect(after.maintenanceMarkers, isEmpty);
      },
    );

    test(
      'offline-sync-queue :: Offline writes commit locally and enqueue operation metadata',
      () async {
        final remote = _FakeMileageRepository();
        remote.addError = Exception('offline');
        final outbox = _FakeSyncOutboxRepository();
        final repository = OfflineFirstMileageRepository(
          remote: remote,
          outbox: outbox,
          now: () => DateTime.utc(2026, 4, 10, 17, 0),
        );

        final log = MileageLog(
          id: 'offline-log-1',
          userId: 'u1',
          entryType: MileageEntryType.total,
          valueKm: 15000,
          recordedAt: DateTime.utc(2026, 4, 10, 16, 59),
        );

        await repository.addLog(log);
        final logs = await repository.fetchLogs(userId: 'u1');

        expect(logs.map((value) => value.id).toList(growable: false), ['offline-log-1']);
        expect(outbox.enqueued, hasLength(1));
        expect(outbox.enqueued.single.operation, SyncOutboxOperation.upsert);
        expect(outbox.enqueued.single.payload['id'], 'offline-log-1');
        expect(outbox.enqueued.single.occurredAt, DateTime.utc(2026, 4, 10, 17, 0));
      },
    );

    test(
      'offline-sync-queue :: Reconnect drains in order and records LWW conflict resolution',
      () async {
        final eventA = SyncOutboxEvent(
          id: 'evt-1',
          schemaVersion: 1,
          idempotencyKey: 'idem-1',
          entity: 'mileage_logs',
          operation: SyncOutboxOperation.upsert,
          payload: {
            'id': 'log-1',
            'updated_at': DateTime.utc(2026, 4, 10, 12, 10).toIso8601String(),
          },
          occurredAt: DateTime.utc(2026, 4, 10, 12, 0),
          status: SyncOutboxStatus.pending,
          attempts: 0,
        );
        final eventB = SyncOutboxEvent(
          id: 'evt-2',
          schemaVersion: 1,
          idempotencyKey: 'idem-2',
          entity: 'mileage_logs',
          operation: SyncOutboxOperation.upsert,
          payload: {
            'id': 'log-2',
            'updated_at': DateTime.utc(2026, 4, 10, 12, 5).toIso8601String(),
          },
          occurredAt: DateTime.utc(2026, 4, 10, 12, 1),
          status: SyncOutboxStatus.pending,
          attempts: 0,
        );
        final repository = _FakeSyncOutboxRepository(ready: [eventA, eventB]);
        final remote = _FakeSyncRemoteClient(
          errorByEventId: {
            'evt-1': SyncApplyConflict(
              remoteUpdatedAt: DateTime.utc(2026, 4, 10, 12, 0),
              reason: 'version-conflict',
            ),
            'evt-2': SyncApplyConflict(
              remoteUpdatedAt: DateTime.utc(2026, 4, 10, 12, 30),
              reason: 'version-conflict',
            ),
          },
        );
        final orchestrator = SyncOrchestrator(
          outboxRepository: repository,
          remoteClient: remote,
          now: () => DateTime.utc(2026, 4, 10, 13, 0),
        );

        final report = await orchestrator.drain(limit: 10);

        expect(remote.appliedEventIds, ['evt-1', 'evt-2']);
        expect(remote.resolvePreferLocalCalls, ['evt-1']);
        expect(repository.syncedEventIds, ['evt-1']);
        expect(repository.conflicts, hasLength(2));
        expect(
          repository.conflicts.first.record.resolution,
          SyncConflictResolution.lastWriteWinsLocal,
        );
        expect(
          repository.conflicts.last.record.resolution,
          SyncConflictResolution.lastWriteWinsRemote,
        );
        expect(report.processed, 2);
        expect(report.conflicts, 2);
      },
    );
  });
}

class _FakeMileageRepository implements MileageRepository {
  _FakeMileageRepository([List<MileageLog>? initial]) : _logs = [...?initial];

  final List<MileageLog> _logs;
  Exception? addError;

  @override
  Future<void> addLog(MileageLog log) async {
    if (addError != null) {
      throw addError!;
    }
    _logs.add(log);
  }

  @override
  Future<void> deleteLog(String logId) async {
    _logs.removeWhere((log) => log.id == logId);
  }

  @override
  Future<List<MileageLog>> fetchLogs({required String userId}) async {
    return _logs.where((log) => log.userId == userId).toList(growable: false);
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

class _FakeSyncOutboxRepository implements SyncOutboxRepository {
  _FakeSyncOutboxRepository({List<SyncOutboxEvent>? ready}) : _ready = [...?ready];

  final List<SyncOutboxEvent> _ready;
  final List<SyncOutboxEvent> enqueued = [];
  final List<String> syncedEventIds = [];
  final List<_FailedCall> failedCalls = [];
  final List<_ConflictCall> conflicts = [];

  @override
  Future<void> enqueue(SyncOutboxEvent event) async {
    enqueued.add(event);
  }

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
    return _ready.take(limit).toList(growable: false);
  }
}

class _FakeSyncRemoteClient implements SyncRemoteClient {
  _FakeSyncRemoteClient({Map<String, Exception>? errorByEventId})
      : _errorByEventId = errorByEventId ?? {};

  final Map<String, Exception> _errorByEventId;
  final List<String> appliedEventIds = [];
  final List<String> resolvePreferLocalCalls = [];

  @override
  Future<void> apply(SyncOutboxEvent event) async {
    appliedEventIds.add(event.id);
    final error = _errorByEventId[event.id];
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> resolveConflictPreferLocal(SyncOutboxEvent event) async {
    resolvePreferLocalCalls.add(event.id);
  }
}
