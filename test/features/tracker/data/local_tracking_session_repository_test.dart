import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/tracker/data/local_tracking_session_repository.dart';
import 'package:mi_changan/features/tracker/domain/gps_point.dart';
import 'package:mi_changan/features/tracker/domain/tracking_session_state.dart';

void main() {
  group('LocalTrackingSessionRepository lifecycle', () {
    test('start + append + restoreIfFresh keeps same trip id and points', () async {
      final repo = LocalTrackingSessionRepository();
      final startedAt = DateTime.now().toUtc();

      await repo.start(startedAt);
      await repo.append(
        GpsPoint(
          lat: 10.48,
          lng: -66.90,
          recordedAt: startedAt.add(const Duration(seconds: 5)),
        ),
      );
      await repo.append(
        GpsPoint(
          lat: 10.49,
          lng: -66.91,
          recordedAt: startedAt.add(const Duration(seconds: 15)),
        ),
      );

      final restored = await repo.restoreIfFresh(const Duration(hours: 2));

      expect(restored.status, TrackingSessionStatus.tracking);
      expect(restored.tripId, startsWith('trip-'));
      expect(restored.startedAt, startedAt);
      expect(restored.points, hasLength(2));
    });

    test('calling start twice without stop keeps the same trip id (resume behavior)', () async {
      final repo = LocalTrackingSessionRepository();
      final startedAt = DateTime.now().toUtc();
      await repo.start(startedAt);

      final first = await repo.restoreIfFresh(const Duration(hours: 2));
      await repo.start(startedAt.add(const Duration(minutes: 30)));
      final second = await repo.restoreIfFresh(const Duration(hours: 2));

      expect(first.tripId, isNotNull);
      expect(second.tripId, first.tripId);
      expect(second.startedAt, first.startedAt);
    });

    test('restoreIfFresh returns idle when draft age is older than maxAge', () async {
      final repo = LocalTrackingSessionRepository();
      await repo.start(DateTime.utc(2026, 4, 10, 8));

      final restored = await repo.restoreIfFresh(
        const Duration(hours: 2),
        now: DateTime.utc(2026, 4, 10, 12, 30),
      );

      expect(restored.status, TrackingSessionStatus.idle);
      expect(restored.tripId, isNull);
      expect(restored.points, isEmpty);
    });

    test('stop returns immutable summary and clears active draft', () async {
      final repo = LocalTrackingSessionRepository();
      final startedAt = DateTime.utc(2026, 4, 10, 10);

      await repo.start(startedAt);
      await repo.append(
        GpsPoint(lat: 10.48, lng: -66.90, recordedAt: DateTime.utc(2026, 4, 10, 10, 0, 2)),
      );
      await repo.append(
        GpsPoint(lat: 10.51, lng: -66.90, recordedAt: DateTime.utc(2026, 4, 10, 10, 12)),
      );

      final stopped = await repo.stop(
        userId: 'u1',
        now: DateTime.utc(2026, 4, 10, 10, 12),
      );

      expect(stopped, isNotNull);
      expect(stopped!.tripId, startsWith('trip-'));
      expect(stopped.userId, 'u1');
      expect(stopped.pointsCount, 2);
      expect(stopped.startedAt, startedAt);
      expect(stopped.duration, const Duration(minutes: 12));
      expect(stopped.distanceKm, greaterThan(0));

      final restoredAfterStop = await repo.restoreIfFresh(const Duration(hours: 2));
      expect(restoredAfterStop.status, TrackingSessionStatus.idle);
      expect(restoredAfterStop.points, isEmpty);

      final secondStop = await repo.stop(
        userId: 'u1',
        now: DateTime.utc(2026, 4, 10, 10, 20),
      );
      expect(secondStop, isNull);
    });

    test('restoreIfFresh can recover completed summary within maxAge window', () async {
      final repo = LocalTrackingSessionRepository();
      final startedAt = DateTime.utc(2026, 4, 10, 10);

      await repo.start(startedAt);
      await repo.append(
        GpsPoint(lat: 10.48, lng: -66.90, recordedAt: DateTime.utc(2026, 4, 10, 10, 0, 2)),
      );
      await repo.append(
        GpsPoint(lat: 10.51, lng: -66.90, recordedAt: DateTime.utc(2026, 4, 10, 10, 12)),
      );

      final stopped = await repo.stop(
        userId: 'u1',
        now: DateTime.utc(2026, 4, 10, 10, 12),
      );
      final restored = await repo.restoreIfFresh(
        const Duration(hours: 2),
        now: DateTime.utc(2026, 4, 10, 11, 0),
      );

      expect(stopped, isNotNull);
      expect(restored.status, TrackingSessionStatus.stopped);
      expect(restored.tripId, stopped!.tripId);
      expect(restored.points, hasLength(2));
    });

    test('restoreIfFresh does not recover completed summary beyond maxAge window', () async {
      final repo = LocalTrackingSessionRepository();
      final startedAt = DateTime.utc(2026, 4, 10, 10);

      await repo.start(startedAt);
      await repo.append(
        GpsPoint(lat: 10.48, lng: -66.90, recordedAt: DateTime.utc(2026, 4, 10, 10, 0, 2)),
      );
      await repo.append(
        GpsPoint(lat: 10.51, lng: -66.90, recordedAt: DateTime.utc(2026, 4, 10, 10, 12)),
      );

      await repo.stop(
        userId: 'u1',
        now: DateTime.utc(2026, 4, 10, 10, 12),
      );

      final restored = await repo.restoreIfFresh(
        const Duration(hours: 2),
        now: DateTime.utc(2026, 4, 10, 12, 30),
      );

      expect(restored.status, TrackingSessionStatus.idle);
      expect(restored.tripId, isNull);
      expect(restored.points, isEmpty);
    });
  });
}
