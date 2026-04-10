import 'package:mi_changan/features/tracker/domain/gps_point.dart';
import 'package:mi_changan/features/tracker/domain/tracking_session_state.dart';

class StoppedTrip {
  const StoppedTrip({
    required this.tripId,
    required this.userId,
    required this.distanceKm,
    required this.duration,
    required this.pointsCount,
    required this.startedAt,
    required this.stoppedAt,
  });

  final String tripId;
  final String userId;
  final double distanceKm;
  final Duration duration;
  final int pointsCount;
  final DateTime startedAt;
  final DateTime stoppedAt;
}

abstract class TrackingSessionRepository {
  Future<TrackingSessionState> restoreIfFresh(Duration maxAge);
  Future<void> start(DateTime startedAt);
  Future<void> append(GpsPoint point);
  Future<StoppedTrip?> stop({required String userId});
}
