import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/core/sync/data/sync_providers.dart';
import 'package:mi_changan/core/sync/domain/sync_outbox_event.dart';

void main() {
  test('sync outbox provider persists queued events across container recreation', () async {
    final tempDir = await Directory.systemTemp.createTemp('mi-changan-sync-test-');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final dbPath = '${tempDir.path}/sync_outbox.sqlite3';
    final event = SyncOutboxEvent(
      id: 'evt-1',
      schemaVersion: 1,
      idempotencyKey: 'idem-1',
      entity: 'mileage_logs',
      operation: SyncOutboxOperation.upsert,
      payload: const {'id': 'log-1'},
      occurredAt: DateTime.utc(2026, 4, 10, 19),
      status: SyncOutboxStatus.pending,
    );

    final firstContainer = ProviderContainer(
      overrides: [
        syncDatabasePathProvider.overrideWithValue(dbPath),
      ],
    );
    addTearDown(firstContainer.dispose);
    await firstContainer.read(syncOutboxRepositoryProvider).enqueue(event);
    firstContainer.dispose();

    final secondContainer = ProviderContainer(
      overrides: [
        syncDatabasePathProvider.overrideWithValue(dbPath),
      ],
    );
    addTearDown(secondContainer.dispose);

    final ready = await secondContainer
        .read(syncOutboxRepositoryProvider)
        .pullReady(limit: 10);

    expect(ready, hasLength(1));
    expect(ready.single.id, 'evt-1');
    expect(ready.single.idempotencyKey, 'idem-1');
  });
}
