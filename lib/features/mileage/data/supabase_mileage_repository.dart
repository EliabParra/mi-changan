// supabase_mileage_repository.dart
//
// Supabase implementation of MileageRepository.
//
// Design decisions:
//   - Table name: `mileage_logs` (matches Supabase schema).
//   - Maps between MileageLog domain model and JSON row format.
//   - entry_type stored as string ('total' | 'distance').
//   - recorded_at stored as ISO-8601 UTC string.
//   - All queries scoped to the authenticated user via RLS (server-side),
//     but userId is also sent as a column for clarity.

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/mileage/domain/mileage_repository.dart';

/// Supabase-backed implementation of [MileageRepository].
class SupabaseMileageRepository implements MileageRepository {
  const SupabaseMileageRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'mileage_logs';

  @override
  Future<List<MileageLog>> fetchLogs({required String userId}) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('recorded_at', ascending: false);

    return (response as List)
        .map((row) => _fromRow(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> addLog(MileageLog log) async {
    await _client.from(_table).insert(_toRow(log));
  }

  @override
  Future<void> deleteLog(String logId) async {
    await _client.from(_table).delete().eq('id', logId);
  }

  // ── Mapping helpers ──────────────────────────────────────────────────────

  static MileageLog _fromRow(Map<String, dynamic> row) {
    return MileageLog(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      entryType: row['entry_type'] == 'total'
          ? MileageEntryType.total
          : MileageEntryType.distance,
      valueKm: (row['value_km'] as num).toDouble(),
      recordedAt: DateTime.parse(row['recorded_at'] as String),
      notes: row['notes'] as String?,
    );
  }

  static Map<String, dynamic> _toRow(MileageLog log) {
    return {
      'id': log.id,
      'user_id': log.userId,
      'entry_type': log.entryType == MileageEntryType.total ? 'total' : 'distance',
      'value_km': log.valueKm,
      'recorded_at': log.recordedAt.toUtc().toIso8601String(),
      if (log.notes != null) 'notes': log.notes,
    };
  }
}
