import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';
import 'package:mi_changan/features/projections/domain/projection_point.dart';

enum MaintenanceMarkerStatus { due, nearDue }

class MaintenanceMarker {
  const MaintenanceMarker({
    required this.reminderId,
    required this.label,
    required this.status,
    this.remainingKm,
  });

  final String reminderId;
  final String label;
  final MaintenanceMarkerStatus status;
  final double? remainingKm;
}

class ProjectionViewModel {
  const ProjectionViewModel({
    required this.points,
    required this.maintenanceMarkers,
  });

  final List<ProjectionPoint> points;
  final List<MaintenanceMarker> maintenanceMarkers;
}

abstract final class ProjectionMaintenanceComposer {
  static const Duration _nearDueWindow = Duration(days: 30);

  static ProjectionViewModel compose({
    required List<ProjectionPoint> points,
    required List<MaintenanceReminder> reminders,
    required DateTime now,
  }) {
    final markers = <MaintenanceMarker>[];

    for (final reminder in reminders) {
      if (reminder.status == ReminderStatus.overdue) {
        markers.add(MaintenanceMarker(
          reminderId: reminder.id,
          label: reminder.label,
          status: MaintenanceMarkerStatus.due,
          remainingKm: reminder.kmRemaining,
        ));
        continue;
      }

      if (reminder.status == ReminderStatus.due) {
        markers.add(MaintenanceMarker(
          reminderId: reminder.id,
          label: reminder.label,
          status: MaintenanceMarkerStatus.nearDue,
          remainingKm: reminder.kmRemaining,
        ));
        continue;
      }

      if (_isNearDueByProjectionDate(
        points: points,
        reminder: reminder,
        now: now,
      )) {
        markers.add(MaintenanceMarker(
          reminderId: reminder.id,
          label: reminder.label,
          status: MaintenanceMarkerStatus.nearDue,
          remainingKm: reminder.kmRemaining,
        ));
      }
    }

    return ProjectionViewModel(
      points: List<ProjectionPoint>.unmodifiable(points),
      maintenanceMarkers: List<MaintenanceMarker>.unmodifiable(markers),
    );
  }

  static bool _isNearDueByProjectionDate({
    required List<ProjectionPoint> points,
    required MaintenanceReminder reminder,
    required DateTime now,
  }) {
    if (reminder.status != ReminderStatus.upcoming) {
      return false;
    }

    final limit = now.add(_nearDueWindow);
    final targetKm = reminder.nextServiceKm;

    return points.any((point) {
      if (point.month.isBefore(now) || point.month.isAfter(limit)) {
        return false;
      }
      return point.estimatedKm >= targetKm;
    });
  }
}
