// supabase_maintenance_repository.dart
//
// Supabase implementation of MaintenanceRepository.
//
// Design decisions:
//   - Table name: `maintenance_reminders` (matches Supabase schema).
//   - Maps between MaintenanceReminder domain model and JSON row format.
//   - last_service_date stored as ISO-8601 UTC string.
//   - All queries scoped to the authenticated user via RLS (server-side),
//     but userId is also sent as a column for clarity.
//   - upsert used for updateReminder to simplify conflict resolution.

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_repository.dart';

/// Supabase-backed implementation of [MaintenanceRepository].
class SupabaseMaintenanceRepository implements MaintenanceRepository {
  const SupabaseMaintenanceRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'maintenance_reminders';

  @override
  Future<List<MaintenanceReminder>> fetchReminders(
      {required String userId}) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('label', ascending: true);

    return (response as List)
        .map((row) => _fromRow(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> addReminder(MaintenanceReminder reminder) async {
    await _client.from(_table).insert(_toRow(reminder));
  }

  @override
  Future<void> updateReminder(MaintenanceReminder reminder) async {
    await _client.from(_table).update(_toRow(reminder)).eq('id', reminder.id);
  }

  @override
  Future<void> deleteReminder(String reminderId) async {
    await _client.from(_table).delete().eq('id', reminderId);
  }

  // ── Mapping helpers ──────────────────────────────────────────────────────

  static MaintenanceReminder _fromRow(Map<String, dynamic> row) {
    return MaintenanceReminder(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      label: row['label'] as String,
      intervalKm: (row['interval_km'] as num).toDouble(),
      lastServiceKm: (row['last_service_km'] as num).toDouble(),
      lastServiceDate:
          DateTime.parse(row['last_service_date'] as String).toLocal(),
      notes: row['notes'] as String?,
    );
  }

  static Map<String, dynamic> _toRow(MaintenanceReminder reminder) {
    return {
      'id': reminder.id,
      'user_id': reminder.userId,
      'label': reminder.label,
      'interval_km': reminder.intervalKm,
      'last_service_km': reminder.lastServiceKm,
      'last_service_date':
          reminder.lastServiceDate.toUtc().toIso8601String(),
      if (reminder.notes != null) 'notes': reminder.notes,
    };
  }
}
