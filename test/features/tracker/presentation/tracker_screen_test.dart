import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mi_changan/core/providers/current_user_provider.dart';
import 'package:mi_changan/features/tracker/data/device_location_service.dart';
import 'package:mi_changan/features/tracker/data/device_location_service_provider.dart';
import 'package:mi_changan/features/tracker/domain/gps_point.dart';
import 'package:mi_changan/features/tracker/domain/tracking_session_repository.dart';
import 'package:mi_changan/features/tracker/domain/tracking_session_repository_provider.dart';
import 'package:mi_changan/features/tracker/domain/tracking_session_state.dart';
import 'package:mi_changan/features/tracker/presentation/tracker_screen.dart';

void main() {
  group('TrackerScreen lifecycle intents + live map', () {
    testWidgets('start intent consumes location stream and updates map marker/polyline',
        (tester) async {
      final gateway = _FakeLocationGateway(
        serviceEnabled: true,
        currentPermission: DeviceLocationPermission.whileInUse,
      );
      addTearDown(gateway.dispose);
      final locationService = DeviceLocationService(gateway: gateway);
      final repository = _FakeTrackingSessionRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((_) => 'user-1'),
            trackingSessionRepositoryProvider.overrideWith((_) => repository),
            deviceLocationServiceProvider.overrideWith((_) => locationService),
          ],
          child: const MaterialApp(home: TrackerScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('tracker_start_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('tracker_stop_button')), findsOneWidget);

      gateway.emit(GpsPoint(
        lat: 10.48,
        lng: -66.90,
        recordedAt: DateTime.utc(2026, 4, 10, 10, 0, 1),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.byType(FlutterMap), findsOneWidget);
      final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(markerLayer.markers, hasLength(1));

      gateway.emit(GpsPoint(
        lat: 10.49,
        lng: -66.91,
        recordedAt: DateTime.utc(2026, 4, 10, 10, 0, 9),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      final polylineLayer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
      expect(polylineLayer.polylines, hasLength(1));
      expect(polylineLayer.polylines.first.points, hasLength(2));
      expect(polylineLayer.polylines.first.points.first, const LatLng(10.48, -66.90));
    });

    testWidgets('start intent persists active session and switches to stop CTA',
        (tester) async {
      final gateway = _FakeLocationGateway(
        serviceEnabled: true,
        currentPermission: DeviceLocationPermission.whileInUse,
      );
      addTearDown(gateway.dispose);
      final locationService = DeviceLocationService(gateway: gateway);
      final repository = _FakeTrackingSessionRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((_) => 'user-start'),
            trackingSessionRepositoryProvider.overrideWith((_) => repository),
            deviceLocationServiceProvider.overrideWith((_) => locationService),
          ],
          child: const MaterialApp(home: TrackerScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('tracker_start_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repository.startCalls, 1);
      expect(find.byKey(const Key('tracker_stop_button')), findsOneWidget);
    });

    testWidgets('denied permission keeps idle and shows message', (tester) async {
      final gateway = _FakeLocationGateway(
        serviceEnabled: true,
        currentPermission: DeviceLocationPermission.denied,
        requestPermissionResult: DeviceLocationPermission.denied,
      );
      addTearDown(gateway.dispose);
      final locationService = DeviceLocationService(gateway: gateway);
      final repository = _FakeTrackingSessionRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((_) => 'user-1'),
            trackingSessionRepositoryProvider.overrideWith((_) => repository),
            deviceLocationServiceProvider.overrideWith((_) => locationService),
          ],
          child: const MaterialApp(home: TrackerScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('tracker_start_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Permiso de ubicación denegado.'), findsOneWidget);
      expect(repository.startCalls, 0);
      expect(find.text('Detenido'), findsOneWidget);
    });
  });
}

class _FakeTrackingSessionRepository implements TrackingSessionRepository {
  _Draft? _draft;
  int _seed = 0;

  int startCalls = 0;
  int stopCalls = 0;
  String? lastStopUserId;
  final Completer<void> stopCalled = Completer<void>();

  @override
  Future<void> start(DateTime startedAt) async {
    startCalls++;
    _seed += 1;
    _draft = _Draft(
      tripId: 'trip-$_seed',
      startedAt: startedAt,
      updatedAt: startedAt,
      points: const [],
    );
  }

  @override
  Future<void> append(GpsPoint point) async {
    final active = _draft;
    if (active == null) return;
    _draft = _Draft(
      tripId: active.tripId,
      startedAt: active.startedAt,
      updatedAt: point.recordedAt,
      points: [...active.points, point],
    );
  }

  @override
  Future<TrackingSessionState> restoreIfFresh(Duration maxAge) async {
    final active = _draft;
    if (active == null) return const TrackingSessionState.idle();
    return TrackingSessionState.tracking(
      tripId: active.tripId,
      startedAt: active.startedAt,
      points: active.points,
    );
  }

  @override
  Future<StoppedTrip?> stop({required String userId}) async {
    stopCalls++;
    lastStopUserId = userId;
    if (!stopCalled.isCompleted) {
      stopCalled.complete();
    }
    final active = _draft;
    _draft = null;
    if (active == null) return null;

    return StoppedTrip(
      tripId: active.tripId,
      userId: userId,
      distanceKm: 1.2,
      duration: const Duration(minutes: 8),
      pointsCount: active.points.length,
      startedAt: active.startedAt,
      stoppedAt: active.updatedAt,
    );
  }
}

class _Draft {
  const _Draft({
    required this.tripId,
    required this.startedAt,
    required this.updatedAt,
    required this.points,
  });

  final String tripId;
  final DateTime startedAt;
  final DateTime updatedAt;
  final List<GpsPoint> points;
}

class _FakeLocationGateway implements DeviceLocationGateway {
  _FakeLocationGateway({
    required this.serviceEnabled,
    required this.currentPermission,
    DeviceLocationPermission? requestPermissionResult,
  }) : _requestPermissionResult = requestPermissionResult ?? currentPermission;

  final bool serviceEnabled;
  final DeviceLocationPermission currentPermission;
  final DeviceLocationPermission _requestPermissionResult;
  final _controller = StreamController<GpsPoint>.broadcast();

  void dispose() {
    _controller.close();
  }

  void emit(GpsPoint point) {
    _controller.add(point);
  }

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<DeviceLocationPermission> checkPermission() async => currentPermission;

  @override
  Future<DeviceLocationPermission> requestPermission() async =>
      _requestPermissionResult;

  @override
  Stream<GpsPoint> positionStream() => _controller.stream;
}
