import 'package:mi_changan/features/mileage/domain/mileage_log.dart';

double? latestTotalOdometerKm(List<MileageLog> logs) {
  MileageLog? latest;

  for (final log in logs) {
    if (log.entryType != MileageEntryType.total) continue;
    if (latest == null || log.recordedAt.isAfter(latest.recordedAt)) {
      latest = log;
    }
  }

  return latest?.valueKm;
}

List<MileageLog> orderMileageLogsByTimestamp(
  List<MileageLog> logs, {
  bool newestFirst = true,
}) {
  final ordered = [...logs];
  ordered.sort((left, right) {
    final result = left.recordedAt.compareTo(right.recordedAt);
    return newestFirst ? -result : result;
  });
  return List<MileageLog>.unmodifiable(ordered);
}
