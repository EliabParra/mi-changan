import 'package:flutter/services.dart';
import 'package:mi_changan/features/tracker/data/device_location_service.dart';
import 'package:mi_changan/features/tracker/domain/gps_point.dart';

class RealDeviceLocationGateway implements DeviceLocationGateway {
  static const MethodChannel _methodChannel =
      MethodChannel('mi_changan/location/methods');
  static const EventChannel _eventChannel =
      EventChannel('mi_changan/location/stream');

  @override
  Future<bool> isServiceEnabled() async {
    final enabled = await _methodChannel.invokeMethod<bool>('isServiceEnabled');
    return enabled ?? false;
  }

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    final value = await _methodChannel.invokeMethod<String>('checkPermission');
    return _permissionFromChannel(value);
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    final value =
        await _methodChannel.invokeMethod<String>('requestPermission');
    return _permissionFromChannel(value);
  }

  @override
  Stream<GpsPoint> positionStream() {
    return _eventChannel.receiveBroadcastStream().map((event) {
      final map = Map<Object?, Object?>.from(event as Map);
      final lat = (map['lat'] as num).toDouble();
      final lng = (map['lng'] as num).toDouble();
      final recordedAtRaw = map['recorded_at'] as String;

      return GpsPoint(
        lat: lat,
        lng: lng,
        recordedAt: DateTime.parse(recordedAtRaw).toUtc(),
      );
    });
  }
}

DeviceLocationPermission _permissionFromChannel(String? value) {
  return switch (value) {
    'whileInUse' => DeviceLocationPermission.whileInUse,
    'deniedForever' => DeviceLocationPermission.deniedForever,
    _ => DeviceLocationPermission.denied,
  };
}
