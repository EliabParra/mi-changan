// projection_provider.dart
//
// Riverpod provider for km projections.
//
// Design decisions:
//   - Family provider keyed by (userId, months) so each window (1M, 6M, 1Y)
//     can be independently cached and subscribed.
//   - Reads mileageRepositoryProvider to fetch logs, then delegates to
//     ProjectionCalculator (pure function — no side effects).
//   - Uses today's date as the `from` reference — consistent with real usage.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/mileage/domain/mileage_repository.dart';
import 'package:mi_changan/features/projections/domain/projection_calculator.dart';
import 'package:mi_changan/features/projections/domain/projection_point.dart';

/// Parameter bundle for [projectionsProvider].
class ProjectionsParams {
  const ProjectionsParams({required this.userId, required this.months});

  final String userId;
  final int months;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectionsParams &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          months == other.months;

  @override
  int get hashCode => Object.hash(userId, months);
}

/// Async provider returning projected [ProjectionPoint]s for a given user.
///
/// Keyed by [ProjectionsParams] — subscribe per-window:
///   - `projectionsProvider(ProjectionsParams(userId: id, months: 1))`
///   - `projectionsProvider(ProjectionsParams(userId: id, months: 6))`
///   - `projectionsProvider(ProjectionsParams(userId: id, months: 12))`
final projectionsProvider =
    FutureProvider.family<List<ProjectionPoint>, ProjectionsParams>(
  (ref, params) async {
    final repo = ref.watch(mileageRepositoryProvider);
    final logs = await repo.fetchLogs(userId: params.userId);
    return ProjectionCalculator.project(
      logs: logs,
      months: params.months,
      from: DateTime.now(),
    );
  },
);
