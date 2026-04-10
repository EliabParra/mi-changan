// projection_calculator.dart
//
// Pure domain functions for km projection calculations.
//
// Design decisions:
//   - All methods are static — no state, no dependencies.
//   - Only MileageEntryType.total logs are used for avg computation
//     (odometer readings give absolute positions; distance logs are increments).
//   - Avg is computed as (latestKm - earliestKm) / elapsedMonths.
//   - project() returns N points starting from `from + 1 month`.
//   - Returns empty list when input logs are empty or insufficient.
//   - dateToReachKm(): returns null when avg is 0 or target already reached.
//   - kmAtDate(): returns null when avg is 0 or date is in the past.

import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/projections/domain/projection_point.dart';

/// Pure static helpers for computing km projections from mileage logs.
abstract final class ProjectionCalculator {
  // ── Constants ──────────────────────────────────────────────────────────

  /// Number of days in an average month — used for month-span calculation.
  static const double _daysPerMonth = 30.4375;

  // ── Public API ──────────────────────────────────────────────────────────

  /// Computes the average km driven per calendar month.
  ///
  /// Uses only [MileageEntryType.total] logs.
  /// Returns 0.0 when fewer than 2 total logs are available.
  static double computeAvgKmPerMonth(List<MileageLog> logs) {
    final totalLogs = _totalLogsOnly(logs);
    if (totalLogs.length < 2) return 0.0;

    totalLogs.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    final earliest = totalLogs.first;
    final latest = totalLogs.last;
    final kmDelta = latest.valueKm - earliest.valueKm;
    final daysDelta =
        latest.recordedAt.difference(earliest.recordedAt).inDays.toDouble();
    if (daysDelta <= 0) return 0.0;

    final months = daysDelta / _daysPerMonth;
    return kmDelta / months;
  }

  /// Projects km readings for the next [months] calendar months.
  ///
  /// [from] — the reference date (typically today).
  /// Returns [months] [ProjectionPoint]s starting at `from + 1 month`,
  /// or an empty list when [logs] is empty.
  static List<ProjectionPoint> project({
    required List<MileageLog> logs,
    required int months,
    required DateTime from,
  }) {
    if (logs.isEmpty) return const [];

    final avgPerMonth = computeAvgKmPerMonth(logs);
    final startKm = _latestTotalKm(logs);

    return List.generate(months, (i) {
      final pointMonth = _addMonths(from, i + 1);
      final estimatedKm = startKm + avgPerMonth * (i + 1);
      return ProjectionPoint(month: pointMonth, estimatedKm: estimatedKm);
    });
  }

  /// Calculates the estimated date when the odometer will reach [targetKm].
  ///
  /// [from] — reference date (typically today).
  /// Returns null when:
  ///   - avg km/month is 0 (insufficient data),
  ///   - target is already at or below current odometer.
  static DateTime? dateToReachKm({
    required List<MileageLog> logs,
    required double targetKm,
    required DateTime from,
  }) {
    final avg = computeAvgKmPerMonth(logs);
    if (avg <= 0) return null;

    final currentKm = _latestTotalKm(logs);
    if (targetKm <= currentKm) return null;

    final monthsNeeded = (targetKm - currentKm) / avg;
    final daysNeeded = (monthsNeeded * _daysPerMonth).round();
    return from.add(Duration(days: daysNeeded));
  }

  /// Estimates the odometer reading at [targetDate].
  ///
  /// [from] — reference date (typically today).
  /// Returns null when:
  ///   - avg km/month is 0 (insufficient data),
  ///   - [targetDate] is not after [from].
  static double? kmAtDate({
    required List<MileageLog> logs,
    required DateTime targetDate,
    required DateTime from,
  }) {
    if (!targetDate.isAfter(from)) return null;

    final avg = computeAvgKmPerMonth(logs);
    if (avg <= 0) return null;

    final currentKm = _latestTotalKm(logs);
    final daysDelta = targetDate.difference(from).inDays.toDouble();
    final monthsDelta = daysDelta / _daysPerMonth;

    return currentKm + avg * monthsDelta;
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  static List<MileageLog> _totalLogsOnly(List<MileageLog> logs) =>
      logs.where((l) => l.entryType == MileageEntryType.total).toList();

  /// Latest total odometer reading. Falls back to 0 when none found.
  static double _latestTotalKm(List<MileageLog> logs) {
    final totals = _totalLogsOnly(logs);
    if (totals.isEmpty) return 0.0;
    totals.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return totals.last.valueKm;
  }

  /// Returns a [DateTime] that is [n] calendar months after [base].
  static DateTime _addMonths(DateTime base, int n) {
    var month = base.month + n;
    var year = base.year + (month - 1) ~/ 12;
    month = ((month - 1) % 12) + 1;
    return DateTime(year, month);
  }
}
