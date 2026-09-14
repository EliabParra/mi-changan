// service_notifier_test.dart
//
// TDD — Task 2.2 RED (Notifier)
// Unit tests for ServiceNotifier (CRUD + state + reminder baseline reset).
//
// Tests cover:
//   - build() loads service records from repository.
//   - addRecord() persists and refreshes state.
//   - addRecord() also calls updateReminder on MaintenanceRepository
//     with new baseline (linking service ↔ reminder).
//   - deleteRecord() removes record from state.
//   - addRecord() sets AsyncError on repository failure.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_repository.dart';
import 'package:mi_changan/features/services/domain/service_notifier_provider.dart';
import 'package:mi_changan/features/services/domain/service_record.dart';
import 'package:mi_changan/features/services/domain/service_repository.dart';

// ── Fake repositories ──────────────────────────────────────────────────────

class FakeServiceRepository implements ServiceRepository {
  FakeServiceRepository([List<ServiceRecord>? initial])
      : _stored = List.from(initial ?? []);

  final List<ServiceRecord> _stored;
  Exception? addError;

  @override
  Future<List<ServiceRecord>> fetchRecords({required String userId}) async =>
      List.unmodifiable(_stored);

  @override
  Future<void> addRecord(ServiceRecord record) async {
    if (addError != null) throw addError!;
    _stored.add(record);
  }

  @override
  Future<void> deleteRecord(String recordId) async {
    _stored.removeWhere((r) => r.id == recordId);
  }
}

class FakeMaintenanceRepository implements MaintenanceRepository {
  FakeMaintenanceRepository([List<MaintenanceReminder>? initial])
      : _reminders = List.from(initial ?? []);

  final List<MaintenanceReminder> _reminders;
  MaintenanceReminder? lastUpdated;

  @override
  Future<List<MaintenanceReminder>> fetchReminders(
          {required String userId}) async =>
      List.unmodifiable(_reminders);

  @override
  Future<void> addReminder(MaintenanceReminder reminder) async {
    _reminders.add(reminder);
  }

  @override
  Future<void> updateReminder(MaintenanceReminder reminder) async {
    lastUpdated = reminder;
    final idx = _reminders.indexWhere((r) => r.id == reminder.id);
    if (idx >= 0) _reminders[idx] = reminder;
  }

  @override
  Future<void> deleteReminder(String reminderId) async {
    _reminders.removeWhere((r) => r.id == reminderId);
  }
}

// ── Container helper ───────────────────────────────────────────────────────

ProviderContainer makeContainer({
  required FakeServiceRepository svcFake,
  required FakeMaintenanceRepository mainFake,
  required String userId,
}) {
  return ProviderContainer(
    overrides: [
      serviceRepositoryProvider.overrideWithValue(svcFake),
      maintenanceRepositoryProvider.overrideWithValue(mainFake),
    ],
  );
}

// ── Model helpers ─────────────────────────────────────────────────────────

ServiceRecord makeRecord({
  String id = 'svc-1',
  String userId = 'u1',
  String reminderId = 'rem-1',
  String reminderLabel = 'Aceite',
  double odometerKm = 15000,
  double costUsd = 25.0,
}) =>
    ServiceRecord(
      id: id,
      userId: userId,
      reminderId: reminderId,
      reminderLabel: reminderLabel,
      odometerKm: odometerKm,
      costUsd: costUsd,
      serviceDate: DateTime(2026, 4, 1),
    );

MaintenanceReminder makeReminder({
  String id = 'rem-1',
  String userId = 'u1',
  double intervalKm = 5000,
  double lastServiceKm = 10000,
}) =>
    MaintenanceReminder(
      id: id,
      userId: userId,
      label: 'Aceite',
      intervalKm: intervalKm,
      lastServiceKm: lastServiceKm,
      lastServiceDate: DateTime(2026, 1, 1),
    );

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  group('ServiceNotifier', () {
    test('build() loads empty list when no records exist', () async {
      final container = makeContainer(
        svcFake: FakeServiceRepository(),
        mainFake: FakeMaintenanceRepository(),
        userId: 'u1',
      );
      addTearDown(container.dispose);

      final records =
          await container.read(serviceNotifierProvider('u1').future);

      expect(records, isEmpty);
    });

    test('build() loads pre-existing records', () async {
      final existing = [makeRecord(id: 'svc-1', reminderLabel: 'Frenos')];
      final container = makeContainer(
        svcFake: FakeServiceRepository(existing),
        mainFake: FakeMaintenanceRepository(),
        userId: 'u1',
      );
      addTearDown(container.dispose);

      final records =
          await container.read(serviceNotifierProvider('u1').future);

      expect(records, hasLength(1));
      expect(records.first.reminderLabel, 'Frenos');
    });

    test('addRecord() appends the record to state', () async {
      final container = makeContainer(
        svcFake: FakeServiceRepository(),
        mainFake: FakeMaintenanceRepository([makeReminder()]),
        userId: 'u1',
      );
      addTearDown(container.dispose);

      await container.read(serviceNotifierProvider('u1').future);
      final notifier = container.read(serviceNotifierProvider('u1').notifier);
      await notifier.addRecord(makeRecord(id: 'svc-new', odometerKm: 15000));

      final records =
          await container.read(serviceNotifierProvider('u1').future);
      expect(records, hasLength(1));
      expect(records.first.odometerKm, 15000.0);
    });

    test('addRecord() resets reminder baseline with new odometerKm', () async {
      final mainFake = FakeMaintenanceRepository([makeReminder(id: 'rem-1')]);
      final container = makeContainer(
        svcFake: FakeServiceRepository(),
        mainFake: mainFake,
        userId: 'u1',
      );
      addTearDown(container.dispose);

      await container.read(serviceNotifierProvider('u1').future);
      final notifier = container.read(serviceNotifierProvider('u1').notifier);
      await notifier.addRecord(makeRecord(
        reminderId: 'rem-1',
        odometerKm: 15000,
      ));

      // The linked reminder's lastServiceKm should now be 15000
      expect(mainFake.lastUpdated, isNotNull);
      expect(mainFake.lastUpdated!.lastServiceKm, 15000.0);
    });

    test('deleteRecord() removes record from state', () async {
      final existing = [makeRecord(id: 'to-delete')];
      final container = makeContainer(
        svcFake: FakeServiceRepository(existing),
        mainFake: FakeMaintenanceRepository(),
        userId: 'u1',
      );
      addTearDown(container.dispose);

      await container.read(serviceNotifierProvider('u1').future);
      final notifier = container.read(serviceNotifierProvider('u1').notifier);
      await notifier.deleteRecord('to-delete');

      final records =
          await container.read(serviceNotifierProvider('u1').future);
      expect(records, isEmpty);
    });

    test('addRecord() sets AsyncError when repository throws', () async {
      final svcFake = FakeServiceRepository()
        ..addError = Exception('network error');
      final container = makeContainer(
        svcFake: svcFake,
        mainFake: FakeMaintenanceRepository([makeReminder()]),
        userId: 'u1',
      );
      addTearDown(container.dispose);

      await container.read(serviceNotifierProvider('u1').future);
      final notifier = container.read(serviceNotifierProvider('u1').notifier);
      await notifier.addRecord(makeRecord());

      final state = container.read(serviceNotifierProvider('u1'));
      expect(state.hasError, isTrue);
    });
  });
}
