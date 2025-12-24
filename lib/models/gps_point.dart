class GpsPoint {
final double latitude;
final double longitude;
final double? elevation;
final DateTime timestamp;

GpsPoint({required this.latitude, required this.longitude, this.elevation, required this.timestamp});
}