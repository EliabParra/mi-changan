// tracker_state.dart
//
// State model for the foreground GPS tracker.
//
// Design decisions:
//   - Immutable value type — copyWith() returns a new instance.
//   - TrackerStatus is an enum (idle / tracking) — two-state machine.
//   - route is an unmodifiable snapshot — mutations always go through copyWith.

import 'package:mi_changan/features/tracker/domain/gps_point.dart';

/// Whether the tracker is actively collecting GPS points.
enum TrackerStatus {
  /// Not tracking. Waiting for user to press Start.
  idle,

  /// Actively collecting GPS points.
  tracking,
}

/// Immutable state for [TrackerNotifier].
class TrackerState {
  const TrackerState({
    this.status = TrackerStatus.idle,
    this.route = const [],
  });

  /// Current tracker lifecycle status.
  final TrackerStatus status;

  /// Ordered list of GPS points collected in the current session.
  final List<GpsPoint> route;

  TrackerState copyWith({
    TrackerStatus? status,
    List<GpsPoint>? route,
  }) =>
      TrackerState(
        status: status ?? this.status,
        route: route ?? this.route,
      );

  @override
  String toString() =>
      'TrackerState(status: $status, points: ${route.length})';
}
