import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:mi_changan/core/providers/current_user_provider.dart';
import 'package:mi_changan/features/tracker/data/device_location_service.dart';
import 'package:mi_changan/features/tracker/data/device_location_service_provider.dart';
import 'package:mi_changan/features/tracker/domain/gps_log_converter.dart';
import 'package:mi_changan/features/tracker/domain/gps_point.dart';
import 'package:mi_changan/features/tracker/domain/tracking_session_repository_provider.dart';
import 'package:mi_changan/features/tracker/domain/tracking_session_state.dart';

class TrackerScreen extends ConsumerStatefulWidget {
  const TrackerScreen({super.key});

  @override
  ConsumerState<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends ConsumerState<TrackerScreen> {
  static const _resumeWindow = Duration(hours: 2);
  static const _disableNetworkTiles = bool.fromEnvironment(
    'DISABLE_TRACKER_NETWORK_TILES',
    defaultValue: false,
  );

  StreamSubscription<GpsPoint>? _positionSub;
  TrackingSessionStatus _status = TrackingSessionStatus.idle;
  List<GpsPoint> _points = const [];
  String? _permissionMessage;

  @override
  void initState() {
    super.initState();
    _restoreActiveSession();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _restoreActiveSession() async {
    final repository = ref.read(trackingSessionRepositoryProvider);
    final restored = await repository.restoreIfFresh(_resumeWindow);
    if (!mounted) return;

    if (restored.status == TrackingSessionStatus.tracking) {
      setState(() {
        _status = TrackingSessionStatus.tracking;
        _points = restored.points;
      });
      _startPositionSubscription();
    }
  }

  Future<void> _handleStart() async {
    final locationService = ref.read(deviceLocationServiceProvider);
    final permissionResult = await locationService.ensureForegroundPermission();
    if (!mounted) return;

    if (permissionResult.status != LocationAccessStatus.granted) {
      setState(() {
        _permissionMessage = switch (permissionResult.status) {
          LocationAccessStatus.denied => 'Permiso de ubicación denegado.',
          LocationAccessStatus.deniedForever =>
            'Permiso bloqueado. Abrí Configuración para habilitarlo.',
          LocationAccessStatus.serviceDisabled =>
            'GPS desactivado. Activá el servicio de ubicación.',
          LocationAccessStatus.granted => null,
        };
      });
      return;
    }

    final repository = ref.read(trackingSessionRepositoryProvider);
    await repository.start(DateTime.now().toUtc());
    if (!mounted) return;

    setState(() {
      _status = TrackingSessionStatus.tracking;
      _points = const [];
      _permissionMessage = null;
    });
    _startPositionSubscription();
  }

  Future<void> _handleStop(BuildContext context) async {
    await _positionSub?.cancel();
    _positionSub = null;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sesión no encontrada. Iniciá sesión para guardar el recorrido.',
            ),
          ),
        );
      }
      return;
    }

    final repository = ref.read(trackingSessionRepositoryProvider);
    final summary = await repository.stop(userId: userId);
    if (!mounted) return;

    if (summary == null) {
      setState(() {
        _status = TrackingSessionStatus.idle;
        _points = const [];
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            key: Key('tracker_too_short_snack'),
            content: Text('Recorrido demasiado corto para guardar.'),
          ),
        );
      }
      return;
    }

    setState(() {
      _status = TrackingSessionStatus.stopped;
      _points = const [];
    });

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('tracker_saved_snack'),
        content: Text(
          'Recorrido guardado: ${summary.distanceKm.toStringAsFixed(1)} km',
        ),
      ),
    );
  }

  void _startPositionSubscription() {
    _positionSub?.cancel();
    final locationService = ref.read(deviceLocationServiceProvider);
    final repository = ref.read(trackingSessionRepositoryProvider);
    _positionSub = locationService.positions().listen((point) async {
      await repository.append(point);
      if (!mounted) return;
      setState(() {
        _points = [..._points, point];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTracking = _status == TrackingSessionStatus.tracking;

    double distanceKm = 0;
    if (_points.length >= 2) {
      for (var i = 0; i < _points.length - 1; i++) {
        final a = _points[i];
        final b = _points[i + 1];
        distanceKm += GpsLogConverter.haversineKm(a.lat, a.lng, b.lat, b.lng);
      }
    }

    final markerPoints = _points
        .map((point) => Marker(
              point: LatLng(point.lat, point.lng),
              width: 28,
              height: 28,
              child: const Icon(Icons.location_on, color: Colors.red),
            ))
        .toList(growable: false);

    final polylinePoints = _points
        .map((point) => LatLng(point.lat, point.lng))
        .toList(growable: false);

    final mapCenter = polylinePoints.isNotEmpty
        ? polylinePoints.last
        : const LatLng(10.4806, -66.9036);

    return Scaffold(
      key: const Key('tracker_screen'),
      appBar: AppBar(title: const Text('Tracker GPS')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: mapCenter,
                initialZoom: 14,
              ),
              children: [
                if (!_disableNetworkTiles)
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.michangan.app',
                  ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polylinePoints,
                      strokeWidth: 4,
                      color: Colors.blue,
                    ),
                  ],
                ),
                MarkerLayer(markers: markerPoints),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isTracking ? 'Rastreando…' : 'Detenido',
                  key: const Key('tracker_status_label'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  isTracking
                      ? '${distanceKm.toStringAsFixed(2)} km recorridos'
                      : '${_points.length} puntos registrados',
                  key: const Key('tracker_points_label'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (_permissionMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _permissionMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                        ),
                  ),
                ],
                const SizedBox(height: 16),
                if (!isTracking)
                  FilledButton.icon(
                    key: const Key('tracker_start_button'),
                    onPressed: _handleStart,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Iniciar'),
                  )
                else
                  FilledButton.icon(
                    key: const Key('tracker_stop_button'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => _handleStop(context),
                    icon: const Icon(Icons.stop),
                    label: const Text('Detener y guardar'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
