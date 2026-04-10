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

import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/services/domain/service_record.dart';
import 'package:mi_changan/features/settings/domain/export_schema_migrator.dart';
import 'package:mi_changan/features/settings/domain/vehicle_settings_notifier.dart';

/// Result of a JSON import operation.
class ImportResult {
  const ImportResult({
    required this.mileageLogs,
    required this.reminders,
    required this.serviceRecords,
    required this.schemaVersion,
    this.settings,
    this.exportedAt,
  });

  /// Parsed mileage log entries.
  final List<MileageLog> mileageLogs;

  /// Parsed maintenance reminders.
  final List<MaintenanceReminder> reminders;

  /// Parsed service records.
  final List<ServiceRecord> serviceRecords;

  /// Schema version declared by imported payload.
  final int schemaVersion;

  /// Parsed optional vehicle settings.
  final VehicleSettings? settings;

  /// Optional payload creation timestamp.
  final DateTime? exportedAt;
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
  static String exportToJson({
    required List<MileageLog> mileageLogs,
    List<MaintenanceReminder> reminders = const [],
    List<ServiceRecord> serviceRecords = const [],
    VehicleSettings? settings,
  }) {
    final exportedAt = DateTime.now().toUtc();
    final payload = <String, dynamic>{
      // Canonical keys for current schema.
      'schemaVersion': kCurrentExportSchemaVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'mileage': mileageLogs.map(_logToJson).toList(),
      'reminders': reminders.map(_reminderToJson).toList(),
      'services': serviceRecords.map(_serviceToJson).toList(),
      'settings': _settingsToJson(settings),
      // Legacy compatibility keys (v1 prototype / previous app exports).
      'schema_version': kCurrentExportSchemaVersion,
      'exported_at': exportedAt.toIso8601String(),
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
    final migrated =
        ExportSchemaMigratorRegistry.defaultRegistry.migrateToCurrent(decoded);

    final rawLogs = migrated['mileage'] as List? ?? [];
    final rawReminders = migrated['reminders'] as List? ?? [];
    final rawServices = migrated['services'] as List? ?? [];
    final rawSettings = migrated['settings'] as Map<String, dynamic>?;

    final mileageLogs = rawLogs
        .map((e) => _logFromJson(e as Map<String, dynamic>))
        .toList();
    final reminders = rawReminders
        .map((e) => _reminderFromJson(e as Map<String, dynamic>))
        .toList();
    final serviceRecords = rawServices
        .map((e) => _serviceFromJson(e as Map<String, dynamic>))
        .toList();
    final settings =
        rawSettings != null ? _settingsFromJson(rawSettings) : null;

    final schemaVersion =
        (migrated['schemaVersion'] as num?)?.toInt() ?? kCurrentExportSchemaVersion;
    final exportedAtRaw = migrated['exportedAt'] as String?;
    final exportedAt =
        exportedAtRaw != null ? DateTime.tryParse(exportedAtRaw) : null;

    return ImportResult(
      mileageLogs: mileageLogs,
      reminders: reminders,
      serviceRecords: serviceRecords,
      schemaVersion: schemaVersion,
      settings: settings,
      exportedAt: exportedAt,
    );
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

  static Map<String, dynamic> _reminderToJson(MaintenanceReminder reminder) => {
        'id': reminder.id,
        'user_id': reminder.userId,
        'label': reminder.label,
        'interval_km': reminder.intervalKm,
        'last_service_km': reminder.lastServiceKm,
        'last_service_date': reminder.lastServiceDate.toUtc().toIso8601String(),
        if (reminder.notes != null) 'notes': reminder.notes,
      };

  static MaintenanceReminder _reminderFromJson(Map<String, dynamic> json) =>
      MaintenanceReminder(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        label: json['label'] as String,
        intervalKm: (json['interval_km'] as num).toDouble(),
        lastServiceKm: (json['last_service_km'] as num).toDouble(),
        lastServiceDate: DateTime.parse(json['last_service_date'] as String),
        notes: json['notes'] as String?,
      );

  static Map<String, dynamic> _serviceToJson(ServiceRecord record) => {
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

  static ServiceRecord _serviceFromJson(Map<String, dynamic> json) => ServiceRecord(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        reminderId: json['reminder_id'] as String,
        reminderLabel: json['reminder_label'] as String,
        odometerKm: (json['odometer_km'] as num).toDouble(),
        costUsd: (json['cost_usd'] as num).toDouble(),
        serviceDate: DateTime.parse(json['service_date'] as String),
        workshopName: json['workshop_name'] as String?,
        notes: json['notes'] as String?,
      );

  static Map<String, dynamic> _settingsToJson(VehicleSettings? settings) {
    if (settings == null) return <String, dynamic>{};
    return {
      if (settings.initialKm != null) 'initialKm': settings.initialKm,
      if (settings.purchaseDate != null)
        'purchaseDate': settings.purchaseDate!.toUtc().toIso8601String(),
      if (settings.lastTireChangeKm != null)
        'lastTireChangeKm': settings.lastTireChangeKm,
      if (settings.nextServiceKm != null) 'nextServiceKm': settings.nextServiceKm,
    };
  }

  static VehicleSettings _settingsFromJson(Map<String, dynamic> json) =>
      VehicleSettings(
        initialKm: (json['initialKm'] as num?)?.toDouble(),
        purchaseDate: json['purchaseDate'] is String
            ? DateTime.tryParse(json['purchaseDate'] as String)
            : null,
        lastTireChangeKm: (json['lastTireChangeKm'] as num?)?.toDouble(),
        nextServiceKm: (json['nextServiceKm'] as num?)?.toDouble(),
      );
}
