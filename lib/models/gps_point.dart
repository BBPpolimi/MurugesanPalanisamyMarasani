class GpsPoint {
  final double latitude;
  final double longitude;
  final double? elevation;
  final double? accuracyMeters; // NEW
  final DateTime timestamp;

  GpsPoint({
    required this.latitude,
    required this.longitude,
    this.elevation,
    this.accuracyMeters,
    required this.timestamp,
  });
}
