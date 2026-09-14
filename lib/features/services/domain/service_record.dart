// service_record.dart
//
// Domain model for a service record entry.
//
// Design decisions:
//   - Immutable value object — final fields, no setters.
//   - Links to a MaintenanceReminder via reminderId.
//   - reminderLabel is denormalized for display (avoids extra join).
//   - costUsd stored in USD to support Venezuelan market (multi-currency awareness).
//   - Equality based on id alone (UUID from Supabase).

/// A single service record logged by the user.
class ServiceRecord {
  const ServiceRecord({
    required this.id,
    required this.userId,
    required this.reminderId,
    required this.reminderLabel,
    required this.odometerKm,
    required this.costUsd,
    required this.serviceDate,
    this.workshopName,
    this.notes,
  });

  /// Unique identifier (UUID from Supabase).
  final String id;

  /// Owner's Supabase user ID.
  final String userId;

  /// ID of the linked [MaintenanceReminder].
  final String reminderId;

  /// Denormalized label of the linked reminder for display without joins.
  final String reminderLabel;

  /// Odometer reading at the time of service.
  final double odometerKm;

  /// Cost in USD.
  final double costUsd;

  /// Date the service was performed.
  final DateTime serviceDate;

  /// Optional workshop or mechanic name.
  final String? workshopName;

  /// Optional free-text notes.
  final String? notes;

  // ── Equality ──────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceRecord &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ServiceRecord(id: $id, label: $reminderLabel, km: $odometerKm)';
}
