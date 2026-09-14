// export_import_service_test.dart
//
// TDD — Task 1.3 RED
// Unit tests for ExportImportService pure functions.
//
// Tests cover:
//   - exportToJson() returns a valid JSON string with the expected schema.
//   - importFromJson() restores MileageLog records from a valid JSON string.
//   - importFromJson() throws FormatException on invalid JSON.
//   - importFromJson() returns empty lists when arrays are missing.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/maintenance/domain/maintenance_reminder.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/services/domain/service_record.dart';
import 'package:mi_changan/features/settings/domain/export_schema_migrator.dart';
import 'package:mi_changan/features/settings/domain/export_import_service.dart';
import 'package:mi_changan/features/settings/domain/vehicle_settings_notifier.dart';

void main() {
  group('ExportImportService.exportToJson', () {
    test('exports versioned multi-entity envelope with exact counts', () {
      final mileageLogs = [
        MileageLog(
          id: 'log-1',
          userId: 'u1',
          entryType: MileageEntryType.distance,
          valueKm: 100.0,
          recordedAt: DateTime.utc(2026, 1, 1),
        ),
        MileageLog(
          id: 'log-2',
          userId: 'u1',
          entryType: MileageEntryType.total,
          valueKm: 2000.0,
          recordedAt: DateTime.utc(2026, 1, 2),
        ),
      ];
      final reminders = [
        MaintenanceReminder(
          id: 'rem-1',
          userId: 'u1',
          label: 'Aceite',
          intervalKm: 5000,
          lastServiceKm: 10000,
          lastServiceDate: DateTime.utc(2026, 1, 10),
          notes: 'Cada 5k',
        ),
      ];
      final services = [
        ServiceRecord(
          id: 'srv-1',
          userId: 'u1',
          reminderId: 'rem-1',
          reminderLabel: 'Aceite',
          odometerKm: 15000,
          costUsd: 25,
          serviceDate: DateTime.utc(2026, 2, 1),
          workshopName: 'Taller Centro',
        ),
      ];
      final settings = VehicleSettings(
        initialKm: 5000,
        purchaseDate: DateTime.utc(2025, 5, 1),
        lastTireChangeKm: 12000,
        nextServiceKm: 18000,
      );

      final json = ExportImportService.exportToJson(
        mileageLogs: mileageLogs,
        reminders: reminders,
        serviceRecords: services,
        settings: settings,
      );
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['schemaVersion'], kCurrentExportSchemaVersion);
      expect(decoded['exportedAt'], isA<String>());
      expect((decoded['mileage'] as List), hasLength(2));
      expect((decoded['reminders'] as List), hasLength(1));
      expect((decoded['services'] as List), hasLength(1));
      expect(decoded['settings'], isA<Map<String, dynamic>>());
      expect((decoded['settings'] as Map<String, dynamic>)['initialKm'], 5000);
    });

    test('produces valid JSON with mileage_logs key', () {
      final logs = [
        MileageLog(
          id: 'log-1',
          userId: 'u1',
          entryType: MileageEntryType.distance,
          valueKm: 100.0,
          recordedAt: DateTime.utc(2026, 1, 1),
        ),
      ];
      final json = ExportImportService.exportToJson(mileageLogs: logs);
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded.containsKey('mileage_logs'), isTrue);
      expect((decoded['mileage_logs'] as List), hasLength(1));
    });

    test('serializes entry_type and value_km correctly', () {
      final logs = [
        MileageLog(
          id: 'log-total',
          userId: 'u1',
          entryType: MileageEntryType.total,
          valueKm: 12345.6,
          recordedAt: DateTime.utc(2026, 3, 15),
        ),
      ];
      final json = ExportImportService.exportToJson(mileageLogs: logs);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final firstLog = (decoded['mileage_logs'] as List).first
          as Map<String, dynamic>;

      expect(firstLog['id'], 'log-total');
      expect(firstLog['entry_type'], 'total');
      expect((firstLog['value_km'] as num).toDouble(), closeTo(12345.6, 0.01));
    });

    test('includes schema_version field', () {
      final json = ExportImportService.exportToJson(mileageLogs: []);
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded.containsKey('schema_version'), isTrue);
      expect(decoded['schema_version'], kCurrentExportSchemaVersion);
    });
  });

  group('ExportImportService.importFromJson', () {
    test('restores multi-entity envelope preserving entity counts', () {
      const raw = '''
{
  "schemaVersion": 1,
  "exportedAt": "2026-04-10T10:00:00.000Z",
  "mileage": [
    {
      "id": "log-1",
      "user_id": "u1",
      "entry_type": "distance",
      "value_km": 55.5,
      "recorded_at": "2026-01-01T00:00:00.000Z"
    }
  ],
  "reminders": [
    {
      "id": "rem-1",
      "user_id": "u1",
      "label": "Aceite",
      "interval_km": 5000,
      "last_service_km": 10000,
      "last_service_date": "2026-01-10T00:00:00.000Z"
    }
  ],
  "services": [
    {
      "id": "srv-1",
      "user_id": "u1",
      "reminder_id": "rem-1",
      "reminder_label": "Aceite",
      "odometer_km": 15000,
      "cost_usd": 25,
      "service_date": "2026-02-01T00:00:00.000Z"
    }
  ],
  "settings": {
    "initialKm": 5000,
    "purchaseDate": "2025-05-01T00:00:00.000Z",
    "lastTireChangeKm": 12000,
    "nextServiceKm": 18000
  }
}''';

      final result = ExportImportService.importFromJson(raw);

      expect(result.schemaVersion, kCurrentExportSchemaVersion);
      expect(result.exportedAt, DateTime.parse('2026-04-10T10:00:00.000Z'));
      expect(result.mileageLogs, hasLength(1));
      expect(result.reminders, hasLength(1));
      expect(result.serviceRecords, hasLength(1));
      expect(result.settings, isNotNull);
      expect(result.settings!.nextServiceKm, 18000);
    });

    test('restores mileage logs from valid JSON', () {
      const raw = '''
{
  "schema_version": 1,
  "mileage_logs": [
    {
      "id": "log-1",
      "user_id": "u1",
      "entry_type": "distance",
      "value_km": 55.5,
      "recorded_at": "2026-01-01T00:00:00.000Z"
    }
  ]
}''';

      final result = ExportImportService.importFromJson(raw);

      expect(result.mileageLogs, hasLength(1));
      expect(result.mileageLogs.first.id, 'log-1');
      expect(result.mileageLogs.first.valueKm, closeTo(55.5, 0.01));
      expect(result.mileageLogs.first.entryType, MileageEntryType.distance);
      expect(result.schemaVersion, kCurrentExportSchemaVersion);
      expect(result.exportedAt, isNull);
    });

    test('migrates legacy v1 payload through schema registry before parse', () {
      const raw = '''
{
  "schema_version": 1,
  "exported_at": "2026-04-10T10:00:00.000Z",
  "mileage_logs": [
    {
      "id": "log-legacy-1",
      "user_id": "u1",
      "entry_type": "total",
      "value_km": 10000,
      "recorded_at": "2026-01-01T00:00:00.000Z"
    }
  ],
  "maintenance_reminders": [
    {
      "id": "rem-legacy-1",
      "user_id": "u1",
      "label": "Filtro",
      "interval_km": 5000,
      "last_service_km": 8000,
      "last_service_date": "2025-12-31T00:00:00.000Z"
    }
  ],
  "service_records": [
    {
      "id": "srv-legacy-1",
      "user_id": "u1",
      "reminder_id": "rem-legacy-1",
      "reminder_label": "Filtro",
      "odometer_km": 9000,
      "cost_usd": 12.5,
      "service_date": "2026-01-03T00:00:00.000Z"
    }
  ],
  "vehicle_settings": {
    "initialKm": 7000,
    "nextServiceKm": 13000
  }
}
''';

      final result = ExportImportService.importFromJson(raw);

      expect(result.schemaVersion, kCurrentExportSchemaVersion);
      expect(result.mileageLogs, hasLength(1));
      expect(result.reminders, hasLength(1));
      expect(result.serviceRecords, hasLength(1));
      expect(result.settings, isNotNull);
      expect(result.settings!.initialKm, 7000);
      expect(result.settings!.nextServiceKm, 13000);
    });

    test('reads exported_at metadata when provided', () {
      const raw = '''
{
  "schema_version": 1,
  "exported_at": "2026-04-10T10:00:00.000Z",
  "mileage_logs": []
}''';

      final result = ExportImportService.importFromJson(raw);

      expect(result.schemaVersion, kCurrentExportSchemaVersion);
      expect(result.exportedAt, DateTime.parse('2026-04-10T10:00:00.000Z'));
    });

    test('throws FormatException on non-JSON input', () {
      expect(
        () => ExportImportService.importFromJson('not json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('returns empty lists when mileage_logs array is absent', () {
      const raw = '{"schema_version": 1}';
      final result = ExportImportService.importFromJson(raw);
      expect(result.mileageLogs, isEmpty);
    });
  });
}
