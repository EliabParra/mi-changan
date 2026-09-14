import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_repository.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/mileage/domain/mileage_repository.dart';
import 'package:mi_changan/features/projections/domain/projection_maintenance_composer.dart';
import 'package:mi_changan/features/projections/domain/projection_provider.dart';

class FakeMileageRepository implements MileageRepository {
  FakeMileageRepository(this._logs);

  final List<MileageLog> _logs;

  @override
  Future<void> addLog(MileageLog log) async {}

  @override
  Future<void> deleteLog(String logId) async {}

  @override
  Future<List<MileageLog>> fetchLogs({required String userId}) async => _logs;
}

class FakeMaintenanceRepository implements MaintenanceRepository {
  FakeMaintenanceRepository(this._reminders);

  final List<MaintenanceReminder> _reminders;

  @override
  Future<void> addReminder(MaintenanceReminder reminder) async {}

  @override
  Future<void> deleteReminder(String reminderId) async {}

  @override
  Future<List<MaintenanceReminder>> fetchReminders({required String userId}) async {
    return _reminders;
  }

  @override
  Future<void> updateReminder(MaintenanceReminder reminder) async {}
}

void main() {
  ProviderContainer makeContainer({
    required List<MileageLog> logs,
    required List<MaintenanceReminder> reminders,
  }) {
    return ProviderContainer(
      overrides: [
        mileageRepositoryProvider.overrideWithValue(FakeMileageRepository(logs)),
        maintenanceRepositoryProvider
            .overrideWithValue(FakeMaintenanceRepository(reminders)),
      ],
    );
  }

  group('projectionsProvider', () {
    test('returns points plus due and near-due maintenance markers', () async {
      final logs = [
        MileageLog(
          id: 'l1',
          userId: 'u1',
          entryType: MileageEntryType.total,
          valueKm: 10000,
          recordedAt: DateTime(2026, 1, 1),
        ),
        MileageLog(
          id: 'l2',
          userId: 'u1',
          entryType: MileageEntryType.total,
          valueKm: 12000,
          recordedAt: DateTime(2026, 3, 1),
        ),
      ];
      final reminders = [
        MaintenanceReminder(
          id: 'r-due',
          userId: 'u1',
          label: 'Aceite',
          intervalKm: 5000,
          lastServiceKm: 7000,
          lastServiceDate: DateTime.utc(2026, 1, 1),
          currentKm: 12000,
        ),
        MaintenanceReminder(
          id: 'r-near',
          userId: 'u1',
          label: 'Filtro',
          intervalKm: 5000,
          lastServiceKm: 7000,
          lastServiceDate: DateTime.utc(2026, 1, 1),
          currentKm: 11600,
        ),
      ];

      final container = makeContainer(logs: logs, reminders: reminders);
      addTearDown(container.dispose);

      final model = await container.read(
        projectionsProvider(
          const ProjectionsParams(userId: 'u1', months: 3),
        ).future,
      );

      expect(model.points, hasLength(3));
      expect(model.maintenanceMarkers, hasLength(2));
      expect(
        model.maintenanceMarkers.map((m) => m.status),
        containsAll([
          MaintenanceMarkerStatus.due,
          MaintenanceMarkerStatus.nearDue,
        ]),
      );
    });

    test('filters out upcoming reminders from projection markers', () async {
      final logs = [
        MileageLog(
          id: 'l1',
          userId: 'u1',
          entryType: MileageEntryType.total,
          valueKm: 10000,
          recordedAt: DateTime(2026, 1, 1),
        ),
        MileageLog(
          id: 'l2',
          userId: 'u1',
          entryType: MileageEntryType.total,
          valueKm: 12000,
          recordedAt: DateTime(2026, 3, 1),
        ),
      ];
      final reminders = [
        MaintenanceReminder(
          id: 'r-upcoming',
          userId: 'u1',
          label: 'Bujías',
          intervalKm: 5000,
          lastServiceKm: 9000,
          lastServiceDate: DateTime.utc(2026, 1, 1),
          currentKm: 12000,
        ),
      ];

      final container = makeContainer(logs: logs, reminders: reminders);
      addTearDown(container.dispose);

      final model = await container.read(
        projectionsProvider(
          const ProjectionsParams(userId: 'u1', months: 1),
        ).future,
      );

      expect(model.points, hasLength(1));
      expect(model.maintenanceMarkers, isEmpty);
    });
  });
}
