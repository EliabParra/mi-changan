import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/mileage/domain/mileage_temporal_validator.dart';

void main() {
  group('MileageTemporalValidator', () {
    const validator = MileageTemporalValidator();

    test('rejects timestamp more than 5 minutes in future', () {
      final nowUtc = DateTime.utc(2026, 4, 10, 12, 0, 0);
      final selected = nowUtc.add(const Duration(minutes: 6));

      final result = validator.validate(
        entryType: MileageEntryType.total,
        valueKm: 32000,
        selectedAtUtc: selected,
        nowUtc: nowUtc,
        latestTotalOdometerKm: 31900,
      );

      expect(result.isValid, isFalse);
      expect(result.requiresLowerOdometerConfirmation, isFalse);
      expect(result.message, 'La fecha/hora no puede estar más de 5 minutos en el futuro.');
    });

    test('requires explicit confirmation when odometer is lower than latest', () {
      final nowUtc = DateTime.utc(2026, 4, 10, 12, 0, 0);
      final selected = nowUtc.subtract(const Duration(minutes: 1));

      final result = validator.validate(
        entryType: MileageEntryType.total,
        valueKm: 31999,
        selectedAtUtc: selected,
        nowUtc: nowUtc,
        latestTotalOdometerKm: 32000,
      );

      expect(result.isValid, isTrue);
      expect(result.requiresLowerOdometerConfirmation, isTrue);
      expect(result.message, isNull);
    });

    test('distance entries do not require lower odometer confirmation', () {
      final nowUtc = DateTime.utc(2026, 4, 10, 12, 0, 0);

      final result = validator.validate(
        entryType: MileageEntryType.distance,
        valueKm: 5,
        selectedAtUtc: nowUtc,
        nowUtc: nowUtc,
        latestTotalOdometerKm: 32000,
      );

      expect(result.isValid, isTrue);
      expect(result.requiresLowerOdometerConfirmation, isFalse);
      expect(result.message, isNull);
    });
  });
}
