import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/tracker/data/device_location_service.dart';
import 'package:mi_changan/features/tracker/data/simulated_location_gateway.dart';

void main() {
  group('SimulatedLocationGateway', () {
    test('reports foreground permission as available', () async {
      final gateway = SimulatedLocationGateway();

      final enabled = await gateway.isServiceEnabled();
      final permission = await gateway.checkPermission();
      final requested = await gateway.requestPermission();

      expect(enabled, isTrue);
      expect(permission, DeviceLocationPermission.whileInUse);
      expect(requested, DeviceLocationPermission.whileInUse);
    });

    test('emits deterministic points for live map stream', () async {
      final gateway = SimulatedLocationGateway();

      final first = await gateway.positionStream().first;

      expect(first.lat, closeTo(10.4806, 0.0001));
      expect(first.lng, closeTo(-66.9036, 0.0001));
    });
  });
}
