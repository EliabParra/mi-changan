import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/tracker/data/device_location_service.dart';
import 'package:mi_changan/features/tracker/domain/gps_point.dart';

void main() {
  group('DeviceLocationService.ensureForegroundPermission', () {
    test('returns serviceDisabled + settings required when GPS is off', () async {
      final gateway = _FakeLocationGateway(
        serviceEnabled: false,
        currentPermission: DeviceLocationPermission.denied,
      );
      final service = DeviceLocationService(gateway: gateway);

      final result = await service.ensureForegroundPermission();

      expect(result.status, LocationAccessStatus.serviceDisabled);
      expect(result.shouldOpenSettings, isTrue);
      expect(gateway.requestPermissionCalls, 0);
    });

    test('returns denied when user denies on request', () async {
      final gateway = _FakeLocationGateway(
        serviceEnabled: true,
        currentPermission: DeviceLocationPermission.denied,
        requestPermissionResult: DeviceLocationPermission.denied,
      );
      final service = DeviceLocationService(gateway: gateway);

      final result = await service.ensureForegroundPermission();

      expect(result.status, LocationAccessStatus.denied);
      expect(result.shouldOpenSettings, isFalse);
      expect(gateway.requestPermissionCalls, 1);
    });

    test('returns deniedForever + settings required when permission is permanent denial', () async {
      final gateway = _FakeLocationGateway(
        serviceEnabled: true,
        currentPermission: DeviceLocationPermission.denied,
        requestPermissionResult: DeviceLocationPermission.deniedForever,
      );
      final service = DeviceLocationService(gateway: gateway);

      final result = await service.ensureForegroundPermission();

      expect(result.status, LocationAccessStatus.deniedForever);
      expect(result.shouldOpenSettings, isTrue);
    });

    test('returns granted when while-in-use permission is available', () async {
      final gateway = _FakeLocationGateway(
        serviceEnabled: true,
        currentPermission: DeviceLocationPermission.whileInUse,
      );
      final service = DeviceLocationService(gateway: gateway);

      final result = await service.ensureForegroundPermission();

      expect(result.status, LocationAccessStatus.granted);
      expect(result.shouldOpenSettings, isFalse);
      expect(gateway.requestPermissionCalls, 0);
    });
  });

  group('DeviceLocationService.positions', () {
    test('forwards gateway stream points as-is', () async {
      final points = [
        GpsPoint(lat: 10.48, lng: -66.90, recordedAt: DateTime.utc(2026, 4, 10, 10)),
        GpsPoint(lat: 10.49, lng: -66.91, recordedAt: DateTime.utc(2026, 4, 10, 10, 0, 8)),
      ];

      final gateway = _FakeLocationGateway(
        serviceEnabled: true,
        currentPermission: DeviceLocationPermission.whileInUse,
        streamPoints: points,
      );
      final service = DeviceLocationService(gateway: gateway);

      final emitted = await service.positions().toList();

      expect(emitted, points);
    });
  });
}

class _FakeLocationGateway implements DeviceLocationGateway {
  _FakeLocationGateway({
    required this.serviceEnabled,
    required this.currentPermission,
    DeviceLocationPermission? requestPermissionResult,
    List<GpsPoint>? streamPoints,
  })  : _requestPermissionResult = requestPermissionResult ?? currentPermission,
        _streamPoints = streamPoints ?? const [];

  final bool serviceEnabled;
  final DeviceLocationPermission currentPermission;
  final DeviceLocationPermission _requestPermissionResult;
  final List<GpsPoint> _streamPoints;

  int requestPermissionCalls = 0;

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<DeviceLocationPermission> checkPermission() async => currentPermission;

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    requestPermissionCalls++;
    return _requestPermissionResult;
  }

  @override
  Stream<GpsPoint> positionStream() => Stream<GpsPoint>.fromIterable(_streamPoints);
}
