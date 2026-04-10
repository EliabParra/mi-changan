// reminder_status_badge.dart
//
// Pure presentation widget — displays a colored badge for ReminderStatus.
//
// Design decisions:
//   - Stateless widget (pure — depends only on its single parameter).
//   - Color mapping: upcoming=green, due=amber, overdue=red.
//   - Uses Container + BoxDecoration for a rounded pill style.

import 'package:flutter/material.dart';

import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';

/// A small colored badge that communicates the [ReminderStatus] visually.
class ReminderStatusBadge extends StatelessWidget {
  const ReminderStatusBadge({super.key, required this.status});

  final ReminderStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('reminder_badge_${status.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _badgeColor(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _badgeLabel(status),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Color _badgeColor(ReminderStatus status) => switch (status) {
        ReminderStatus.upcoming => Colors.green,
        ReminderStatus.due => Colors.amber,
        ReminderStatus.overdue => Colors.red,
      };

  static String _badgeLabel(ReminderStatus status) => switch (status) {
        ReminderStatus.upcoming => 'Al día',
        ReminderStatus.due => 'Próximo',
        ReminderStatus.overdue => 'Vencido',
      };
}
