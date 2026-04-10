// tracker_notifier_test.dart
//
// TDD — Task 3.2 RED (Notifier)
// Unit tests for TrackerNotifier state machine.
//
// Spec scenarios:
//   - Initial state is TrackerStatus.idle
//   - startTracking() transitions to TrackerStatus.tracking
//   - stopTracking() on empty route returns idle and no log
//   - stopTracking() on non-empty route converts to MileageLog and returns it
//   - addPoint() while tracking appends the point to the route
//   - addPoint() while idle is ignored (no state change)
//   - stopTracking() resets route to empty and status to idle

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/tracker/domain/gps_point.dart';
import 'package:mi_changan/features/tracker/domain/tracker_notifier_provider.dart';
import 'package:mi_changan/features/tracker/domain/tracker_state.dart';

void main() {
  // ── Container helper ───────────────────────────────────────────────────

  ProviderContainer makeContainer() {
    return ProviderContainer();
  }

  // ── GpsPoint helpers ──────────────────────────────────────────────────

  GpsPoint makePoint({double lat = 10.48, double lng = -66.90}) => GpsPoint(
        lat: lat,
        lng: lng,
        recordedAt: DateTime.now(),
      );

  // ── Tests ──────────────────────────────────────────────────────────────

  group('TrackerNotifier', () {
    test('initial state is idle with empty route', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final state = container.read(trackerNotifierProvider);

      expect(state.status, TrackerStatus.idle);
      expect(state.route, isEmpty);
    });

    test('startTracking() transitions status to tracking', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container.read(trackerNotifierProvider.notifier).startTracking();
      final state = container.read(trackerNotifierProvider);

      expect(state.status, TrackerStatus.tracking);
    });

    test('addPoint() while tracking appends point to route', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(trackerNotifierProvider.notifier);
      notifier.startTracking();
      notifier.addPoint(makePoint(lat: 10.48, lng: -66.90));

      final state = container.read(trackerNotifierProvider);

      expect(state.route, hasLength(1));
      expect(state.route.first.lat, 10.48);
    });

    test('addPoint() while idle is ignored', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container
          .read(trackerNotifierProvider.notifier)
          .addPoint(makePoint());

      final state = container.read(trackerNotifierProvider);

      expect(state.route, isEmpty);
      expect(state.status, TrackerStatus.idle);
    });

    test('stopTracking() with <2 points returns null and resets to idle', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(trackerNotifierProvider.notifier);
      notifier.startTracking();
      notifier.addPoint(makePoint());
      final log = notifier.stopTracking(
        userId: 'u1',
        logId: 'log-1',
      );

      final state = container.read(trackerNotifierProvider);

      expect(log, isNull);
      expect(state.status, TrackerStatus.idle);
      expect(state.route, isEmpty);
    });

    test('stopTracking() with >=2 points returns a MileageLog and resets', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(trackerNotifierProvider.notifier);
      notifier.startTracking();
      notifier.addPoint(GpsPoint(
        lat: 10.480,
        lng: -66.900,
        recordedAt: DateTime(2026, 4, 1, 10),
      ));
      notifier.addPoint(GpsPoint(
        lat: 10.490,
        lng: -66.900,
        recordedAt: DateTime(2026, 4, 1, 10, 10),
      ));

      final log = notifier.stopTracking(
        userId: 'u1',
        logId: 'log-2',
      );

      final state = container.read(trackerNotifierProvider);

      expect(log, isNotNull);
      expect(log!.userId, 'u1');
      expect(log.id, 'log-2');
      expect(log.valueKm, greaterThan(0));
      expect(state.status, TrackerStatus.idle);
      expect(state.route, isEmpty);
    });

    test('stopTracking() resets route to empty', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(trackerNotifierProvider.notifier);
      notifier.startTracking();
      notifier.addPoint(makePoint(lat: 10.48));
      notifier.addPoint(makePoint(lat: 10.49));
      notifier.stopTracking(userId: 'u1', logId: 'log-3');

      final state = container.read(trackerNotifierProvider);

      expect(state.route, isEmpty);
    });
  });
}
