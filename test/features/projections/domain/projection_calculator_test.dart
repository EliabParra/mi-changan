// projection_calculator_test.dart
//
// TDD — Task 3.1 RED
// Unit tests for ProjectionCalculator pure functions.
//
// Spec scenarios:
//   - Projection for 1 month: returns a single data point
//   - Projection for 6 months: returns 6 data points
//   - Projection for 1 year: returns 12 data points
//   - Average km/month calculated correctly from logs spanning multiple months
//   - Starting km is the current (latest total log) odometer reading
//   - Returns empty list when no mileage logs provided
//   - Each projection point has a date and estimated odometer reading

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/projections/domain/projection_calculator.dart';
import 'package:mi_changan/features/projections/domain/projection_point.dart';

void main() {
  // ── Helpers ───────────────────────────────────────────────────────────────

  MileageLog makeLog({
    required String id,
    required double valueKm,
    required DateTime recordedAt,
    MileageEntryType type = MileageEntryType.total,
  }) =>
      MileageLog(
        id: id,
        userId: 'u1',
        entryType: type,
        valueKm: valueKm,
        recordedAt: recordedAt,
      );

  // ── ProjectionPoint ───────────────────────────────────────────────────────

  group('ProjectionPoint', () {
    test('stores month and estimatedKm', () {
      final point = ProjectionPoint(
        month: DateTime(2026, 5),
        estimatedKm: 15500.0,
      );

      expect(point.month, DateTime(2026, 5));
      expect(point.estimatedKm, 15500.0);
    });
  });

  // ── ProjectionCalculator.computeAvgKmPerMonth ─────────────────────────────

  group('ProjectionCalculator.computeAvgKmPerMonth', () {
    test('returns 0 when no total logs available', () {
      final result = ProjectionCalculator.computeAvgKmPerMonth([]);

      expect(result, 0.0);
    });

    test('returns 0 when only one total log (cannot compute span)', () {
      final logs = [
        makeLog(id: 'l1', valueKm: 10000, recordedAt: DateTime(2026, 1, 1)),
      ];

      final result = ProjectionCalculator.computeAvgKmPerMonth(logs);

      expect(result, 0.0);
    });

    test('computes avg km per month from two total logs spanning 2 months', () {
      // 10000 → 12000 over ~2 months = 1000 km/month
      final logs = [
        makeLog(id: 'l1', valueKm: 10000, recordedAt: DateTime(2026, 1, 1)),
        makeLog(id: 'l2', valueKm: 12000, recordedAt: DateTime(2026, 3, 1)),
      ];

      final result = ProjectionCalculator.computeAvgKmPerMonth(logs);

      // 2000 km over 2 months = 1000 km/month
      expect(result, closeTo(1000.0, 50.0));
    });

    test('uses only total-type logs for avg computation', () {
      // distance logs should not affect avg calculation
      final logs = [
        makeLog(id: 'l1', valueKm: 10000, recordedAt: DateTime(2026, 1, 1)),
        makeLog(
            id: 'l2',
            valueKm: 500,
            recordedAt: DateTime(2026, 2, 1),
            type: MileageEntryType.distance),
        makeLog(id: 'l3', valueKm: 11000, recordedAt: DateTime(2026, 3, 1)),
      ];

      final result = ProjectionCalculator.computeAvgKmPerMonth(logs);

      // Only l1 (10000) and l3 (11000) used → 1000 km over 2 months = 500/month
      expect(result, closeTo(500.0, 50.0));
    });
  });

  // ── ProjectionCalculator.project ─────────────────────────────────────────

  group('ProjectionCalculator.project', () {
    test('returns empty list when no logs provided', () {
      final result = ProjectionCalculator.project(
        logs: [],
        months: 6,
        from: DateTime(2026, 4, 1),
      );

      expect(result, isEmpty);
    });

    test('returns N points for N months requested', () {
      final logs = [
        makeLog(id: 'l1', valueKm: 10000, recordedAt: DateTime(2026, 1, 1)),
        makeLog(id: 'l2', valueKm: 12000, recordedAt: DateTime(2026, 3, 1)),
      ];

      final result = ProjectionCalculator.project(
        logs: logs,
        months: 6,
        from: DateTime(2026, 4, 1),
      );

      expect(result, hasLength(6));
    });

    test('returns 12 points for 1Y window', () {
      final logs = [
        makeLog(id: 'l1', valueKm: 10000, recordedAt: DateTime(2026, 1, 1)),
        makeLog(id: 'l2', valueKm: 12000, recordedAt: DateTime(2026, 3, 1)),
      ];

      final result = ProjectionCalculator.project(
        logs: logs,
        months: 12,
        from: DateTime(2026, 4, 1),
      );

      expect(result, hasLength(12));
    });

    test('first point is at from+1 month with current odometer + avg', () {
      // latest total = 12000, avg = 1000/month
      // from = 2026-04-01 → first point month = 2026-05-01, km = 13000
      final logs = [
        makeLog(id: 'l1', valueKm: 10000, recordedAt: DateTime(2026, 1, 1)),
        makeLog(id: 'l2', valueKm: 12000, recordedAt: DateTime(2026, 3, 1)),
      ];

      final result = ProjectionCalculator.project(
        logs: logs,
        months: 1,
        from: DateTime(2026, 4, 1),
      );

      expect(result, hasLength(1));
      expect(result.first.month, DateTime(2026, 5));
      expect(result.first.estimatedKm, closeTo(13000.0, 100.0));
    });

    test('projection grows linearly across multiple months', () {
      // avg = 1000/month, start = 12000, from = 2026-04-01
      // Month 1: 13000, Month 2: 14000, Month 3: 15000
      final logs = [
        makeLog(id: 'l1', valueKm: 10000, recordedAt: DateTime(2026, 1, 1)),
        makeLog(id: 'l2', valueKm: 12000, recordedAt: DateTime(2026, 3, 1)),
      ];

      final result = ProjectionCalculator.project(
        logs: logs,
        months: 3,
        from: DateTime(2026, 4, 1),
      );

      expect(result[0].estimatedKm, closeTo(13000.0, 100.0));
      expect(result[1].estimatedKm, closeTo(14000.0, 100.0));
      expect(result[2].estimatedKm, closeTo(15000.0, 100.0));
    });
  });
}
