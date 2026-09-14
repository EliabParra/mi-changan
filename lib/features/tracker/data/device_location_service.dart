import 'package:mi_changan/features/tracker/domain/gps_point.dart';

enum DeviceLocationPermission { denied, deniedForever, whileInUse }

enum LocationAccessStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class LocationAccessResult {
  const LocationAccessResult._({
    required this.status,
    required this.shouldOpenSettings,
  });

  const LocationAccessResult.granted()
      : this._(
          status: LocationAccessStatus.granted,
          shouldOpenSettings: false,
        );

  const LocationAccessResult.denied()
      : this._(
          status: LocationAccessStatus.denied,
          shouldOpenSettings: false,
        );

  const LocationAccessResult.deniedForever()
      : this._(
          status: LocationAccessStatus.deniedForever,
          shouldOpenSettings: true,
        );

  const LocationAccessResult.serviceDisabled()
      : this._(
          status: LocationAccessStatus.serviceDisabled,
          shouldOpenSettings: true,
        );

  final LocationAccessStatus status;
  final bool shouldOpenSettings;
}

abstract class DeviceLocationGateway {
  Future<bool> isServiceEnabled();
  Future<DeviceLocationPermission> checkPermission();
  Future<DeviceLocationPermission> requestPermission();
  Stream<GpsPoint> positionStream();
}

class DeviceLocationService {
  const DeviceLocationService({required DeviceLocationGateway gateway})
      : _gateway = gateway;

  final DeviceLocationGateway _gateway;

  DeviceLocationGateway get gateway => _gateway;

  Future<LocationAccessResult> ensureForegroundPermission() async {
    final serviceEnabled = await _gateway.isServiceEnabled();
    if (!serviceEnabled) return const LocationAccessResult.serviceDisabled();

    var permission = await _gateway.checkPermission();
    if (permission == DeviceLocationPermission.denied) {
      permission = await _gateway.requestPermission();
    }

    return switch (permission) {
      DeviceLocationPermission.whileInUse => const LocationAccessResult.granted(),
      DeviceLocationPermission.deniedForever =>
        const LocationAccessResult.deniedForever(),
      DeviceLocationPermission.denied => const LocationAccessResult.denied(),
    };
  }

  Stream<GpsPoint> positions() => _gateway.positionStream();
}
