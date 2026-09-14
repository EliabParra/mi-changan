import 'package:sqlite3/sqlite3.dart';

abstract final class LocalSchemaMigrator {
  static void migrateToLatest(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS tracking_session_drafts (
        trip_id TEXT PRIMARY KEY,
        started_at TEXT NOT NULL,
        status TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS outbox_events (
        id TEXT PRIMARY KEY,
        schema_version INTEGER NOT NULL,
        idempotency_key TEXT NOT NULL,
        entity TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        status TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        next_retry_at TEXT,
        synced_at TEXT,
        failure_reason TEXT
      );
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS sync_conflict_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id TEXT NOT NULL,
        entity TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        local_updated_at TEXT NOT NULL,
        remote_updated_at TEXT NOT NULL,
        resolution TEXT NOT NULL,
        reason TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        FOREIGN KEY(event_id) REFERENCES outbox_events(id)
      );
    ''');
  }
}
