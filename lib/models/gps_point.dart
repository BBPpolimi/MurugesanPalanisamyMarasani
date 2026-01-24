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

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'elevation': elevation,
      'accuracyMeters': accuracyMeters,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory GpsPoint.fromJson(Map<String, dynamic> json) {
    return GpsPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      elevation: (json['elevation'] as num?)?.toDouble(),
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
