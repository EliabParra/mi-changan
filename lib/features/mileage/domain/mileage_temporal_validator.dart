import 'package:mi_changan/features/mileage/domain/mileage_log.dart';

const _futureTolerance = Duration(minutes: 5);

class MileageTemporalValidationResult {
  const MileageTemporalValidationResult({
    required this.isValid,
    required this.requiresLowerOdometerConfirmation,
    this.message,
  });

  final bool isValid;
  final bool requiresLowerOdometerConfirmation;
  final String? message;
}

class MileageTemporalValidator {
  const MileageTemporalValidator();

  MileageTemporalValidationResult validate({
    required MileageEntryType entryType,
    required double valueKm,
    required DateTime selectedAtUtc,
    required DateTime nowUtc,
    double? latestTotalOdometerKm,
  }) {
    if (selectedAtUtc.isAfter(nowUtc.add(_futureTolerance))) {
      return const MileageTemporalValidationResult(
        isValid: false,
        requiresLowerOdometerConfirmation: false,
        message: 'La fecha/hora no puede estar más de 5 minutos en el futuro.',
      );
    }

    if (entryType == MileageEntryType.total &&
        latestTotalOdometerKm != null &&
        valueKm < latestTotalOdometerKm) {
      return const MileageTemporalValidationResult(
        isValid: true,
        requiresLowerOdometerConfirmation: true,
      );
    }

    return const MileageTemporalValidationResult(
      isValid: true,
      requiresLowerOdometerConfirmation: false,
    );
  }
}
