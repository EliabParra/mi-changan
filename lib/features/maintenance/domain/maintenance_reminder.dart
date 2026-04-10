// maintenance_reminder.dart
//
// Domain model for a maintenance reminder entry.
//
// Design decisions:
//   - Immutable value object — final fields, no setters.
//   - status is a computed property based on currentKm vs nextServiceKm.
//   - Due threshold: 500 km before nextServiceKm.
//   - kmRemaining is null when currentKm is not available.
//   - updateBaseline() is the only "mutation" — returns a new instance.

/// The alert state of a maintenance reminder relative to current odometer.
enum ReminderStatus {
  /// Service is not yet approaching.
  upcoming,

  /// Service is within [MaintenanceReminder.dueThresholdKm] of being needed.
  due,

  /// Current km has reached or passed the next service km.
  overdue,
}

/// A single maintenance reminder configured by the user.
class MaintenanceReminder {
  const MaintenanceReminder({
    required this.id,
    required this.userId,
    required this.label,
    required this.intervalKm,
    required this.lastServiceKm,
    required this.lastServiceDate,
    this.currentKm,
    this.notes,
  });

  /// Unique identifier (UUID from Supabase).
  final String id;

  /// Owner's Supabase user ID.
  final String userId;

  /// Human-readable label (e.g. 'Cambio de aceite').
  final String label;

  /// Service recurrence interval in km (e.g. 5000 for every 5,000 km).
  final double intervalKm;

  /// Odometer reading at the last service.
  final double lastServiceKm;

  /// Date of the last service performed.
  final DateTime lastServiceDate;

  /// Current odometer reading (injected from DashboardMetrics / mileage logs).
  /// Null when the odometer is not yet known.
  final double? currentKm;

  /// Optional notes.
  final String? notes;

  // ── Km threshold for "due" warning (500 km before nextServiceKm) ──────────
  static const double dueThresholdKm = 500.0;

  // ── Computed properties ───────────────────────────────────────────────────

  /// The km at which the next service is needed.
  double get nextServiceKm => lastServiceKm + intervalKm;

  /// Km remaining until next service (negative when overdue).
  /// Returns null if [currentKm] is null.
  double? get kmRemaining =>
      currentKm != null ? nextServiceKm - currentKm! : null;

  /// Computed status based on [kmRemaining].
  ReminderStatus get status {
    final remaining = kmRemaining;
    if (remaining == null) return ReminderStatus.upcoming;
    if (remaining <= 0) return ReminderStatus.overdue;
    if (remaining <= dueThresholdKm) return ReminderStatus.due;
    return ReminderStatus.upcoming;
  }

  // ── Mutation factory ──────────────────────────────────────────────────────

  /// Returns a new [MaintenanceReminder] with updated service baseline.
  ///
  /// Called after a service record is logged to reset the reminder.
  MaintenanceReminder updateBaseline({
    required double newLastServiceKm,
    required DateTime newLastServiceDate,
  }) =>
      MaintenanceReminder(
        id: id,
        userId: userId,
        label: label,
        intervalKm: intervalKm,
        lastServiceKm: newLastServiceKm,
        lastServiceDate: newLastServiceDate,
        currentKm: currentKm,
        notes: notes,
      );

  // ── Equality ──────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceReminder &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MaintenanceReminder(id: $id, label: $label, nextServiceKm: $nextServiceKm, status: $status)';
}
