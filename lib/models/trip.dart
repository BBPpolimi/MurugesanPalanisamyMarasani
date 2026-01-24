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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'points': points.map((p) => p.toJson()).toList(),
      'distanceMeters': distanceMeters,
      'duration': duration.inMicroseconds, // Storing duration as microseconds
      'averageSpeed': averageSpeed,
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      points: (json['points'] as List<dynamic>)
          .map((e) => GpsPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      duration: Duration(microseconds: json['duration'] as int),
      averageSpeed: (json['averageSpeed'] as num).toDouble(),
    );
  }
}
