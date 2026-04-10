// dashboard_provider.dart
//
// Riverpod provider that aggregates mileage logs into DashboardMetrics.
//
// Design decisions:
//   - FutureProvider.family parameterized by userId — pure data fetch.
//   - No UI dependency — can be unit-tested without Flutter widgets.
//   - nextServiceKm will later be read from settings; defaulting to null (MVP).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/dashboard/domain/dashboard_metrics.dart';
import 'package:mi_changan/features/mileage/domain/mileage_repository.dart';

/// Provides aggregated [DashboardMetrics] for a given [userId].
///
/// Fetches all mileage logs via [mileageRepositoryProvider] and computes
/// metrics using the pure [DashboardMetrics.fromLogs] factory.
final dashboardMetricsProvider =
    FutureProvider.family<DashboardMetrics, String>((ref, userId) async {
  final repo = ref.watch(mileageRepositoryProvider);
  final logs = await repo.fetchLogs(userId: userId);
  return DashboardMetrics.fromLogs(logs);
});
