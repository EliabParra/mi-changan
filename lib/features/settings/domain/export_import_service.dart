// export_import_service.dart
//
// Pure service for JSON export and import of app data.
//
// Design decisions:
//   - All methods are static — no state, pure transformation functions.
//   - schema_version is included so future migrations can be detected.
//   - MVP scope: only mileage_logs are exported/imported.
//   - importFromJson() throws FormatException on invalid JSON (caller handles).

import 'dart:convert';

import 'package:mi_changan/features/mileage/domain/mileage_log.dart';

/// The current JSON export schema version.
const _kSchemaVersion = 1;

/// Result of a JSON import operation.
class ImportResult {
  const ImportResult({required this.mileageLogs});

  /// Parsed mileage log entries.
  final List<MileageLog> mileageLogs;
}

/// Pure service for exporting and importing app data as JSON.
abstract final class ExportImportService {
  /// Serialize [mileageLogs] to a JSON string.
  ///
  /// The resulting JSON follows the MVP export schema:
  /// ```json
  /// {
  ///   "schema_version": 1,
  ///   "exported_at": "2026-...",
  ///   "mileage_logs": [ ... ]
  /// }
  /// ```
  static String exportToJson({required List<MileageLog> mileageLogs}) {
    final payload = <String, dynamic>{
      'schema_version': _kSchemaVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'mileage_logs': mileageLogs.map(_logToJson).toList(),
    };
    return jsonEncode(payload);
  }

  /// Parse a JSON string and return an [ImportResult].
  ///
  /// Throws [FormatException] if [raw] is not valid JSON.
  /// Returns empty lists for missing array keys (graceful degradation).
  static ImportResult importFromJson(String raw) {
    // jsonDecode throws FormatException on invalid input — propagate.
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    final rawLogs = decoded['mileage_logs'] as List? ?? [];
    final mileageLogs = rawLogs
        .map((e) => _logFromJson(e as Map<String, dynamic>))
        .toList();

    return ImportResult(mileageLogs: mileageLogs);
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  static Map<String, dynamic> _logToJson(MileageLog log) => {
        'id': log.id,
        'user_id': log.userId,
        'entry_type':
            log.entryType == MileageEntryType.total ? 'total' : 'distance',
        'value_km': log.valueKm,
        'recorded_at': log.recordedAt.toUtc().toIso8601String(),
        if (log.notes != null) 'notes': log.notes,
      };

  static MileageLog _logFromJson(Map<String, dynamic> json) => MileageLog(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        entryType: json['entry_type'] == 'total'
            ? MileageEntryType.total
            : MileageEntryType.distance,
        valueKm: (json['value_km'] as num).toDouble(),
        recordedAt: DateTime.parse(json['recorded_at'] as String),
        notes: json['notes'] as String?,
      );
}
