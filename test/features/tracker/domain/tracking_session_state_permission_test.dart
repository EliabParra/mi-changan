import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/tracker/domain/tracking_session_state.dart';

void main() {
  group('TrackingSessionState permission transitions', () {
    test('marks denied and keeps settings CTA disabled', () {
      const state = TrackingSessionState.idle();

      final next = state.withPermissionStatus(TrackingPermissionStatus.denied);

      expect(next.permissionStatus, TrackingPermissionStatus.denied);
      expect(next.permissionDenied, isTrue);
      expect(next.permissionDeniedForever, isFalse);
      expect(next.requiresSettingsRedirect, isFalse);
    });

    test('marks deniedForever and requires settings redirect', () {
      const state = TrackingSessionState.idle();

      final next = state.withPermissionStatus(
        TrackingPermissionStatus.deniedForever,
      );

      expect(next.permissionStatus, TrackingPermissionStatus.deniedForever);
      expect(next.permissionDenied, isFalse);
      expect(next.permissionDeniedForever, isTrue);
      expect(next.requiresSettingsRedirect, isTrue);
    });

    test('serviceDisabled also requires settings redirect', () {
      const state = TrackingSessionState.idle();

      final next = state.withPermissionStatus(
        TrackingPermissionStatus.serviceDisabled,
      );

      expect(next.permissionStatus, TrackingPermissionStatus.serviceDisabled);
      expect(next.requiresSettingsRedirect, isTrue);
    });
  });
}
