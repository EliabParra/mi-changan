import 'package:mi_changan/core/sync/domain/sync_outbox_event.dart';

abstract class SyncOutboxRepository {
  Future<void> enqueue(SyncOutboxEvent event);
  Future<List<SyncOutboxEvent>> pullReady({required int limit});
  Future<void> markSynced(String eventId, {required DateTime syncedAt});
  Future<void> markFailed(
    String eventId, {
    required String reason,
    DateTime? nextRetryAt,
  });
  Future<void> markConflict(String eventId, SyncConflictRecord conflict);
}
