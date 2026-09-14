import 'package:mi_changan/features/tracker/domain/gps_log_converter.dart';
import 'package:mi_changan/features/tracker/domain/gps_point.dart';
import 'package:mi_changan/features/tracker/domain/tracking_session_repository.dart';
import 'package:mi_changan/features/tracker/domain/tracking_session_state.dart';

class LocalTrackingSessionRepository implements TrackingSessionRepository {
  _TrackingDraft? _draft;
  _CompletedTripSnapshot? _completed;
  int _seed = 0;

  @override
  Future<void> start(DateTime startedAt) async {
    final activeDraft = _draft;
    if (activeDraft != null) {
      return;
    }

    _seed += 1;
    _draft = _TrackingDraft(
      tripId: 'trip-$_seed',
      startedAt: startedAt,
      updatedAt: startedAt,
      points: const [],
    );
  }

  @override
  Future<void> append(GpsPoint point) async {
    final activeDraft = _draft;
    if (activeDraft == null) return;

    _draft = activeDraft.copyWith(
      points: [...activeDraft.points, point],
      updatedAt: point.recordedAt,
    );
  }

  @override
  Future<TrackingSessionState> restoreIfFresh(
    Duration maxAge, {
    DateTime? now,
  }) async {
    final instant = now ?? DateTime.now().toUtc();

    final completed = _completed;
    if (completed != null) {
      final completedElapsed = instant.difference(completed.stoppedAt);
      if (completedElapsed <= maxAge) {
        return TrackingSessionState.stopped(
          tripId: completed.tripId,
          startedAt: completed.startedAt,
          points: completed.points,
        );
      }

      _completed = null;
    }

    final activeDraft = _draft;
    if (activeDraft == null) return const TrackingSessionState.idle();

    final elapsed = instant.difference(activeDraft.updatedAt);
    if (elapsed > maxAge) {
      return const TrackingSessionState.idle();
    }

    return TrackingSessionState.tracking(
      tripId: activeDraft.tripId,
      startedAt: activeDraft.startedAt,
      points: activeDraft.points,
    );
  }

  @override
  Future<StoppedTrip?> stop({
    required String userId,
    DateTime? now,
  }) async {
    final activeDraft = _draft;
    if (activeDraft == null) return null;

    final stoppedAt = now ?? DateTime.now().toUtc();
    final log = GpsLogConverter.convert(
      route: activeDraft.points,
      userId: userId,
      logId: activeDraft.tripId,
      endedAt: stoppedAt,
    );
    if (log == null) {
      _draft = null;
      return null;
    }

    final summary = StoppedTrip(
      tripId: activeDraft.tripId,
      userId: userId,
      distanceKm: log.valueKm,
      duration: stoppedAt.difference(activeDraft.startedAt),
      pointsCount: activeDraft.points.length,
      startedAt: activeDraft.startedAt,
      stoppedAt: stoppedAt,
    );

    _completed = _CompletedTripSnapshot(
      tripId: activeDraft.tripId,
      startedAt: activeDraft.startedAt,
      stoppedAt: stoppedAt,
      points: activeDraft.points,
    );
    _draft = null;
    return summary;
  }
}

class _TrackingDraft {
  const _TrackingDraft({
    required this.tripId,
    required this.startedAt,
    required this.updatedAt,
    required this.points,
  });

  final String tripId;
  final DateTime startedAt;
  final DateTime updatedAt;
  final List<GpsPoint> points;

  _TrackingDraft copyWith({
    DateTime? updatedAt,
    List<GpsPoint>? points,
  }) {
    return _TrackingDraft(
      tripId: tripId,
      startedAt: startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      points: points ?? this.points,
    );
  }
}

class _CompletedTripSnapshot {
  const _CompletedTripSnapshot({
    required this.tripId,
    required this.startedAt,
    required this.stoppedAt,
    required this.points,
  });

  final String tripId;
  final DateTime startedAt;
  final DateTime stoppedAt;
  final List<GpsPoint> points;
}
