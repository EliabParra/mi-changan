// gps_log_converter.dart
//
// Pure domain function to convert a GPS route into a MileageLog.
//
// Design decisions:
//   - All methods are static — no state, no side effects.
//   - Uses Haversine formula for earth-curvature-aware distance.
//   - Returns null for routes with < 2 points (distance undefined).
//   - Resulting log uses MileageEntryType.distance — it records a trip delta.
//   - recordedAt on the log is the endedAt param (session end timestamp).
//   - haversineKm is public for direct unit testing.

import 'dart:math' as math;

import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/tracker/domain/gps_point.dart';

/// Converts a list of [GpsPoint]s into a distance-type [MileageLog].
abstract final class GpsLogConverter {
  // ── Earth radius (mean) ──────────────────────────────────────────────────

  static const double _earthRadiusKm = 6371.0088;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Converts a GPS [route] into a [MileageLog] with the total distance.
  ///
  /// Returns `null` when [route] has fewer than 2 points.
  static MileageLog? convert({
    required List<GpsPoint> route,
    required String userId,
    required String logId,
    required DateTime endedAt,
  }) {
    if (route.length < 2) return null;

    var totalKm = 0.0;
    for (var i = 0; i < route.length - 1; i++) {
      final a = route[i];
      final b = route[i + 1];
      totalKm += haversineKm(a.lat, a.lng, b.lat, b.lng);
    }

    return MileageLog(
      id: logId,
      userId: userId,
      entryType: MileageEntryType.distance,
      valueKm: totalKm,
      recordedAt: endedAt,
    );
  }

  /// Haversine distance in km between two WGS-84 coordinates.
  ///
  /// Public to allow direct unit testing of the formula accuracy.
  static double haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  static double _toRad(double deg) => deg * math.pi / 180.0;
}
