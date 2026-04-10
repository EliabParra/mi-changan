// tracker_notifier.dart
//
// Domain-layer Notifier for foreground GPS tracking session.
//
// Design decisions:
//   - Extends Notifier<TrackerState> (synchronous — no async needed for state).
//   - startTracking() transitions idle → tracking.
//   - addPoint() appends to route only when tracking.
//   - stopTracking() converts route via GpsLogConverter, resets to idle,
//     and returns the resulting MileageLog (or null if route too short).
//   - All GPS hardware interaction is in the presentation layer — notifier
//     receives already-captured GpsPoints.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/tracker/domain/gps_log_converter.dart';
import 'package:mi_changan/features/tracker/domain/gps_point.dart';
import 'package:mi_changan/features/tracker/domain/tracker_state.dart';

/// Manages the foreground GPS tracking session state.
class TrackerNotifier extends Notifier<TrackerState> {
  @override
  TrackerState build() => const TrackerState();

  /// Begin a new tracking session (idle → tracking).
  void startTracking() {
    state = state.copyWith(
      status: TrackerStatus.tracking,
      route: [],
    );
  }

  /// Append [point] to the current route.
  ///
  /// No-op when status is [TrackerStatus.idle].
  void addPoint(GpsPoint point) {
    if (state.status != TrackerStatus.tracking) return;
    state = state.copyWith(route: [...state.route, point]);
  }

  /// End the tracking session and convert the route to a [MileageLog].
  ///
  /// Resets state to idle regardless of outcome.
  /// Returns null when the route has fewer than 2 points.
  MileageLog? stopTracking({
    required String userId,
    required String logId,
  }) {
    final route = state.route;
    state = const TrackerState(); // reset to idle

    return GpsLogConverter.convert(
      route: route,
      userId: userId,
      logId: logId,
      endedAt: DateTime.now(),
    );
  }
}
