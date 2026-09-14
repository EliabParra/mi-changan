// supabase_service_repository.dart
//
// Supabase implementation of ServiceRepository.
//
// Design decisions:
//   - Table name: `service_records` (matches Supabase schema).
//   - Maps between ServiceRecord domain model and JSON row format.
//   - service_date stored as ISO-8601 UTC string.
//   - All queries scoped to the authenticated user via RLS (server-side).
//   - No update method — service records are immutable once logged.

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mi_changan/features/services/domain/service_record.dart';
import 'package:mi_changan/features/services/domain/service_repository.dart';

/// Supabase-backed implementation of [ServiceRepository].
class SupabaseServiceRepository implements ServiceRepository {
  const SupabaseServiceRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'service_records';

  @override
  Future<List<ServiceRecord>> fetchRecords({required String userId}) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('service_date', ascending: false);

    return (response as List)
        .map((row) => _fromRow(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> addRecord(ServiceRecord record) async {
    await _client.from(_table).insert(_toRow(record));
  }

  @override
  Future<void> deleteRecord(String recordId) async {
    await _client.from(_table).delete().eq('id', recordId);
  }

  // ── Mapping helpers ──────────────────────────────────────────────────────

  static ServiceRecord _fromRow(Map<String, dynamic> row) {
    return ServiceRecord(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      reminderId: row['reminder_id'] as String,
      reminderLabel: row['reminder_label'] as String,
      odometerKm: (row['odometer_km'] as num).toDouble(),
      costUsd: (row['cost_usd'] as num).toDouble(),
      serviceDate:
          DateTime.parse(row['service_date'] as String).toLocal(),
      workshopName: row['workshop_name'] as String?,
      notes: row['notes'] as String?,
    );
  }

  static Map<String, dynamic> _toRow(ServiceRecord record) {
    return {
      'id': record.id,
      'user_id': record.userId,
      'reminder_id': record.reminderId,
      'reminder_label': record.reminderLabel,
      'odometer_km': record.odometerKm,
      'cost_usd': record.costUsd,
      'service_date': record.serviceDate.toUtc().toIso8601String(),
      if (record.workshopName != null) 'workshop_name': record.workshopName,
      if (record.notes != null) 'notes': record.notes,
    };
  }
}
