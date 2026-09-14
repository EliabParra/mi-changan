import 'dart:async';

import 'package:mi_changan/features/tracker/data/device_location_service.dart';
import 'package:mi_changan/features/tracker/domain/gps_point.dart';

class SimulatedLocationGateway implements DeviceLocationGateway {
  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<DeviceLocationPermission> checkPermission() async =>
      DeviceLocationPermission.whileInUse;

  @override
  Future<DeviceLocationPermission> requestPermission() async =>
      DeviceLocationPermission.whileInUse;

  @override
  Stream<GpsPoint> positionStream() async* {
    final startedAt = DateTime.now().toUtc();
    var index = 0;

    while (true) {
      final lat = 10.4806 + (index * 0.0002);
      final lng = -66.9036 - (index * 0.0002);
      yield GpsPoint(
        lat: lat,
        lng: lng,
        recordedAt: startedAt.add(Duration(seconds: index * 5)),
      );
      index += 1;
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }
}
