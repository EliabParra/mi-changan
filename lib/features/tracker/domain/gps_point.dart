// gps_point.dart
//
// Immutable value object representing a single GPS coordinate capture.
//
// Design decisions:
//   - Pure value type — no dependencies on external packages.
//   - lat/lng in WGS-84 decimal degrees.
//   - recordedAt in UTC.

/// A captured GPS coordinate from a tracking session.
class GpsPoint {
  const GpsPoint({
    required this.lat,
    required this.lng,
    required this.recordedAt,
  });

  /// Latitude in WGS-84 decimal degrees.
  final double lat;

  /// Longitude in WGS-84 decimal degrees.
  final double lng;

  /// When this point was captured (UTC).
  final DateTime recordedAt;

  @override
  String toString() => 'GpsPoint(lat: $lat, lng: $lng, at: $recordedAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GpsPoint &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lng == other.lng &&
          recordedAt == other.recordedAt;

  @override
  int get hashCode => Object.hash(lat, lng, recordedAt);
}
