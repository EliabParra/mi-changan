// dashboard_metrics_test.dart
//
// TDD — Task 1.1 RED
// Unit tests for DashboardMetrics model and pure view-model computations.
//
// Tests cover:
//   - DashboardMetrics.empty constructor
//   - DashboardMetrics.fromLogs factory: totalKm, avgPerMonth, avgPerDay
//   - nextServiceAlertKm: returns km remaining to next service
//   - isOverdue: returns true when currentKm >= nextServiceKm

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/dashboard/domain/dashboard_metrics.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log.dart';

void main() {
  group('DashboardMetrics.empty', () {
    test('all values are zero', () {
      const m = DashboardMetrics.empty();
      expect(m.totalKm, 0.0);
      expect(m.avgKmPerMonth, 0.0);
      expect(m.avgKmPerDay, 0.0);
      expect(m.nextServiceAlertKm, isNull);
    });
  });

  group('DashboardMetrics.fromLogs', () {
    test('totalKm sums all distance values', () {
      final logs = [
        MileageLog(
          id: '1',
          userId: 'u1',
          entryType: MileageEntryType.distance,
          valueKm: 50.0,
          recordedAt: DateTime(2026, 1, 1),
        ),
        MileageLog(
          id: '2',
          userId: 'u1',
          entryType: MileageEntryType.distance,
          valueKm: 30.0,
          recordedAt: DateTime(2026, 1, 15),
        ),
      ];
      final m = DashboardMetrics.fromLogs(logs);
      expect(m.totalKm, 80.0);
    });

    test('totalKm uses latest total entry when total logs are present', () {
      final logs = [
        MileageLog(
          id: '1',
          userId: 'u1',
          entryType: MileageEntryType.total,
          valueKm: 12000.0,
          recordedAt: DateTime(2026, 1, 1),
        ),
        MileageLog(
          id: '2',
          userId: 'u1',
          entryType: MileageEntryType.total,
          valueKm: 12500.0,
          recordedAt: DateTime(2026, 1, 20),
        ),
      ];
      final m = DashboardMetrics.fromLogs(logs);
      expect(m.totalKm, 12500.0);
    });

    test('avgKmPerDay is zero when fewer than 2 logs', () {
      final logs = [
        MileageLog(
          id: '1',
          userId: 'u1',
          entryType: MileageEntryType.distance,
          valueKm: 100.0,
          recordedAt: DateTime(2026, 1, 1),
        ),
      ];
      final m = DashboardMetrics.fromLogs(logs);
      expect(m.avgKmPerDay, 0.0);
    });

    test('avgKmPerDay is computed correctly from distance logs', () {
      // 100km over 10 days = 10 km/day
      final logs = [
        MileageLog(
          id: '1',
          userId: 'u1',
          entryType: MileageEntryType.distance,
          valueKm: 40.0,
          recordedAt: DateTime(2026, 1, 1),
        ),
        MileageLog(
          id: '2',
          userId: 'u1',
          entryType: MileageEntryType.distance,
          valueKm: 60.0,
          recordedAt: DateTime(2026, 1, 11),
        ),
      ];
      final m = DashboardMetrics.fromLogs(logs);
      expect(m.avgKmPerDay, closeTo(10.0, 0.01));
    });

    test('nextServiceAlertKm returns remaining km to next service', () {
      final logs = [
        MileageLog(
          id: '1',
          userId: 'u1',
          entryType: MileageEntryType.total,
          valueKm: 9500.0,
          recordedAt: DateTime(2026, 1, 1),
        ),
      ];
      // next service at 10000, current = 9500 → 500 remaining
      final m = DashboardMetrics.fromLogs(logs, nextServiceKm: 10000.0);
      expect(m.nextServiceAlertKm, closeTo(500.0, 0.01));
    });

    test('isOverdue is true when currentKm >= nextServiceKm', () {
      final logs = [
        MileageLog(
          id: '1',
          userId: 'u1',
          entryType: MileageEntryType.total,
          valueKm: 10100.0,
          recordedAt: DateTime(2026, 1, 1),
        ),
      ];
      final m = DashboardMetrics.fromLogs(logs, nextServiceKm: 10000.0);
      expect(m.isOverdue, isTrue);
    });

    test('isOverdue is false when currentKm < nextServiceKm', () {
      final logs = [
        MileageLog(
          id: '1',
          userId: 'u1',
          entryType: MileageEntryType.total,
          valueKm: 8000.0,
          recordedAt: DateTime(2026, 1, 1),
        ),
      ];
      final m = DashboardMetrics.fromLogs(logs, nextServiceKm: 10000.0);
      expect(m.isOverdue, isFalse);
    });
  });
}
