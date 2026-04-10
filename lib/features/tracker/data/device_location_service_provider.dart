import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_changan/features/tracker/data/device_location_service.dart';
import 'package:mi_changan/features/tracker/data/simulated_location_gateway.dart';

final deviceLocationServiceProvider = Provider<DeviceLocationService>((ref) {
  return DeviceLocationService(
    gateway: SimulatedLocationGateway(),
  );
});
