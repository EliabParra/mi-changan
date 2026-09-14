// maintenance_repository.dart
//
// Abstract interface for maintenance reminder data operations.
//
// Design decisions:
//   - Interface-first pattern (mirrors MileageRepository) — production uses
//     Supabase; tests inject FakeMaintenanceRepository.
//   - All methods are async — Supabase calls are always awaited.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';

/// Abstract interface for maintenance reminder data operations.
abstract class MaintenanceRepository {
  /// Fetch all reminders for the given [userId].
  Future<List<MaintenanceReminder>> fetchReminders({required String userId});

  /// Persist a new [reminder].
  Future<void> addReminder(MaintenanceReminder reminder);

  /// Update an existing [reminder].
  Future<void> updateReminder(MaintenanceReminder reminder);

  /// Remove the reminder with [reminderId].
  Future<void> deleteReminder(String reminderId);
}

/// Riverpod provider for [MaintenanceRepository].
///
/// Overridden in tests with a [FakeMaintenanceRepository].
/// Production value is provided by [supabaseMaintenanceRepositoryProvider].
final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  throw UnimplementedError(
    'maintenanceRepositoryProvider must be overridden with a concrete implementation.',
  );
});
