// service_record_test.dart
//
// TDD — Task 2.2 RED
// Unit tests for ServiceRecord model.
//
// Tests cover:
//   - Immutable construction with all fields.
//   - Optional fields (workshopName, notes) can be null.
//   - Equality based on id.
//   - toString() includes key fields.

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/services/domain/service_record.dart';

void main() {
  // ── Helpers ────────────────────────────────────────────────────────────────

  ServiceRecord makeRecord({
    String id = 'svc-1',
    String userId = 'u1',
    String reminderId = 'rem-1',
    String reminderLabel = 'Cambio de aceite',
    double odometerKm = 15000,
    double costUsd = 25.50,
    DateTime? serviceDate,
    String? workshopName,
    String? notes,
  }) =>
      ServiceRecord(
        id: id,
        userId: userId,
        reminderId: reminderId,
        reminderLabel: reminderLabel,
        odometerKm: odometerKm,
        costUsd: costUsd,
        serviceDate: serviceDate ?? DateTime(2026, 4, 1),
        workshopName: workshopName,
        notes: notes,
      );

  // ── Construction ──────────────────────────────────────────────────────────

  group('ServiceRecord construction', () {
    test('stores all required fields correctly', () {
      final record = makeRecord(
        id: 'svc-abc',
        userId: 'user-99',
        reminderId: 'rem-xyz',
        reminderLabel: 'Frenos',
        odometerKm: 22000,
        costUsd: 80.0,
        serviceDate: DateTime(2026, 3, 15),
      );

      expect(record.id, 'svc-abc');
      expect(record.userId, 'user-99');
      expect(record.reminderId, 'rem-xyz');
      expect(record.reminderLabel, 'Frenos');
      expect(record.odometerKm, 22000.0);
      expect(record.costUsd, 80.0);
      expect(record.serviceDate, DateTime(2026, 3, 15));
    });

    test('optional fields default to null when not provided', () {
      final record = makeRecord();

      expect(record.workshopName, isNull);
      expect(record.notes, isNull);
    });

    test('stores optional workshopName and notes when provided', () {
      final record = makeRecord(
        workshopName: 'Taller Pérez',
        notes: 'Aceite 5W-30',
      );

      expect(record.workshopName, 'Taller Pérez');
      expect(record.notes, 'Aceite 5W-30');
    });
  });

  // ── Equality ──────────────────────────────────────────────────────────────

  group('ServiceRecord equality', () {
    test('two records with same id are equal', () {
      final a = makeRecord(id: 'svc-1', costUsd: 10.0);
      final b = makeRecord(id: 'svc-1', costUsd: 99.0);

      expect(a, equals(b));
    });

    test('two records with different ids are not equal', () {
      final a = makeRecord(id: 'svc-1');
      final b = makeRecord(id: 'svc-2');

      expect(a, isNot(equals(b)));
    });
  });

  // ── toString ──────────────────────────────────────────────────────────────

  group('ServiceRecord.toString', () {
    test('includes id, reminderLabel, and odometerKm', () {
      final record = makeRecord(
        id: 'svc-99',
        reminderLabel: 'Aceite',
        odometerKm: 12345.0,
      );

      final str = record.toString();

      expect(str, contains('svc-99'));
      expect(str, contains('Aceite'));
      expect(str, contains('12345.0'));
    });
  });
}
