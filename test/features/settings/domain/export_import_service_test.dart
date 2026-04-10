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
import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/settings/domain/export_import_service.dart';

void main() {
  group('ExportImportService.exportToJson', () {
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
      expect(decoded['schema_version'], isA<int>());
    });
  });

  group('ExportImportService.importFromJson', () {
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
