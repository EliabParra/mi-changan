// mileage_log.dart
//
// Domain model for a mileage log entry.
//
// Design decisions:
//   - Immutable value object — final fields, no setters.
//   - Two entry types: `total` (odometer reading) and `distance` (trip distance).
//   - `MileageEntryType.total` records the absolute odometer reading.
//   - `MileageEntryType.distance` records a trip/trip-distance increment.

/// Whether a log records the total odometer or a trip distance.
enum MileageEntryType { total, distance }

/// A single mileage log entry linked to a user.
class MileageLog {
  const MileageLog({
    required this.id,
    required this.userId,
    required this.entryType,
    required this.valueKm,
    required this.recordedAt,
    this.notes,
  });

  /// Unique identifier (UUID from Supabase).
  final String id;

  /// Owner's Supabase user ID.
  final String userId;

  /// Whether this records the total odometer or a trip distance.
  final MileageEntryType entryType;

  /// Km value: odometer reading for `total`, trip km for `distance`.
  final double valueKm;

  /// When the log was recorded (UTC).
  final DateTime recordedAt;

  /// Optional user notes.
  final String? notes;

  @override
  String toString() =>
      'MileageLog(id: $id, type: $entryType, value: $valueKm, at: $recordedAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MileageLog &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
