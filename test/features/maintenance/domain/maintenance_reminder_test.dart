// maintenance_reminder_test.dart
//
// TDD — Task 2.1 RED
// Unit tests for MaintenanceReminder model and due/overdue status logic.
//
// Tests cover:
//   - ReminderStatus.upcoming  when km remaining > threshold (500 km).
//   - ReminderStatus.due       when km remaining ≤ threshold (500 km) but > 0.
//   - ReminderStatus.overdue   when km remaining ≤ 0 (i.e., nextServiceKm ≤ currentKm).
//   - Edge: exactly at threshold → due.
//   - Edge: exactly at nextServiceKm → overdue.
//   - Edge: no currentKm provided (null) → upcoming by default.
//   - MaintenanceReminder equality based on id.
//   - updateBaseline() returns a new reminder with updated lastServiceKm and lastServiceDate.

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';

void main() {
  // ── Helpers ────────────────────────────────────────────────────────────────

  MaintenanceReminder makeReminder({
    String id = 'rem-1',
    String userId = 'u1',
    String label = 'Cambio de aceite',
    double intervalKm = 5000,
    double lastServiceKm = 10000,
    DateTime? lastServiceDate,
    double? currentKm,
  }) =>
      MaintenanceReminder(
        id: id,
        userId: userId,
        label: label,
        intervalKm: intervalKm,
        lastServiceKm: lastServiceKm,
        lastServiceDate: lastServiceDate ?? DateTime(2026, 1, 1),
        currentKm: currentKm,
      );

  // ── status computed property ───────────────────────────────────────────────

  group('MaintenanceReminder.status', () {
    test('is upcoming when km remaining is well above the due threshold', () {
      // lastServiceKm=10000, intervalKm=5000 → nextServiceKm=15000
      // currentKm=12000 → kmRemaining=3000 → upcoming
      final reminder = makeReminder(
        lastServiceKm: 10000,
        intervalKm: 5000,
        currentKm: 12000,
      );

      expect(reminder.status, ReminderStatus.upcoming);
    });

    test('is due when km remaining ≤ threshold but still positive', () {
      // nextServiceKm=15000, currentKm=14600 → kmRemaining=400 ≤ 500 threshold
      final reminder = makeReminder(
        lastServiceKm: 10000,
        intervalKm: 5000,
        currentKm: 14600,
      );

      expect(reminder.status, ReminderStatus.due);
    });

    test('is overdue when current km has passed the next service km', () {
      // nextServiceKm=15000, currentKm=15100 → kmRemaining=-100 → overdue
      final reminder = makeReminder(
        lastServiceKm: 10000,
        intervalKm: 5000,
        currentKm: 15100,
      );

      expect(reminder.status, ReminderStatus.overdue);
    });

    test('is overdue exactly at nextServiceKm (boundary)', () {
      // nextServiceKm=15000, currentKm=15000 → kmRemaining=0 → overdue
      final reminder = makeReminder(
        lastServiceKm: 10000,
        intervalKm: 5000,
        currentKm: 15000,
      );

      expect(reminder.status, ReminderStatus.overdue);
    });

    test('is due exactly at the due threshold boundary', () {
      // nextServiceKm=15000, currentKm=14500 → kmRemaining=500 → due
      final reminder = makeReminder(
        lastServiceKm: 10000,
        intervalKm: 5000,
        currentKm: 14500,
      );

      expect(reminder.status, ReminderStatus.due);
    });

    test('is upcoming when currentKm is null (unknown odometer)', () {
      final reminder = makeReminder(
        lastServiceKm: 10000,
        intervalKm: 5000,
        currentKm: null,
      );

      expect(reminder.status, ReminderStatus.upcoming);
    });
  });

  // ── nextServiceKm ──────────────────────────────────────────────────────────

  group('MaintenanceReminder.nextServiceKm', () {
    test('is lastServiceKm + intervalKm', () {
      final reminder = makeReminder(lastServiceKm: 10000, intervalKm: 5000);

      expect(reminder.nextServiceKm, 15000.0);
    });

    test('reflects updated values when different interval used', () {
      final reminder = makeReminder(lastServiceKm: 20000, intervalKm: 10000);

      expect(reminder.nextServiceKm, 30000.0);
    });
  });

  // ── kmRemaining ───────────────────────────────────────────────────────────

  group('MaintenanceReminder.kmRemaining', () {
    test('returns null when currentKm is null', () {
      final reminder = makeReminder(currentKm: null);

      expect(reminder.kmRemaining, isNull);
    });

    test('returns positive value when service not yet due', () {
      final reminder = makeReminder(
        lastServiceKm: 10000,
        intervalKm: 5000,
        currentKm: 12000,
      );

      expect(reminder.kmRemaining, 3000.0);
    });

    test('returns negative value when overdue', () {
      final reminder = makeReminder(
        lastServiceKm: 10000,
        intervalKm: 5000,
        currentKm: 15200,
      );

      expect(reminder.kmRemaining, -200.0);
    });
  });

  // ── updateBaseline() ──────────────────────────────────────────────────────

  group('MaintenanceReminder.updateBaseline', () {
    test('returns a new reminder with updated lastServiceKm and date', () {
      final original = makeReminder(lastServiceKm: 10000);
      final serviceDate = DateTime(2026, 4, 1);

      final updated = original.updateBaseline(
        newLastServiceKm: 15000,
        newLastServiceDate: serviceDate,
      );

      expect(updated.lastServiceKm, 15000.0);
      expect(updated.lastServiceDate, serviceDate);
    });

    test('preserves all other fields unchanged', () {
      final original = makeReminder(
        id: 'rem-abc',
        userId: 'u99',
        label: 'Filtro de aire',
        intervalKm: 20000,
        lastServiceKm: 5000,
        currentKm: 8000,
      );

      final updated = original.updateBaseline(
        newLastServiceKm: 25000,
        newLastServiceDate: DateTime(2026, 4, 9),
      );

      expect(updated.id, 'rem-abc');
      expect(updated.userId, 'u99');
      expect(updated.label, 'Filtro de aire');
      expect(updated.intervalKm, 20000.0);
      expect(updated.currentKm, 8000.0);
    });
  });

  // ── Equality ──────────────────────────────────────────────────────────────

  group('MaintenanceReminder equality', () {
    test('two reminders with same id are equal', () {
      final a = makeReminder(id: 'rem-1');
      final b = makeReminder(id: 'rem-1', label: 'Different label');

      expect(a, equals(b));
    });

    test('two reminders with different ids are not equal', () {
      final a = makeReminder(id: 'rem-1');
      final b = makeReminder(id: 'rem-2');

      expect(a, isNot(equals(b)));
    });
  });
}
