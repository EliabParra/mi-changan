// dashboard_metrics.dart
//
// Pure domain model for dashboard aggregate metrics.
//
// Design decisions:
//   - All computation is done in the factory constructor — pure function.
//   - No Riverpod/Flutter dependencies — easy to unit test.
//   - Two strategies depending on entry type mix:
//       • If any `total` logs exist → use latest total as currentKm.
//       • If only `distance` logs → sum all distances as currentKm.
//   - avgKmPerDay uses the date range between first and last log.
//   - avgKmPerMonth = avgKmPerDay * 30.

import 'package:mi_changan/features/mileage/domain/mileage_log.dart';

/// Aggregate metrics derived from a list of [MileageLog] entries.
class DashboardMetrics {
  /// Primary constructor.
  const DashboardMetrics({
    required this.totalKm,
    required this.avgKmPerMonth,
    required this.avgKmPerDay,
    this.nextServiceAlertKm,
    this.nextServiceKm,
  });

  /// Convenience constructor for an empty / zero state.
  const DashboardMetrics.empty()
      : totalKm = 0.0,
        avgKmPerMonth = 0.0,
        avgKmPerDay = 0.0,
        nextServiceAlertKm = null,
        nextServiceKm = null;

  /// Build [DashboardMetrics] from a list of [MileageLog] entries.
  ///
  /// [nextServiceKm] — if provided, computes [nextServiceAlertKm].
  factory DashboardMetrics.fromLogs(
    List<MileageLog> logs, {
    double? nextServiceKm,
  }) {
    if (logs.isEmpty) {
      return DashboardMetrics(
        totalKm: 0.0,
        avgKmPerMonth: 0.0,
        avgKmPerDay: 0.0,
        nextServiceAlertKm: nextServiceKm,
        nextServiceKm: nextServiceKm,
      );
    }

    // Determine currentKm — prefer latest `total` entry if any exist.
    final totalLogs = logs
        .where((l) => l.entryType == MileageEntryType.total)
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    final double currentKm;
    if (totalLogs.isNotEmpty) {
      currentKm = totalLogs.last.valueKm;
    } else {
      // Sum all distance logs
      currentKm = logs
          .where((l) => l.entryType == MileageEntryType.distance)
          .fold(0.0, (sum, l) => sum + l.valueKm);
    }

    // avgKmPerDay: computed from distance logs' date range
    final distanceLogs = logs
        .where((l) => l.entryType == MileageEntryType.distance)
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    final double avgDay;
    if (distanceLogs.length < 2) {
      avgDay = 0.0;
    } else {
      final days = distanceLogs.last.recordedAt
          .difference(distanceLogs.first.recordedAt)
          .inDays;
      final totalDistance = distanceLogs.fold(0.0, (s, l) => s + l.valueKm);
      avgDay = days > 0 ? totalDistance / days : 0.0;
    }

    final double avgMonth = avgDay * 30;
    final double? alertKm =
        nextServiceKm != null ? (nextServiceKm - currentKm) : null;

    return DashboardMetrics(
      totalKm: currentKm,
      avgKmPerMonth: avgMonth,
      avgKmPerDay: avgDay,
      nextServiceAlertKm: alertKm,
      nextServiceKm: nextServiceKm,
    );
  }

  // ── Fields ───────────────────────────────────────────────────────────────

  /// Current km on the odometer (or sum of distances).
  final double totalKm;

  /// Average km driven per month (estimated from log date range).
  final double avgKmPerMonth;

  /// Average km driven per day (estimated from log date range).
  final double avgKmPerDay;

  /// Km remaining until next scheduled service (null if no service set).
  final double? nextServiceAlertKm;

  /// Target km for next service (null if not configured).
  final double? nextServiceKm;

  // ── Computed ─────────────────────────────────────────────────────────────

  /// Whether the current km has reached or passed the next service km.
  bool get isOverdue => nextServiceKm != null && totalKm >= nextServiceKm!;
}
