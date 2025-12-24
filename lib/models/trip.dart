import 'gps_point.dart';

class Trip {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final List<GpsPoint> points;
  final double distanceMeters;
  final Duration duration;
  final double averageSpeed;

  Trip({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.points,
    required this.distanceMeters,
    required this.duration,
    required this.averageSpeed,
  });
}
