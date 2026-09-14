// maintenance_notifier_provider.dart
//
// Riverpod provider declaration for MaintenanceNotifier.
//
// Separated from the notifier so router / other providers can import
// only the provider reference without loading the full notifier.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_changan/features/maintenance/domain/maintenance_notifier.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';

/// The application-wide maintenance reminders provider, keyed by userId.
///
/// Exposes [AsyncValue<List<MaintenanceReminder>>].
final maintenanceNotifierProvider = AsyncNotifierProvider.family<
    MaintenanceNotifier, List<MaintenanceReminder>, String>(
  MaintenanceNotifier.new,
);
