import 'package:mi_changan/features/tracker/domain/gps_point.dart';

enum TrackingSessionStatus { idle, tracking, stopped, restored, error }

enum TrackingPermissionStatus {
  unknown,
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class TrackingSessionState {
  const TrackingSessionState._({
    required this.status,
    this.tripId,
    this.startedAt,
    this.points = const [],
    this.permissionStatus = TrackingPermissionStatus.unknown,
    this.permissionDenied = false,
    this.permissionDeniedForever = false,
  });

  const TrackingSessionState.idle()
      : this._(
          status: TrackingSessionStatus.idle,
        );

  factory TrackingSessionState.stopped({
    required String tripId,
    required DateTime startedAt,
    required List<GpsPoint> points,
  }) {
    return TrackingSessionState._(
      status: TrackingSessionStatus.stopped,
      tripId: tripId,
      startedAt: startedAt,
      points: List<GpsPoint>.unmodifiable(points),
    );
  }

  factory TrackingSessionState.tracking({
    required String tripId,
    required DateTime startedAt,
    required List<GpsPoint> points,
  }) {
    return TrackingSessionState._(
      status: TrackingSessionStatus.tracking,
      tripId: tripId,
      startedAt: startedAt,
      points: List<GpsPoint>.unmodifiable(points),
    );
  }

  final TrackingSessionStatus status;
  final String? tripId;
  final DateTime? startedAt;
  final List<GpsPoint> points;
  final TrackingPermissionStatus permissionStatus;
  final bool permissionDenied;
  final bool permissionDeniedForever;

  bool get requiresSettingsRedirect =>
      permissionStatus == TrackingPermissionStatus.deniedForever ||
      permissionStatus == TrackingPermissionStatus.serviceDisabled;

  TrackingSessionState withPermissionStatus(
    TrackingPermissionStatus nextStatus,
  ) {
    return TrackingSessionState._(
      status: status,
      tripId: tripId,
      startedAt: startedAt,
      points: points,
      permissionStatus: nextStatus,
      permissionDenied: nextStatus == TrackingPermissionStatus.denied,
      permissionDeniedForever:
          nextStatus == TrackingPermissionStatus.deniedForever,
    );
  }
}
