import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/tracker/domain/gps_point.dart';
import 'package:mi_changan/features/tracker/domain/tracking_session_repository.dart';
import 'package:mi_changan/features/tracker/domain/tracking_session_state.dart';

void main() {
  group('TrackingSessionState', () {
    test('idle() starts with no active trip metadata', () {
      const state = TrackingSessionState.idle();

      expect(state.status, TrackingSessionStatus.idle);
      expect(state.tripId, isNull);
      expect(state.points, isEmpty);
    });

    test('tracking() keeps trip identity and points snapshot', () {
      final points = [
        GpsPoint(lat: 10.48, lng: -66.9, recordedAt: DateTime.utc(2026, 1, 1)),
      ];

      final state = TrackingSessionState.tracking(
        tripId: 'trip-1',
        startedAt: DateTime.utc(2026, 1, 1),
        points: points,
      );

      expect(state.status, TrackingSessionStatus.tracking);
      expect(state.tripId, 'trip-1');
      expect(state.points, hasLength(1));
    });
  });

  group('TrackingSessionRepository contract', () {
    test('restoreIfFresh returns a tracking state snapshot', () async {
      final repo = _FakeTrackingSessionRepository();

      final restored = await repo.restoreIfFresh(const Duration(hours: 2));

      expect(restored.status, TrackingSessionStatus.tracking);
      expect(restored.tripId, 'trip-1');
    });

    test('stop returns immutable stopped summary', () async {
      final repo = _FakeTrackingSessionRepository();

      final stopped = await repo.stop(userId: 'user-1');

      expect(stopped, isNotNull);
      expect(stopped!.tripId, 'trip-1');
      expect(stopped.pointsCount, 2);
      expect(stopped.distanceKm, closeTo(12.4, 0.01));
    });
  });
}

class _FakeTrackingSessionRepository implements TrackingSessionRepository {
  @override
  Future<void> append(GpsPoint point) async {}

  @override
  Future<TrackingSessionState> restoreIfFresh(Duration maxAge) async {
    return TrackingSessionState.tracking(
      tripId: 'trip-1',
      startedAt: DateTime.utc(2026, 1, 1),
      points: const [],
    );
  }

  @override
  Future<void> start(DateTime startedAt) async {}

  @override
  Future<StoppedTrip?> stop({required String userId}) async {
    return StoppedTrip(
      tripId: 'trip-1',
      userId: userId,
      distanceKm: 12.4,
      duration: const Duration(minutes: 22),
      pointsCount: 2,
      startedAt: DateTime.utc(2026, 1, 1),
      stoppedAt: DateTime.utc(2026, 1, 1, 0, 22),
    );
  }
}
