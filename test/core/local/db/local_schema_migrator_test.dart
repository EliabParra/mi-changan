import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/core/local/db/local_schema_migrator.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('LocalSchemaMigrator', () {
    test('creates tracking_session_drafts and outbox_events tables', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      LocalSchemaMigrator.migrateToLatest(db);

      final trackingColumns = _columnNames(db, 'tracking_session_drafts');
      final outboxColumns = _columnNames(db, 'outbox_events');

      expect(trackingColumns, containsAll(['trip_id', 'started_at', 'status']));
      expect(
        outboxColumns,
        containsAll([
          'id',
          'idempotency_key',
          'entity',
          'operation',
          'attempts',
          'next_retry_at',
          'failure_reason',
        ]),
      );
      final conflictColumns = _columnNames(db, 'sync_conflict_logs');
      expect(
        conflictColumns,
        containsAll(['event_id', 'entity_id', 'resolution', 'recorded_at']),
      );
    });

    test('outbox_events supports insert and read with attempts and retry', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      LocalSchemaMigrator.migrateToLatest(db);

      db.execute(
        '''
        INSERT INTO outbox_events(
          id, schema_version, idempotency_key, entity, operation, payload_json, occurred_at,
          status, attempts, next_retry_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          'evt-1',
          1,
          'idem-evt-1',
          'mileage_log',
          'upsert',
          '{"id":"log-1"}',
          '2026-04-10T13:00:00.000Z',
          'pending',
          2,
          '2026-04-10T13:05:00.000Z',
        ],
      );

      final rows = db.select(
        'SELECT attempts, next_retry_at FROM outbox_events WHERE id = ?',
        ['evt-1'],
      );

      expect(rows, hasLength(1));
      expect(rows.first['attempts'], 2);
      expect(rows.first['next_retry_at'], '2026-04-10T13:05:00.000Z');
    });
  });
}

List<String> _columnNames(Database db, String table) {
  final rows = db.select('PRAGMA table_info($table)');
  return rows.map((r) => r['name'] as String).toList();
}
