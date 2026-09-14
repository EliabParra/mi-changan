import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/tracker/data/device_location_service.dart';
import 'package:mi_changan/features/tracker/data/real_device_location_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('mi_changan/location/methods');

  group('RealDeviceLocationGateway', () {
    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
    });

    test('maps whileInUse permission from platform channel', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            switch (call.method) {
              case 'checkPermission':
                return 'whileInUse';
              default:
                return null;
            }
          });

      final gateway = RealDeviceLocationGateway();
      final permission = await gateway.checkPermission();

      expect(permission, DeviceLocationPermission.whileInUse);
    });

    test('maps deniedForever permission from platform channel', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            switch (call.method) {
              case 'requestPermission':
                return 'deniedForever';
              default:
                return null;
            }
          });

      final gateway = RealDeviceLocationGateway();
      final permission = await gateway.requestPermission();

      expect(permission, DeviceLocationPermission.deniedForever);
    });

    test('returns false when service flag is null from channel', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            if (call.method == 'isServiceEnabled') {
              return null;
            }
            return null;
          });

      final gateway = RealDeviceLocationGateway();
      final enabled = await gateway.isServiceEnabled();

      expect(enabled, isFalse);
    });
  });
}
