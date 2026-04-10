import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';
import 'package:mi_changan/features/projections/domain/projection_maintenance_composer.dart';
import 'package:mi_changan/features/projections/domain/projection_point.dart';

void main() {
  group('ProjectionMaintenanceComposer', () {
    test('marks due reminders as due overlays', () {
      final points = [
        ProjectionPoint(month: DateTime(2026, 5), estimatedKm: 12000),
      ];
      final reminders = [
        MaintenanceReminder(
          id: 'r1',
          userId: 'u1',
          label: 'Aceite',
          intervalKm: 5000,
          lastServiceKm: 7000,
          lastServiceDate: DateTime.utc(2026, 1, 1),
          currentKm: 12000,
        ),
      ];

      final model = ProjectionMaintenanceComposer.compose(
        points: points,
        reminders: reminders,
        now: DateTime.utc(2026, 4, 10),
      );

      expect(model.maintenanceMarkers, hasLength(1));
      expect(model.maintenanceMarkers.first.status, MaintenanceMarkerStatus.due);
    });

    test('marks near due reminders for <=500km threshold', () {
      final reminders = [
        MaintenanceReminder(
          id: 'r-near',
          userId: 'u1',
          label: 'Filtro',
          intervalKm: 5000,
          lastServiceKm: 10000,
          lastServiceDate: DateTime.utc(2026, 1, 1),
          currentKm: 14550,
        ),
      ];

      final model = ProjectionMaintenanceComposer.compose(
        points: const [],
        reminders: reminders,
        now: DateTime.utc(2026, 4, 10),
      );

      expect(
        model.maintenanceMarkers.first.status,
        MaintenanceMarkerStatus.nearDue,
      );
    });

    test('marks upcoming reminder as near due when projection reaches target within 30 days', () {
      final now = DateTime.utc(2026, 4, 10);
      final reminders = [
        MaintenanceReminder(
          id: 'r-near-30d',
          userId: 'u1',
          label: 'Correa',
          intervalKm: 5000,
          lastServiceKm: 10000,
          lastServiceDate: DateTime.utc(2026, 1, 1),
          currentKm: 13000,
        ),
      ];

      final model = ProjectionMaintenanceComposer.compose(
        points: [
          ProjectionPoint(month: now.add(const Duration(days: 10)), estimatedKm: 14500),
          ProjectionPoint(month: now.add(const Duration(days: 25)), estimatedKm: 15100),
        ],
        reminders: reminders,
        now: now,
      );

      expect(model.maintenanceMarkers, hasLength(1));
      expect(model.maintenanceMarkers.first.status, MaintenanceMarkerStatus.nearDue);
      expect(model.maintenanceMarkers.first.reminderId, 'r-near-30d');
    });
  });
}
