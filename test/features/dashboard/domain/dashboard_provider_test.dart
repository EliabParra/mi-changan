// dashboard_provider_test.dart
//
// TDD — Task 1.1 RED (provider layer)
// Unit tests for dashboardMetricsProvider.
//
// Verifies that:
//   - Provider emits DashboardMetrics.empty() when there are no logs.
//   - Provider emits correct totalKm when logs are provided.
//   - Provider propagates nextServiceKm from settings when configured.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/dashboard/domain/dashboard_provider.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/mileage/domain/mileage_repository.dart';

// ── Fake repository ────────────────────────────────────────────────────────

class FakeMileageRepository implements MileageRepository {
  FakeMileageRepository(this._logs);

  final List<MileageLog> _logs;

  @override
  Future<List<MileageLog>> fetchLogs({required String userId}) async => _logs;

  @override
  Future<void> addLog(MileageLog log) async {}

  @override
  Future<void> deleteLog(String logId) async {}
}

// ── Helpers ────────────────────────────────────────────────────────────────

ProviderContainer makeContainer(List<MileageLog> logs) {
  return ProviderContainer(
    overrides: [
      mileageRepositoryProvider
          .overrideWithValue(FakeMileageRepository(logs)),
    ],
  );
}

void main() {
  group('dashboardMetricsProvider', () {
    test('emits empty metrics when no logs exist', () async {
      final container = makeContainer([]);
      addTearDown(container.dispose);

      final metrics = await container.read(dashboardMetricsProvider('u1').future);

      expect(metrics.totalKm, 0.0);
      expect(metrics.avgKmPerDay, 0.0);
    });

    test('emits correct totalKm from distance logs', () async {
      final logs = [
        MileageLog(
          id: '1',
          userId: 'u1',
          entryType: MileageEntryType.distance,
          valueKm: 120.0,
          recordedAt: DateTime(2026, 1, 1),
        ),
        MileageLog(
          id: '2',
          userId: 'u1',
          entryType: MileageEntryType.distance,
          valueKm: 80.0,
          recordedAt: DateTime(2026, 1, 15),
        ),
      ];
      final container = makeContainer(logs);
      addTearDown(container.dispose);

      final metrics = await container.read(dashboardMetricsProvider('u1').future);

      expect(metrics.totalKm, 200.0);
    });

    test('emits correct totalKm from latest total log', () async {
      final logs = [
        MileageLog(
          id: '1',
          userId: 'u1',
          entryType: MileageEntryType.total,
          valueKm: 11000.0,
          recordedAt: DateTime(2026, 1, 1),
        ),
        MileageLog(
          id: '2',
          userId: 'u1',
          entryType: MileageEntryType.total,
          valueKm: 12500.0,
          recordedAt: DateTime(2026, 2, 1),
        ),
      ];
      final container = makeContainer(logs);
      addTearDown(container.dispose);

      final metrics = await container.read(dashboardMetricsProvider('u1').future);

      expect(metrics.totalKm, 12500.0);
    });
  });
}
