// mileage_notifier_test.dart
//
// TDD — Task 1.2 RED
// Unit tests for MileageNotifier (add/delete + state management).
//
// Tests cover:
//   - Initial state is AsyncLoading, then AsyncData([]) when no logs.
//   - addLog() appends a log to state.
//   - deleteLog() removes a log from state.
//   - addLog() sets AsyncError on repository failure.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/mileage/domain/mileage_notifier_provider.dart';
import 'package:mi_changan/features/mileage/domain/mileage_repository.dart';

// ── Controllable fake repository ───────────────────────────────────────────

class FakeMileageRepository implements MileageRepository {
  FakeMileageRepository([List<MileageLog>? initial])
      : _stored = List.from(initial ?? []);

  final List<MileageLog> _stored;
  Exception? addError;
  Exception? deleteError;

  @override
  Future<List<MileageLog>> fetchLogs({required String userId}) async =>
      List.unmodifiable(_stored);

  @override
  Future<void> addLog(MileageLog log) async {
    if (addError != null) throw addError!;
    _stored.add(log);
  }

  @override
  Future<void> deleteLog(String logId) async {
    if (deleteError != null) throw deleteError!;
    _stored.removeWhere((l) => l.id == logId);
  }
}

ProviderContainer makeContainer(FakeMileageRepository fake, String userId) {
  return ProviderContainer(
    overrides: [
      mileageRepositoryProvider.overrideWithValue(fake),
    ],
  );
}

// ── Test helpers ───────────────────────────────────────────────────────────

MileageLog makeLog({
  String id = 'log-1',
  String userId = 'u1',
  double km = 100.0,
}) =>
    MileageLog(
      id: id,
      userId: userId,
      entryType: MileageEntryType.distance,
      valueKm: km,
      recordedAt: DateTime(2026, 3, 1),
    );

void main() {
  group('MileageNotifier', () {
    test('initial state loads empty list when no logs exist', () async {
      final fake = FakeMileageRepository();
      final container = makeContainer(fake, 'u1');
      addTearDown(container.dispose);

      final logs = await container.read(mileageNotifierProvider('u1').future);

      expect(logs, isEmpty);
    });

    test('initial state loads pre-existing logs', () async {
      final existing = [makeLog(id: 'log-1', km: 50.0)];
      final fake = FakeMileageRepository(existing);
      final container = makeContainer(fake, 'u1');
      addTearDown(container.dispose);

      final logs = await container.read(mileageNotifierProvider('u1').future);

      expect(logs, hasLength(1));
      expect(logs.first.id, 'log-1');
    });

    test('addLog() appends the log to state', () async {
      final fake = FakeMileageRepository();
      final container = makeContainer(fake, 'u1');
      addTearDown(container.dispose);

      // Wait for build to complete
      await container.read(mileageNotifierProvider('u1').future);

      final notifier = container.read(mileageNotifierProvider('u1').notifier);
      await notifier.addLog(makeLog(id: 'log-new', km: 75.0));

      final logs = await container.read(mileageNotifierProvider('u1').future);
      expect(logs, hasLength(1));
      expect(logs.first.valueKm, 75.0);
    });

    test('deleteLog() removes the log from state', () async {
      final existing = [makeLog(id: 'to-delete', km: 30.0)];
      final fake = FakeMileageRepository(existing);
      final container = makeContainer(fake, 'u1');
      addTearDown(container.dispose);

      await container.read(mileageNotifierProvider('u1').future);

      final notifier =
          container.read(mileageNotifierProvider('u1').notifier);
      await notifier.deleteLog('to-delete');

      final logs = await container.read(mileageNotifierProvider('u1').future);
      expect(logs, isEmpty);
    });

    test('addLog() sets AsyncError when repository throws', () async {
      final fake = FakeMileageRepository()
        ..addError = Exception('network error');
      final container = makeContainer(fake, 'u1');
      addTearDown(container.dispose);

      await container.read(mileageNotifierProvider('u1').future);
      final notifier = container.read(mileageNotifierProvider('u1').notifier);
      await notifier.addLog(makeLog());

      final state = container.read(mileageNotifierProvider('u1'));
      expect(state.hasError, isTrue);
    });
  });
}
