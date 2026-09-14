import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_changan/core/local/db/local_schema_migrator.dart';
import 'package:mi_changan/core/sync/data/drift_sync_outbox_repository.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_repository.dart';
import 'package:sqlite3/sqlite3.dart';

final syncDatabasePathProvider = Provider<String>((ref) {
  return 'sync_outbox.sqlite3';
});

final _syncDatabaseProvider = Provider<Database>((ref) {
  final dbPath = ref.watch(syncDatabasePathProvider);
  final db = sqlite3.open(dbPath);
  LocalSchemaMigrator.migrateToLatest(db);
  ref.onDispose(db.dispose);
  return db;
});

final syncOutboxRepositoryProvider = Provider<SyncOutboxRepository>((ref) {
  final db = ref.watch(_syncDatabaseProvider);
  return DriftSyncOutboxRepository(db);
});
