// maintenance_notifier_test.dart
//
// TDD — Task 2.1 RED (Notifier)
// Unit tests for MaintenanceNotifier (CRUD + state management).
//
// Tests cover:
//   - build() loads reminders from repository.
//   - addReminder() persists and refreshes state.
//   - updateReminder() persists and refreshes state.
//   - deleteReminder() removes and refreshes state.
//   - addReminder() sets AsyncError on repository failure.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_notifier_provider.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_repository.dart';

// ── Fake repository ────────────────────────────────────────────────────────

class FakeMaintenanceRepository implements MaintenanceRepository {
  FakeMaintenanceRepository([List<MaintenanceReminder>? initial])
      : _stored = List.from(initial ?? []);

  final List<MaintenanceReminder> _stored;
  Exception? addError;

  @override
  Future<List<MaintenanceReminder>> fetchReminders(
          {required String userId}) async =>
      List.unmodifiable(_stored);

  @override
  Future<void> addReminder(MaintenanceReminder reminder) async {
    if (addError != null) throw addError!;
    _stored.add(reminder);
  }

  @override
  Future<void> updateReminder(MaintenanceReminder reminder) async {
    final idx = _stored.indexWhere((r) => r.id == reminder.id);
    if (idx >= 0) _stored[idx] = reminder;
  }

  @override
  Future<void> deleteReminder(String reminderId) async {
    _stored.removeWhere((r) => r.id == reminderId);
  }
}

// ── Container helper ───────────────────────────────────────────────────────

ProviderContainer makeContainer(
    FakeMaintenanceRepository fake, String userId) {
  return ProviderContainer(
    overrides: [
      maintenanceRepositoryProvider.overrideWithValue(fake),
    ],
  );
}

// ── Model helper ──────────────────────────────────────────────────────────

MaintenanceReminder makeReminder({
  String id = 'rem-1',
  String userId = 'u1',
  String label = 'Cambio de aceite',
  double intervalKm = 5000,
  double lastServiceKm = 10000,
}) =>
    MaintenanceReminder(
      id: id,
      userId: userId,
      label: label,
      intervalKm: intervalKm,
      lastServiceKm: lastServiceKm,
      lastServiceDate: DateTime(2026, 1, 1),
    );

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  group('MaintenanceNotifier', () {
    test('build() loads empty list when no reminders exist', () async {
      final fake = FakeMaintenanceRepository();
      final container = makeContainer(fake, 'u1');
      addTearDown(container.dispose);

      final reminders =
          await container.read(maintenanceNotifierProvider('u1').future);

      expect(reminders, isEmpty);
    });

    test('build() loads pre-existing reminders', () async {
      final existing = [makeReminder(id: 'rem-1', label: 'Aceite')];
      final fake = FakeMaintenanceRepository(existing);
      final container = makeContainer(fake, 'u1');
      addTearDown(container.dispose);

      final reminders =
          await container.read(maintenanceNotifierProvider('u1').future);

      expect(reminders, hasLength(1));
      expect(reminders.first.id, 'rem-1');
    });

    test('addReminder() appends the reminder to state', () async {
      final fake = FakeMaintenanceRepository();
      final container = makeContainer(fake, 'u1');
      addTearDown(container.dispose);

      await container.read(maintenanceNotifierProvider('u1').future);
      final notifier =
          container.read(maintenanceNotifierProvider('u1').notifier);
      await notifier.addReminder(makeReminder(id: 'rem-new', label: 'Frenos'));

      final reminders =
          await container.read(maintenanceNotifierProvider('u1').future);
      expect(reminders, hasLength(1));
      expect(reminders.first.label, 'Frenos');
    });

    test('updateReminder() changes existing reminder in state', () async {
      final original = makeReminder(id: 'rem-1', intervalKm: 5000);
      final fake = FakeMaintenanceRepository([original]);
      final container = makeContainer(fake, 'u1');
      addTearDown(container.dispose);

      await container.read(maintenanceNotifierProvider('u1').future);
      final notifier =
          container.read(maintenanceNotifierProvider('u1').notifier);
      final updated = makeReminder(id: 'rem-1', intervalKm: 10000);
      await notifier.updateReminder(updated);

      final reminders =
          await container.read(maintenanceNotifierProvider('u1').future);
      expect(reminders, hasLength(1));
      expect(reminders.first.intervalKm, 10000.0);
    });

    test('deleteReminder() removes reminder from state', () async {
      final existing = [makeReminder(id: 'to-delete')];
      final fake = FakeMaintenanceRepository(existing);
      final container = makeContainer(fake, 'u1');
      addTearDown(container.dispose);

      await container.read(maintenanceNotifierProvider('u1').future);
      final notifier =
          container.read(maintenanceNotifierProvider('u1').notifier);
      await notifier.deleteReminder('to-delete');

      final reminders =
          await container.read(maintenanceNotifierProvider('u1').future);
      expect(reminders, isEmpty);
    });

    test('addReminder() sets AsyncError when repository throws', () async {
      final fake = FakeMaintenanceRepository()
        ..addError = Exception('network error');
      final container = makeContainer(fake, 'u1');
      addTearDown(container.dispose);

      await container.read(maintenanceNotifierProvider('u1').future);
      final notifier =
          container.read(maintenanceNotifierProvider('u1').notifier);
      await notifier.addReminder(makeReminder());

      final state = container.read(maintenanceNotifierProvider('u1'));
      expect(state.hasError, isTrue);
    });
  });
}
