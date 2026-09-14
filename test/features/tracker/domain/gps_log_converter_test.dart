// gps_log_converter_test.dart
//
// TDD — Task 3.2 RED
// Unit tests for GpsLogConverter pure function.
//
// Spec scenarios:
//   - Convert empty GPS route → null (no log created)
//   - Convert single GPS point → null (no distance calculable)
//   - Convert two points → MileageLog with distance type and computed km
//   - Convert multiple points → sum of all segment distances
//   - Resulting log uses MileageEntryType.distance (not total)
//   - Distance is computed via Haversine formula
//   - Resulting log.recordedAt is the endedAt parameter

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/features/mileage/domain/mileage_log.dart';
import 'package:mi_changan/features/tracker/domain/gps_log_converter.dart';
import 'package:mi_changan/features/tracker/domain/gps_point.dart';

void main() {
  // ── GpsPoint ──────────────────────────────────────────────────────────────

  group('GpsPoint', () {
    test('stores lat, lng, and timestamp', () {
      final point = GpsPoint(
        lat: 10.4806,
        lng: -66.9036,
        recordedAt: DateTime(2026, 4, 1, 10, 0),
      );

      expect(point.lat, 10.4806);
      expect(point.lng, -66.9036);
      expect(point.recordedAt, DateTime(2026, 4, 1, 10, 0));
    });
  });

  // ── GpsLogConverter.convert ───────────────────────────────────────────────

  group('GpsLogConverter.convert', () {
    const userId = 'u1';
    final endedAt = DateTime(2026, 4, 1, 11, 0);

    test('returns null when route is empty', () {
      final result = GpsLogConverter.convert(
        route: [],
        userId: userId,
        logId: 'log-1',
        endedAt: endedAt,
      );

      expect(result, isNull);
    });

    test('returns null when route has only one point', () {
      final result = GpsLogConverter.convert(
        route: [
          GpsPoint(lat: 10.4806, lng: -66.9036, recordedAt: endedAt),
        ],
        userId: userId,
        logId: 'log-1',
        endedAt: endedAt,
      );

      expect(result, isNull);
    });

    test('returns MileageLog with distance type for two-point route', () {
      // Caracas airport area — ~2 km apart
      final result = GpsLogConverter.convert(
        route: [
          GpsPoint(lat: 10.6014, lng: -66.9956, recordedAt: DateTime(2026, 4, 1, 10)),
          GpsPoint(lat: 10.5920, lng: -66.9956, recordedAt: DateTime(2026, 4, 1, 10, 5)),
        ],
        userId: userId,
        logId: 'log-2',
        endedAt: endedAt,
      );

      expect(result, isNotNull);
      expect(result!.entryType, MileageEntryType.distance);
      expect(result.userId, userId);
      expect(result.id, 'log-2');
      expect(result.recordedAt, endedAt);
      // ~1.05 km apart (0.0094° lat difference ≈ 1.05 km)
      expect(result.valueKm, greaterThan(0.5));
      expect(result.valueKm, lessThan(5.0));
    });

    test('sums distances across all segments for a multi-point route', () {
      // 3 points: A→B then B→C, each ~1 km
      // B is 0.009° north of A, C is 0.009° north of B
      const lat0 = 10.4806;
      const lat1 = lat0 + 0.009; // ~1 km north
      const lat2 = lat1 + 0.009; // ~1 km further north
      const lng = -66.9036;

      final result = GpsLogConverter.convert(
        route: [
          GpsPoint(lat: lat0, lng: lng, recordedAt: DateTime(2026, 4, 1, 10)),
          GpsPoint(lat: lat1, lng: lng, recordedAt: DateTime(2026, 4, 1, 10, 5)),
          GpsPoint(lat: lat2, lng: lng, recordedAt: DateTime(2026, 4, 1, 10, 10)),
        ],
        userId: userId,
        logId: 'log-3',
        endedAt: endedAt,
      );

      expect(result, isNotNull);
      // Two segments each ~1 km → total ~2 km
      expect(result!.valueKm, greaterThan(1.5));
      expect(result.valueKm, lessThan(3.0));
    });

    test('recordedAt on resulting log matches the provided endedAt', () {
      final customEndedAt = DateTime(2026, 5, 15, 14, 30);
      final result = GpsLogConverter.convert(
        route: [
          GpsPoint(lat: 10.4806, lng: -66.9036, recordedAt: DateTime(2026, 5, 15, 14, 0)),
          GpsPoint(lat: 10.4900, lng: -66.9036, recordedAt: DateTime(2026, 5, 15, 14, 30)),
        ],
        userId: userId,
        logId: 'log-4',
        endedAt: customEndedAt,
      );

      expect(result, isNotNull);
      expect(result!.recordedAt, customEndedAt);
    });
  });

  // ── GpsLogConverter.haversineKm ───────────────────────────────────────────

  group('GpsLogConverter.haversineKm', () {
    test('returns ~0 for identical coordinates', () {
      final km = GpsLogConverter.haversineKm(10.0, -66.0, 10.0, -66.0);

      expect(km, closeTo(0.0, 0.001));
    });

    test('returns ~111 km for 1 degree latitude difference', () {
      // 1 degree of latitude ≈ 111.195 km
      final km = GpsLogConverter.haversineKm(0.0, 0.0, 1.0, 0.0);

      expect(km, closeTo(111.195, 0.5));
    });

    test('returns ~78.6 km for 1 degree longitude at 45° latitude', () {
      // At 45° lat, 1° longitude ≈ cos(45°) * 111.195 ≈ 78.6 km
      final km = GpsLogConverter.haversineKm(45.0, 0.0, 45.0, 1.0);

      expect(km, closeTo(78.6, 1.0));
    });
  });
}
