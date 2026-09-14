// projection_point.dart
//
// Immutable value object representing a single projected km data point.
//
// Design decisions:
//   - Pure value type — no dependencies on repositories or providers.
//   - month is the first day of the projected month (normalized).
//   - estimatedKm is the projected total odometer reading for that month.

/// A single km-projection data point for chart rendering.
class ProjectionPoint {
  const ProjectionPoint({
    required this.month,
    required this.estimatedKm,
  });

  /// The projected month (normalized to year+month, day=1).
  final DateTime month;

  /// Estimated total odometer reading at the end of this month.
  final double estimatedKm;

  @override
  String toString() =>
      'ProjectionPoint(month: ${month.year}-${month.month.toString().padLeft(2, '0')}, km: $estimatedKm)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectionPoint &&
          runtimeType == other.runtimeType &&
          month == other.month &&
          estimatedKm == other.estimatedKm;

  @override
  int get hashCode => Object.hash(month, estimatedKm);
}
