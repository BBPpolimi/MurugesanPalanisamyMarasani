import 'gps_point.dart';
import 'weather_data.dart';

class Trip {
  final String? name; // Optional user-defined name
  final String id;
  final String userId; // Owner of the trip
  final DateTime startTime;
  final DateTime endTime;
  final List<GpsPoint> points;
  final double distanceMeters;
  final Duration duration;
  final double averageSpeed;
  final String? contributionId; // Link to generated Contribution (if any)
  final bool isAutoDetected; // Whether trip was auto-started
  final WeatherData? weatherData; // Optional weather at trip time
  final List<String> confirmedObstacleIds; // IDs of confirmed obstacles

  Trip({
    this.name,
    required this.id,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.points,
    required this.distanceMeters,
    required this.duration,
    required this.averageSpeed,
    this.contributionId,
    this.isAutoDetected = false,
    this.weatherData,
    this.confirmedObstacleIds = const [],
  });

  Trip copyWith({
    String? name,
    String? id,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    List<GpsPoint>? points,
    double? distanceMeters,
    Duration? duration,
    double? averageSpeed,
    String? contributionId,
    bool? isAutoDetected,
    WeatherData? weatherData,
    List<String>? confirmedObstacleIds,
  }) {
    return Trip(
      name: name ?? this.name,
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      points: points ?? this.points,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      duration: duration ?? this.duration,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      contributionId: contributionId ?? this.contributionId,
      isAutoDetected: isAutoDetected ?? this.isAutoDetected,
      weatherData: weatherData ?? this.weatherData,
      confirmedObstacleIds: confirmedObstacleIds ?? this.confirmedObstacleIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'id': id,
      'userId': userId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'points': points.map((p) => p.toJson()).toList(),
      'distanceMeters': distanceMeters,
      'duration': duration.inMicroseconds, // Storing duration as microseconds
      'averageSpeed': averageSpeed,
      if (contributionId != null) 'contributionId': contributionId,
      'isAutoDetected': isAutoDetected,
      if (weatherData != null) 'weatherData': weatherData!.toJson(),
      'confirmedObstacleIds': confirmedObstacleIds,
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      name: json['name'] as String?,
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      points: (json['points'] as List<dynamic>)
          .map((e) => GpsPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      duration: Duration(microseconds: json['duration'] as int),
      averageSpeed: (json['averageSpeed'] as num).toDouble(),
      contributionId: json['contributionId'] as String?,
      isAutoDetected: json['isAutoDetected'] as bool? ?? false,
      weatherData: json['weatherData'] != null
          ? WeatherData.fromJson(json['weatherData'] as Map<String, dynamic>)
          : null,
      confirmedObstacleIds: (json['confirmedObstacleIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}
