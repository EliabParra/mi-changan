// dashboard_provider.dart
//
// Riverpod provider that aggregates mileage logs into DashboardMetrics.
//
// Design decisions:
//   - FutureProvider.family parameterized by userId — pure data fetch.
//   - No UI dependency — can be unit-tested without Flutter widgets.
//   - Reads vehicleSettingsProvider to obtain nextServiceKm when configured.
//   - nextServiceKm is taken from vehicleSettings.nextServiceKm if available;
//     falls back to null so the card is hidden when not set.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/dashboard/domain/dashboard_metrics.dart';
import 'package:mi_changan/features/mileage/domain/mileage_repository.dart';
import 'package:mi_changan/features/settings/domain/vehicle_settings_notifier.dart';

/// Provides aggregated [DashboardMetrics] for a given [userId].
///
/// Fetches all mileage logs via [mileageRepositoryProvider] and computes
/// metrics using the pure [DashboardMetrics.fromLogs] factory.
/// Also reads [vehicleSettingsProvider] for nextServiceKm when configured.
final dashboardMetricsProvider =
    FutureProvider.family<DashboardMetrics, String>((ref, userId) async {
  final repo = ref.watch(mileageRepositoryProvider);
  final logs = await repo.fetchLogs(userId: userId);

  // Read vehicle settings synchronously — already loaded by settings screen.
  // If not yet ready, treat nextServiceKm as null.
  final vehicleSettings = ref.watch(vehicleSettingsProvider).valueOrNull;
  final nextServiceKm = vehicleSettings?.nextServiceKm;

  return DashboardMetrics.fromLogs(logs, nextServiceKm: nextServiceKm);
});
