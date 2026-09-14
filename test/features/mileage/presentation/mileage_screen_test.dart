import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/core/providers/current_user_provider.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/mileage/domain/mileage_repository.dart';
import 'package:mi_changan/features/mileage/presentation/mileage_datetime_picker.dart';
import 'package:mi_changan/features/mileage/presentation/mileage_screen.dart';

class _FakeMileageRepository implements MileageRepository {
  _FakeMileageRepository([List<MileageLog>? initial])
      : _stored = List<MileageLog>.from(initial ?? const []);

  final List<MileageLog> _stored;
  MileageLog? lastAdded;

  @override
  Future<void> addLog(MileageLog log) async {
    _stored.add(log);
    lastAdded = log;
  }

  @override
  Future<void> deleteLog(String logId) async {
    _stored.removeWhere((log) => log.id == logId);
  }

  @override
  Future<List<MileageLog>> fetchLogs({required String userId}) async =>
      List<MileageLog>.unmodifiable(_stored.where((log) => log.userId == userId));
}

class _FakeMileageDateTimePicker implements MileageDateTimePicker {
  _FakeMileageDateTimePicker(this.selected);

  DateTime selected;

  @override
  Future<DateTime?> pick(BuildContext context, DateTime initialLocalDateTime) async {
    return selected;
  }
}

void main() {
  group('MileageScreen manual datetime + temporal validations', () {
    testWidgets('persists selected custom timestamp when saving entry', (tester) async {
      final fakeRepo = _FakeMileageRepository();
      final fakePicker = _FakeMileageDateTimePicker(DateTime(2026, 4, 10, 8, 45));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((_) => 'user-1'),
            mileageRepositoryProvider.overrideWithValue(fakeRepo),
            mileageDateTimePickerProvider.overrideWithValue(fakePicker),
          ],
          child: const MaterialApp(home: MileageBody()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mileage_add_fab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mileage_datetime_picker_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('mileage_value_field')), '32123');
      await tester.tap(find.byKey(const Key('mileage_save_button')));
      await tester.pumpAndSettle();

      expect(fakeRepo.lastAdded, isNotNull);
      expect(fakeRepo.lastAdded!.recordedAt, DateTime.utc(2026, 4, 10, 8, 45));
    });

    testWidgets('blocks save when selected timestamp is more than 5 minutes in future',
        (tester) async {
      final fakeRepo = _FakeMileageRepository();
      final fakePicker = _FakeMileageDateTimePicker(DateTime.now().add(const Duration(minutes: 6)));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((_) => 'user-1'),
            mileageRepositoryProvider.overrideWithValue(fakeRepo),
            mileageDateTimePickerProvider.overrideWithValue(fakePicker),
          ],
          child: const MaterialApp(home: MileageBody()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mileage_add_fab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mileage_datetime_picker_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('mileage_value_field')), '32000');
      await tester.tap(find.byKey(const Key('mileage_save_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('La fecha/hora no puede estar más de 5 minutos en el futuro.'),
        findsOneWidget,
      );
      expect(fakeRepo.lastAdded, isNull);
    });

    testWidgets('requires explicit confirmation for lower odometer and saves on confirm',
        (tester) async {
      final fakeRepo = _FakeMileageRepository([
        MileageLog(
          id: 'latest-odo',
          userId: 'user-1',
          entryType: MileageEntryType.total,
          valueKm: 35000,
          recordedAt: DateTime.utc(2026, 4, 9, 10, 0),
        ),
      ]);
      final fakePicker = _FakeMileageDateTimePicker(DateTime(2026, 4, 10, 9, 0));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((_) => 'user-1'),
            mileageRepositoryProvider.overrideWithValue(fakeRepo),
            mileageDateTimePickerProvider.overrideWithValue(fakePicker),
          ],
          child: const MaterialApp(home: MileageBody()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mileage_add_fab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mileage_datetime_picker_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('mileage_value_field')), '34999');
      await tester.tap(find.byKey(const Key('mileage_save_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('El odómetro es menor al último registro. ¿Querés guardarlo igual?'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('mileage_confirm_lower_odometer_button')));
      await tester.pumpAndSettle();

      expect(fakeRepo.lastAdded, isNotNull);
      expect(fakeRepo.lastAdded!.valueKm, 34999);
    });
  });
}
